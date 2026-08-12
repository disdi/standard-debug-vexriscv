# System Integration — SWD


Goal is **host-visible integration only** (LiteX SoC, OpenOCD, GDB). Target-side SWD
RTL (`SwdPhy` / `SwdDp` / `SwdDmiGateway`) is Phase **2A–2C** and is not re-defined here.

| Step | Content | Status |
| --- | --- | --- |
| **1** | Cluster / `core.py` / `swdremote` / `litex_sim` + OpenOCD raw-AP smoke | ✅ Completed |
| **2** | Custom OpenOCD `riscv` glue + GDB | ✅ Completed (**Vexriscv fork**: master + Gerrit 9786) |
| **3** | Arty pinout + CMSIS-DAP (SWD mode) + Phase 4 regressions | [ ] **Next** |
| — | Finalize placeholder `DPIDR` / `AP_IDR` if host scripts hard-code them | [ ] Still open (placeholders ship from Phase 2C) |

**Invariant**

- Official RISC-V DM only (`withPrivilegedDebug`).
- One debug transport per build — **no** JTAG-DTM + SWD-DTM on the same `DebugBus`
  without arbitration. Do **not** set `JTAG_SIM=1` and `SWD_SIM=1` together.

---

**Code repositories**

- LiteX — https://github.com/disdi/litex/tree/swd
- VexRiscv — https://github.com/disdi/VexRiscv/tree/phase3
- OpenOCD (Vexriscv fork) — https://github.com/disdi/openocd/tree/vexriscv-gateway

