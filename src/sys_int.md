# System Integration — SWD


Goal is **host-visible integration only** (LiteX SoC, OpenOCD, GDB).

| Step | Content | Status |
| --- | --- | --- |
| **1** | Cluster / `core.py` / `swdremote` / `litex_sim` / Makefile + OpenOCD smoke | ✅ Completed |
| **2** | Custom OpenOCD option A (`riscv` glue) + GDB; finalize IDs if host hard-codes them | 🟡 DAP/DMI helpers done; GDB open |

**Note:** 
- Support for official RISC-V DM only (`withPrivilegedDebug`). 
- One Debug transport per build — 
**no** JTAG-DTM + SWD-DTM on the same `DebugBus` without arbitration. Do **not** set `JTAG_SIM=1` and `SWD_SIM=1` together.

---

**Code Repository :**

- Litex    - https://github.com/disdi/litex/tree/swd
- VexRiscv - https://github.com/disdi/VexRiscv/tree/phase3

(Update submodules in [pythondata-cpu-vexriscv_smp](https://github.com/disdi/pythondata-cpu-vexriscv_smp) to above branch)

---

## SWD specific tasks

### Step 1 (Already done)

- [x] Create `DebugTransportModuleSwd` with `io.swclk` (**input**, probe-driven) + `io.swdio` as `i`/`o`/`oe` — Phase **2A–2C**
- [x] Add `withSwdTransport()` to `DebugModuleFiber` (mutually exclusive with `withJtagTap()` per build) — Phase **2C**
- [x] LiteX SMP cluster: `swd` param, `--swd` CLI, three-wire `debugPort_swclk` / `swdio_{i,o,oe}`, `noTap` guarded `!jtagTap && !swd` — Phase **3**
- [x] LiteX sim: `--with-swd-debug`, `_Swd` netlist token, `add_swd()`, `swdremote` on TCP **44854**, `SWD_SIM=1` Makefile targets — Phase **3**
- [x] OpenOCD smoke on sim: DPIDR `0x0ba11aab` + `dap apreg` → `dmstatus` `0x004c0c82`
- [x] OpenOCD cfgs: `openocd_swd_remote.cfg` + `vexriscv_swd.cfg` (DAP + `vexriscv_dmi_read/write` + smoke)
- [x] Cluster asserts: reject `swd && jtagTap`; require `privilegedDebug` when `swd`

### Step 2 — host tooling + GDB (open)

- [~] Custom OpenOCD target: DAP/DMI procs done; **`riscv` target glue + GDB still open**
  - Exit: halt / resume / register read of the **sim CPU** over SWD (analogous to JTAG three-terminal)
  - Files: `vexriscv_swd.cfg` (extend), optional interface cfgs for hardware
  - Requires real hart in LiteX sim (not Phase2C stub `DebugHartBus`)
- [ ] Finalize `DPIDR` / `AP_IDR` before host scripts hard-code them  
  - Rules + placeholders owned by Phase **2C** (`DPIDR=0x0BA11AAB`, `AP_IDR=0x74726976`)  
  - Must **not** look like ARM Cortex SW-DP (`0x2ba01477` / DESIGNER `0x23B`)
- [ ] GDB workflow on sim: `target extended-remote :3333`, `set remotetimeout 120`, `monitor reset halt`, `info registers`


---

### JTAG — End to End Workflow

Official stack only (`--with-privileged-debug` + full JTAG TAP in sim) is already supported.

**Prerequisites**

-  `litex_sim`
-  `OpenOCD`
-  `riscv64-unknown-elf-gdb`

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
riscv64-unknown-elf-gdb -ex "set remotetimeout 120" \
  -ex "set remote disable-packet-optimization 1" \
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

---

### SWD — what is possible **now**

**step 1** landed LiteX + `swdremote` + OpenOCD smoke. In Terminal 3, **NO** GDB yet because `vexriscv_swd.cfg` deliberately does **not** `target create riscv` (stock OpenOCD has no RISC-V-over-SWD path).

**Prerequisites (SWD-specific)**

- `litex_sim`
- OpenOCD with SWD `remote_bitbang`
- GDB **not** usable on this path until step 2

**Configs**

| File | Role |
| --- | --- |
| `openocd_swd_remote.cfg` | `remote_bitbang` → `localhost:44854`, `transport select swd` |
| `vexriscv_swd.cfg` | SW-DP + DAP + `vexriscv_dmi_read/write` + `vexriscv_swd_smoke` — **no** `riscv` target |

**Terminal 1 — sim (keep running)**

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
```

| Flag | Role |
| --- | --- |
| `--integrated-main-ram-size=0x10000` | 64 KiB main RAM for sim |
| `--cpu-type=vexriscv_smp` / `--cpu-variant=linux` / `--cpu-count=1` | SMP Linux-capable cluster, 1 hart |
| `--with-privileged-debug` | Official `DebugModule` (required; SWD is official-stack only) |
| `--with-swd-debug` | Cluster SWD transport + `_Swd` netlist token; forces privileged debug on LiteX side |
| `--with-swdremote` | LiteX sim module `swdremote` — OpenOCD `remote_bitbang` SWD on TCP **44854** |
| `--non-interactive` | Keep sim running as the target for OpenOCD |

Wait for `Found port 44854` and BIOS prompt `litex>`. First run may take several minutes (cluster regen + Verilator compile). 

Do **NOT** pass `--jtag-tap` / `--with-jtagremote` here.


**Terminal 2 — OpenOCD smoke (after Terminal 1 is up)**

One-shot (connect, `vexriscv_swd_smoke`, exit):

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

**Terminal 3 — GDB**

```text
Not supported yet (step 2).
No :3333 riscv GDB server from the SWD configs above.
```


when Step 2 is done — same shape as JTAG:

| Terminal | Intended SWD flow (not done) |
| --- | --- |
| 1 | `litex_sim … --with-privileged-debug --with-swd-debug --with-swdremote --non-interactive` |
| 2 | OpenOCD + SWD + **`riscv` examine** → listen **:3333** |
| 3 | `riscv64-unknown-elf-gdb` → `target extended-remote localhost:3333` → halt / regs / load |

---

## Host attach workflows (sim only)

### Side-by-side

| Terminal | JTAG — **full three-terminal ✅** | SWD — **partial 🟡** |
| --- | --- | --- |
| **1 — sim** | `litex_sim … --with-privileged-debug --jtag-tap --with-jtagremote` → TCP **44853** (`jtagremote`) | `litex_sim … --with-privileged-debug --with-swd-debug --with-swdremote` → TCP **44854** (`swdremote`) |
| **2 — OpenOCD** | Stock `riscv` target + BSCAN tunnel; examines hart; GDB server **:3333** | `transport select swd` + DAP; **DPIDR** / **`dmstatus` via `dap apreg`**; **no** `riscv` target yet |
| **3 — GDB** | `target extended-remote localhost:3333` → halt / regs / load | ❌ **Not available** until step 2 (`riscv` glue + GDB) |

| Capability | JTAG now | SWD now |
| --- | --- | --- |
| Verilator SoC + official DM | ✅ | ✅ (`_Swd` cluster) |
| Wire transport in sim | ✅ JTAG TAP + tunnel | ✅ SW-DP (`DebugTransportModuleSwd`) |
| OpenOCD sees transport | ✅ TAP `0x10003fff` | ✅ SWD DPIDR `0x0ba11aab` |
| Read `dmstatus` | ✅ via `riscv` / DMI | ✅ via `vexriscv_dmi_read 0x11` / smoke |
| `Examined RISC-V core; found 1 harts` | ✅ | ❌ step 2 |
| GDB halt / resume / `info registers` | ✅ | ❌ step 2 |
| `load demo.elf` / break / continue | ✅ | ❌ step 2 |
| OpenOCD binary | ✅ |  remote_bitbang SWD chars |

---