Update submodules in
[pythondata-cpu-vexriscv_smp](https://github.com/disdi/pythondata-cpu-vexriscv_smp)
to the LiteX / VexRiscv branches above.

**OpenOCD (host, not RTL)** — two lanes on **master**:

| Lane | Build | Role |
| --- | --- | --- |
| raw-AP smoke | OpenOCD **master** (stock OK for SWD `remote_bitbang`) | DPIDR + `dap apreg` → `dmstatus`; **no** GDB |
| **Vexriscv fork** (`riscv` + GDB) | [disdi/openocd `vexriscv-gateway`](https://github.com/disdi/openocd/tree/vexriscv-gateway) — OpenOCD **master** + [Gerrit 9786](https://review.openocd.org/c/openocd/+/9786) + designer-AP / VexRiscv DTM backend | examine + halt/resume/regs + GDB :3333 |

Stock master is enough for smoke. Full `riscv` attach needs the published
[`vexriscv-gateway`](https://github.com/disdi/openocd/tree/vexriscv-gateway) branch:
9786 (DTM + Mem-AP DMI backend), two fixes to 9786 itself, and a second **designer-AP /
VexRiscv gateway** backend for the Phase 2C `DMI_ADDR` / `DMI_DATA` map. No RTL change.

Upstream’s stock `riscv` target **rejects `-dap`** at argument parsing, so Tcl-only
`dap apreg` helpers cannot drive a GDB session — that is why the 9786 + gateway path exists.

---

## SWD specific tasks

### Step 1 (done) — LiteX + smoke

- [x] `DebugTransportModuleSwd` with `io.swclk` (**input**, probe-driven) + `io.swdio` as `i`/`o`/`oe` — Phase **2A–2C**
- [x] `withSwdTransport()` on `DebugModuleFiber` (mutually exclusive with `withJtagTap()` per build) — Phase **2C**
- [x] LiteX SMP cluster: `swd` param, `--swd` CLI, three-wire `debugPort_swclk` / `swdio_{i,o,oe}`, `noTap` guarded `!jtagTap && !swd`
- [x] LiteX sim: `--with-swd-debug`, `_Swd` netlist token, `add_swd()`, `swdremote` on TCP **44854**
- [x] OpenOCD smoke on sim: DPIDR `0x0ba11aab` + `dap apreg` → `dmstatus` `0x004c0c82`
- [x] OpenOCD cfgs: `openocd_swd_remote.cfg` + `vexriscv_swd.cfg` (DAP + `vexriscv_dmi_read/write` + smoke)
- [x] Cluster asserts: reject `swd && jtagTap`; require `privilegedDebug` when `swd`

### Step 2 (done) — host tooling + GDB (Vexriscv fork)

- [x] OpenOCD `riscv` target over SWD via master + Gerrit 9786 + VexRiscv DTM backend
  ([disdi/openocd `vexriscv-gateway`](https://github.com/disdi/openocd/tree/vexriscv-gateway))
  - Exit met: halt / resume / register read of the **sim CPU** over SWD
  - Config: `vexriscv_swd_riscv_master.cfg` (`dtm create -type vexriscv-gateway`)
- [x] Real hart examine (not Phase 2C stub): `XLEN=32`, `misa=0x40141101` (RV32IMA + S/U)
- [x] GDB: `target extended-remote :3333`, attach, `info registers`, disassembly, memory R/W
- [ ] Finalize `DPIDR` / `AP_IDR` before host scripts hard-code them
  - Placeholders from Phase **2C**: `DPIDR=0x0BA11AAB`, `AP_IDR=0x74726976` (“triv”)
  - Must **not** look like ARM Cortex SW-DP (`0x2ba01477` / DESIGNER `0x23B`)

### Step 2b (done) — demo run control in sim

- [x] Preload `demo.bin` into `main_ram` (`--ram-init=demo.bin`); GDB loads **symbols only** from `demo/demo.elf`
- [x] `break main` / `continue` / `bt` over SWD on the Vexriscv fork
- [x] **Never** GDB `load` in SWD sim (hours at `swdremote` pacing)

### Step 3 (open) — hardware

- [ ] Arty pinout + CMSIS-DAP in **SWD mode**
- [ ] Probe docs (CMSIS-DAP / J-Link / ST-Link) for SWD, not ARM Cortex auto-detect
- [ ] Phase 4 regressions on real silicon

---

## Host attach workflows (sim)

### Side-by-side

| Terminal | JTAG — **full three-terminal ✅** | SWD — **full three-terminal ✅** |
| --- | --- | --- |
| **1 — sim** | `litex_sim … --with-privileged-debug --jtag-tap --with-jtagremote` → TCP **44853** (`jtagremote`) | `litex_sim … --with-privileged-debug --with-swd-debug --with-swdremote` → TCP **44854** (`swdremote`); add `--ram-init=demo.bin` for demo debug |
| **2 — OpenOCD** | Stock `riscv` target + BSCAN tunnel; examines hart; GDB **:3333** | `transport select swd` + DAP + **Vexriscv fork** `riscv`; examines hart; GDB **:3333** |
| **3 — GDB** | `target extended-remote localhost:3333` → halt / regs / `load` | attach + regs ✅; demo **`break main` / `continue` / `bt`** ✅ via **preload** (no GDB `load`) |

| Capability | JTAG | SWD |
| --- | --- | --- |
| Verilator SoC + official DM | ✅ | ✅ (`_Swd` cluster) |
| Wire transport in sim | ✅ JTAG TAP + tunnel | ✅ SW-DP (`DebugTransportModuleSwd`) |
| OpenOCD sees transport | ✅ TAP `0x10003fff` | ✅ SWD DPIDR `0x0ba11aab` |
| Read `dmstatus` | ✅ via `riscv` / DMI | ✅ via `vexriscv_dmi_read 0x11` / smoke |
| `Examined RISC-V core` | ✅ | ✅ `XLEN=32, misa=0x40141101` |
| GDB halt / resume / `info registers` | ✅ | ✅ |
| Break / continue / backtrace | ✅ (`load` OK on JTAG) | ✅ via `--ram-init=demo.bin` + symbols; GDB `load` impractical in sim |
| OpenOCD binary | stock master | stock master for raw-AP smoke; **Vexriscv fork** ([disdi/openocd `vexriscv-gateway`](https://github.com/disdi/openocd/tree/vexriscv-gateway)) for `riscv` / GDB |

---

### JTAG — end-to-end workflow

Official stack only (`--with-privileged-debug` + full JTAG TAP in sim).

**Prerequisites**

- `litex_sim` (LiteX venv)
- OpenOCD master with standard RISC-V target
- `riscv64-unknown-elf-gdb`

**Configs**

| File | Role |
| --- | --- |
| `openocd_jtag_remote.cfg` | `remote_bitbang` → `localhost:44853` |
| `riscv_jtag_tunneled.tcl` | TAP `irlen 6`, ID `0x10003fff`, `riscv use_bscan_tunnel 6 1` |

**Terminal 1 — sim (keep running)**

```sh
litex_sim \
  --integrated-main-ram-size=0x10000 \
  --cpu-type=vexriscv_smp \
  --cpu-variant=linux \
  --cpu-count=1 \
  --with-privileged-debug \
  --jtag-tap \
  --with-jtagremote \
  --non-interactive
```

| Flag | Role |
| --- | --- |
| `--integrated-main-ram-size=0x10000` | 64 KiB main RAM for sim (demo load region) |
| `--cpu-type=vexriscv_smp` / `--cpu-variant=linux` / `--cpu-count=1` | SMP Linux-capable cluster, 1 hart |
| `--with-privileged-debug` | Official `DebugModule` + DTM (`_Pd` netlist token) |
| `--jtag-tap` | Full JTAG TAP on cluster (`_JtagT`); needed so sim has TCK/TMS/TDI/TDO pads |
| `--with-jtagremote` | LiteX sim module `jtagremote` — OpenOCD `remote_bitbang` on TCP **44853** |
| `--non-interactive` | Keep sim running (no local control menu); target for OpenOCD/GDB |

Wait for `Found port 44853` and BIOS prompt `litex>`. First run may take several minutes
(cluster regen + Verilator compile).

**Terminal 2 — OpenOCD (after Terminal 1 is up)**

```sh
openocd -f openocd_jtag_remote.cfg -f riscv_jtag_tunneled.tcl
```

Success indicators:

```text
Info : JTAG tap: riscv.cpu tap/device found: 0x10003fff
Info : Examined RISC-V core; found 1 harts
Ready for Remote Connections
Info : Listening on port 3333 for gdb connections
```

**Terminal 3 — GDB (after OpenOCD is ready)**

```sh
riscv64-unknown-elf-gdb demo/demo.elf
```

```gdb
set remotetimeout 120
set pagination off
set arch riscv:rv32
target extended-remote localhost:3333
monitor reset halt
x/8i $pc
info registers
```

One-liner:

```sh
riscv64-unknown-elf-gdb -ex "set remotetimeout 120" \
  -ex "target extended-remote localhost:3333" \
  demo/demo.elf
```

Load `demo.elf` (linked at `0x40000000`) only after halt — this `litex_sim` invocation does
**not** pass `--ram-init=demo.bin`, so the image is not preloaded:

```gdb
monitor reset halt
load demo/demo.elf
break main
continue
```

If sim is slow and `keep_alive()` warnings (slow bitbang) are seen, prefer `target extended-remote`
and `set remotetimeout 120`.

---

### SWD — OpenOCD

| Lane | OpenOCD build | Configs | Gives you |
| --- | --- | --- | --- |
| raw AP | master | `openocd_swd_remote.cfg` + `vexriscv_swd.cfg` | DPIDR + `dap apreg` → `dmstatus`; **no** GDB |
| `riscv` **Vexriscv fork** | [disdi/openocd `vexriscv-gateway`](https://github.com/disdi/openocd/tree/vexriscv-gateway) (master + 9786 + gateway) | + `vexriscv_swd_riscv_master.cfg` | examine + halt/resume/regs + GDB :3333 |

**Prerequisites (SWD-specific)**

- `litex_sim`
- OpenOCD **master** with SWD `remote_bitbang` for smoke test
- For `riscv` / GDB: build from
  [https://github.com/disdi/openocd/tree/vexriscv-gateway](https://github.com/disdi/openocd/tree/vexriscv-gateway)
  (stock master rejects `riscv -dap`)
- `riscv64-unknown-elf-gdb`; use **`set remotetimeout 300`** on the SWD lane

**Configs**

| File | Role |
| --- | --- |
| `openocd_swd_remote.cfg` | `remote_bitbang` → `localhost:44854`, `transport select swd` |
| `vexriscv_swd.cfg` | SW-DP + DAP + `vexriscv_dmi_read/write` + `vexriscv_swd_smoke` — **no** `riscv` target |
| `vexriscv_swd_riscv_master.cfg` | Vexriscv fork: `dtm create -type vexriscv-gateway` + `riscv` + `gdb-attach halt` |

**Terminal 1 — sim (keep running)**

Do **not** pass `--jtag-tap` / `--with-jtagremote` here.

| Goal | Extra flag |
| --- | --- |
| Attach / regs / raw-AP smoke | (none) — wait for `Found port 44854` + BIOS `litex>` |
| Debug the demo app (`break main` / `continue` / `bt`) | `--ram-init=demo.bin` — wait for serialboot timeout → `Executing booted program at 0x40000000` → `litex-demo-app>` |

```sh
litex_sim \
  --integrated-main-ram-size=0x10000 \
  --cpu-type=vexriscv_smp \
  --cpu-variant=linux \
  --cpu-count=1 \
  --with-privileged-debug \
  --with-swd-debug \
  --with-swdremote \
  --non-interactive
  --ram-init=demo.bin
```

| Flag | Role |
| --- | --- |
| `--with-privileged-debug` | Official `DebugModule` (required; SWD is official-stack only) |
| `--with-swd-debug` | Cluster SWD transport + `_Swd` netlist token |
| `--with-swdremote` | LiteX sim module `swdremote` — OpenOCD SWD bitbang on TCP **44854** |
| `--ram-init=demo.bin` | Preload demo into `main_ram` @ `0x40000000` (demo-debug only) |

**Terminal 2 — raw-AP smoke** (stock master; no GDB)

One-shot:

```sh
openocd -s tcl \
  -f openocd_swd_remote.cfg \
  -f vexriscv_swd.cfg \
  -c init -c vexriscv_swd_smoke -c shutdown
```

Verified success:

```text
Info : SWD DPIDR 0x0ba11aab
AP_IDR   = 0x74726976
dmstatus = 0x004c0c82 (version=2 authenticated=1 allrunning=1 allhalted=0)
PASS: SWD -> SW-DP -> DMI gateway -> DebugModule
```

Interactive Tcl helpers (same two configs, stay open):

```tcl
vexriscv_swd_smoke
vexriscv_dmi_read 0x11          ;# dmstatus
```

**Terminal 2 — `riscv` target + GDB server** (Vexriscv fork: [disdi/openocd `vexriscv-gateway`](https://github.com/disdi/openocd/tree/vexriscv-gateway))

```sh
# Use the openocd binary built from:
#   https://github.com/disdi/openocd/tree/vexriscv-gateway
openocd -s tcl \
  -f openocd_swd_remote.cfg \
  -f vexriscv_swd.cfg \
  -f vexriscv_swd_riscv_master.cfg
```

Verified examine (real hart, not stub):

```text
Info : SWD DPIDR 0x0ba11aab
Info : [vexriscv.rv] datacount=1 progbufsize=2
Info : [vexriscv.rv] Examined RISC-V core
Info : [vexriscv.rv]  XLEN=32, misa=0x40141101
vexriscv.rv halted due to debug-request.
```

`misa=0x40141101` = RV32 I+M+A+S+U. Check halt/resume by `curstate`, not only by log
lines: `resume` may print `halted due to single-step.` while stepping off a
breakpoint — that is **not** a failure.

**Terminal 3 — GDB** (after the Vexriscv fork is listening on :3333)

Start GDB with the ELF for **symbols** (attach-only or demo-debug):

```sh
riscv64-unknown-elf-gdb demo/demo.elf
```

#### Attach and inspect

```gdb
set remotetimeout 300
set pagination off
set arch riscv:rv32
target extended-remote localhost:3333
info registers
x/6i $pc
```

`vexriscv_swd_riscv_master.cfg` sets `-event gdb-attach halt`, so GDB attaches to an
**already-halted** target — no `monitor halt` is required.

#### Debug the demo app (`break` / `continue` / `bt`)

If litex_sim is passed with **`--ram-init=demo.bin`** :

```gdb
set remotetimeout 300
set pagination off
set arch riscv:rv32
target extended-remote localhost:3333
# Image is already in main_ram via --ram-init=demo.bin.

x/8xw 0x40000000        # confirm preload (e.g. 0x0b00006f 0x00000013 ...)
set $pc = 0x40000000    # re-enter demo at _start so main is hit cleanly
break main
continue
bt
```

Expected: stop at `main` (typically around `0x4000069c`); `bt` shows `#0  main ()`.

---

## Open items (not blocking sim three-terminal)

| Item | Notes |
| --- | --- |
| **Arty + CMSIS-DAP** | Next host-visible milestone |
| **`DPIDR` / `AP_IDR` finalize** | Placeholders still `0x0BA11AAB` / `0x74726976` |
| **Gerrit 9786 merge** | Published at [disdi/openocd `vexriscv-gateway`](https://github.com/disdi/openocd/tree/vexriscv-gateway); 9786 still unmerged upstream (plus two fixes on that branch) |

---
