# System Integration — SWD


Goal is **host-visible integration only** (LiteX SoC, OpenOCD, GDB). Target-side SWD
RTL (`SwdPhy` / `SwdDp` / `SwdDmiGateway`) is Phase **2A–2C** and is not re-defined here.

---

**Code repositories**

| Piece | Where | Status |
| --- | --- | --- |
| SWD DTM (`DebugTransportModuleSwd`) + `DebugModuleFiber.withSwdTransport()` | SpinalHDL [#1956](https://github.com/SpinalHDL/SpinalHDL/pull/1956) | merged 2026-09-08 |
| `spinal.lib.com.swd` split (`Swd` / `SwdPhy` / `SwdDp`) | SpinalHDL [#1966](https://github.com/SpinalHDL/SpinalHDL/pull/1966) | merged 2026-09-19 |
| VexRiscv SMP cluster `--swd` | VexRiscv [#483](https://github.com/SpinalHDL/VexRiscv/pull/483), [#499](https://github.com/SpinalHDL/VexRiscv/pull/499) | merged 2026-09-08 / 09-19 |
| **VexiiRiscv** LiteX SoC `--with-swd` + MicroSoc `--swd` | VexiiRiscv [#184](https://github.com/SpinalHDL/VexiiRiscv/pull/184) | merged 2026-09-23 |
| JTAG on Xilinx USER chains (`add_cpu_jtag_debug`, `--with-cpu-jtag-debug`) | LiteX [#2572](https://github.com/enjoy-digital/litex/pull/2572) + linux-on-litex-vexriscv [#459](https://github.com/litex-hub/linux-on-litex-vexriscv/pull/459) | merged 2026-09-10 |
| LiteX: `swdremote` sim module, OpenOCD configs, `--with-swd-debug` for `vexriscv_smp` | <https://github.com/disdi/litex/tree/swd> | branch, not yet proposed upstream |
| linux-on-litex-vexriscv: SWD pads on Arty Pmod JB | <https://github.com/disdi/linux-on-litex-vexriscv/tree/swd-arty> | branch, waits for the LiteX part |
| OpenOCD (Vexriscv fork) | <https://github.com/disdi/openocd/tree/vexriscv-gateway> | branch; Gerrit [9786](https://review.openocd.org/c/openocd/+/9786) + gateway backend |
| Black Magic Debug: DMI gateway AP support (no OpenOCD) | blackmagic [#2322](https://codeberg.org/blackmagic-debug/blackmagic/pulls/2322) — `disdi:feature/riscv-swd-dmi-gateway` | open, submitted 2026-09-25 — see [Black Magic Probe](#black-magic-probe-no-openocd) |


**OpenOCD (host ONLY)** — :

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

## Simulation based workflow using verilator

### Side-by-side

| Terminal | JTAG — **full three-terminal ✅** | SWD — **full three-terminal ✅** |
| --- | --- | --- |
| **1 — sim** | `litex_sim … --with-privileged-debug --jtag-tap --with-jtagremote` → TCP **44853** (`jtagremote`) | `litex_sim … --with-privileged-debug --with-swd-debug --with-swdremote` → TCP **44854** (`swdremote`); add `--ram-init=demo.bin` for demo debug |
| **2 — OpenOCD** | Stock `riscv` target + **fabric** TAP — no vendor BSCAN in sim; examines hart; GDB **:3333** | `transport select swd` + DAP + **Vexriscv fork** `riscv`; examines hart; GDB **:3333** |
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

**SWD Reading dmstatus, all the way down**

![flow](images/swd_flow.png)

**Terminal 1 — sim (keep running)**

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

## Hardware based workflow using Arty

Reference manual: <https://digilent.com/reference/programmable-logic/arty-a7/reference-manual>


| | |
| --- | --- |
| Device | `xc7a35ticsg324-1L` (`a7-35` variant) |
| System clock | `clk100`, 100 MHz |
| USB | On-board FTDI FT2232HQ — **USB-JTAG (programming) + USB-UART (console)** on one cable |
| Programmer | OpenOCD via `openocd_xc7_ft2232.cfg` + `bscan_spi_xc7a35t.bit` |
| PMOD connectors | JA/JB/JC/JD → `pmoda`/`pmodb`/`pmodc`/`pmodd` |
| SWD probe | External CMSIS-DAP (MCU-Link) on **Pmod JB** — not the on-board FTDI |


### JTAG on Arty — end-to-end workflow

Official stack only (`--with-privileged-debug`).

`--with-privileged-debug` alone is **not enough** on hardware. Without `--jtag-tap` the DTM is
tunneled, and its `debugPort_*` signals need a vendor boundary-scan primitive (`BSCANE2` on a
Xilinx USER chain). That binding is now upstream as an explicit second flag,
**`--with-cpu-jtag-debug`** — LiteX [#2572](https://github.com/enjoy-digital/litex/pull/2572)
(`LiteXSoC.add_cpu_jtag_debug()`, default USER4, IR `0x23`) and linux-on-litex-vexriscv
[#459](https://github.com/litex-hub/linux-on-litex-vexriscv/pull/459). USER1 stays free for
`jtagbone`. It replaces the original
[#458](https://github.com/litex-hub/linux-on-litex-vexriscv/pull/458), which was closed unmerged;
the hardware results below were taken with #458's `BSCANE2` instance, the same USER4 / IR `0x23`
binding.

**Prerequisites**

- Arty
- OpenOCD master with standard RISC-V target
- `riscv64-unknown-elf-gdb`

**Configs**

| File | Role |
| --- | --- |
| `openocd_arty_bscan.cfg` | Fits on-board FT2232 into the Xilinx TAP |
| `openocd_arty_official.cfg` | JTAG on Arty hardware. Composes `openocd_arty_bscan.cfg` (adapter + Xilinx TAP) with `riscv_jtag_tunneled.tcl` (the `riscv` target + `use_bscan_tunnel`). |


Terminal 1 — Build and Flash on Arty

```bash
# Stock LiteX + linux-on-litex-vexriscv master (litex#2572 / linux-on-litex-vexriscv#459)
./make.py --board=arty --cpu-count=1 --with-privileged-debug --with-cpu-jtag-debug --build --load
```

Expected in OpenOCD: `Examined RISC-V core; found 1 harts` and `XLEN=32, misa=0x40141101`.

Terminal 2 — OpenOCD (after Terminal 1 is up)

```bash
openocd -f litex/litex/tools/debug/openocd_arty_official.cfg
```

Terminal 3 — GDB (after OpenOCD is ready)



```bash
riscv64-unknown-elf-gdb -ex "set arch riscv:rv32"   -ex "target extended-remote localhost:3333"   linux-on-litex-vexriscv/build/arty/software/bios/bios.elf
```

---

### SWD on Arty — end-to-end workflow

Official stack only (`--with-swd-debug`; that flag implies `--with-privileged-debug`).
One transport per bitstream — do not combine with `--jtag-tap`.

`--with-swd-debug` alone is **not enough** on hardware. Unlike JTAG (which reuses the on-board FT2232 as a tunneled TAP), SWD needs an **external CMSIS-DAP probe** and two **user I/O** pins. Pinout lives in
[`soc_linux.py`](https://github.com/disdi/linux-on-litex-vexriscv/blob/swd-arty/soc_linux.py)
(`_swd_pmod_io` / `add_cpu_swd_debug`) on
<https://github.com/disdi/linux-on-litex-vexriscv/tree/swd-arty>.

**Prerequisites**

- Arty
- CMSIS-DAP probe (MCU-Link is the verified one) + jumper wires
- OpenOCD **master** for the raw-AP smoke; the **Vexriscv fork**
  ([disdi/openocd `vexriscv-gateway`](https://github.com/disdi/openocd/tree/vexriscv-gateway)) for GDB support.
- `riscv64-unknown-elf-gdb`

**Hardware connection**

Two USB cables to the host. The FTDI does **not** carry SWD.

```text
Host PC
 ├─ USB ── FT2232 (Arty J10) ── bitstream load + UART console
 └─ USB ── MCU-Link (CMSIS-DAP)
              SWCLK ──► JB3 ──► cluster swd_clk ──► SwdPhy
              SWDIO ◄─► JB7 ── IOBUF (swdio_i / o / oe)
                                 └── SwdPhy → SwdDp → DMI gateway → DebugModule
```

`--with-swd-debug` brings SWCLK / SWDIO out on **Pmod JB** (high-speed header: no 200 Ω series resistors, which matters for bidirectional SWDIO turnaround). Do **not** use JA or JD.

| Signal | LiteX pin | Pmod JB | FPGA ball | Notes |
| --- | --- | --- | --- | --- |
| **SWCLK** | `pmodb:2` | **JB3** | `D15` | Probe-driven, gated clock |
| **SWDIO** | `pmodb:4` | **JB7** | `J17` | Bidirectional; FPGA `PULLUP TRUE` (ADI) |
| **GND** | — | **JB11** | — | Common ground (required) |
| **GND (2nd)** | — | **JB5** | — | **Required** — second ground return, see below |
| **3.3 V (VTref)** | — | **JB12** | — | **Required for the MCU-Link** — see below |

Looking into the 12-pin Pmod:

```text
JB1        JB2  JB3=SWCLK  JB4   JB5=GND(2nd)  JB6=3V3
JB7=SWDIO  JB8  JB9        JB10  JB11=GND      JB12=3V3 (VTref)
```

MCU-Link 10-pin Cortex debug header → Arty:

```text
MCU-Link pin 4 (SWCLK)    → Arty JB3
MCU-Link pin 2 (SWDIO)    → Arty JB7
MCU-Link pin 3 (GND)      → Arty JB11
MCU-Link pin 5 (GND)      → Arty JB5    (second ground, required)
MCU-Link pin 1 (VTref)    → Arty JB12   (required on the MCU-Link)
```

**Configs**

| File | Role |
| --- | --- |
| `openocd_arty_swd.cfg` | CMSIS-DAP adapter. Hardware sibling of `openocd_swd_remote.cfg` — same DAP/DMI helpers, `remote_bitbang` swapped for `cmsis-dap` + `usb_bulk`. |
| `vexriscv_swd.cfg` | SW-DP + DAP + `vexriscv_dmi_read/write` + `vexriscv_swd_smoke` — **reused from sim, unchanged** |
| `vexriscv_swd_riscv_master.cfg` | Vexriscv fork: `dtm create -type vexriscv-gateway` + `riscv` + `gdb-attach halt` — **reused from sim, unchanged** |

Terminal 1 — Build and Flash on Arty

```bash
#   Support for SWD added to https://github.com/disdi/linux-on-litex-vexriscv/tree/swd-arty
./make.py --board=arty --cpu-count=1 --with-swd-debug --build --load
```

The first SWD build regenerates the cluster via sbt (no `_Swd` netlist ships prebuilt).
Expected name: `VexRiscvLitexSmpCluster_Cc1_…_Ood_Pd_Hb1_Swd`.

Terminal 2 — raw-AP smoke (stock master; no GDB)

```bash
openocd -s tcl \
  -f litex/litex/tools/debug/openocd_arty_swd.cfg \
  -f litex/litex/tools/debug/vexriscv_swd.cfg \
  -c init -c vexriscv_swd_smoke -c shutdown
```

Success indicators:

```text
Info : SWD DPIDR 0x0ba11aab
AP_IDR   = 0x74726976
dmstatus = 0x004c0c82 (version=2 authenticated=1 allrunning=1 allhalted=0)
PASS: SWD -> SW-DP -> DMI gateway -> DebugModule
```

`dmstatus` is bit-identical to the sim value.

Terminal 2 — `riscv` target + GDB server (Vexriscv fork: [disdi/openocd `vexriscv-gateway`](https://github.com/disdi/openocd/tree/vexriscv-gateway))

```bash
# Use the openocd binary built from:
#   https://github.com/disdi/openocd/tree/vexriscv-gateway
openocd -s tcl \
  -f litex/litex/tools/debug/openocd_arty_swd.cfg \
  -f litex/litex/tools/debug/vexriscv_swd.cfg \
  -f litex/litex/tools/debug/vexriscv_swd_riscv_master.cfg
```

Success indicators:

```text
Info : SWD DPIDR 0x0ba11aab
Info : [vexriscv.rv] Examined RISC-V core
Info : [vexriscv.rv]  XLEN=32, misa=0x40141101
```

`misa=0x40141101` = RV32 I+M+A+S+U.

Terminal 3 — GDB (after OpenOCD is ready)

```bash
riscv64-unknown-elf-gdb -ex "set arch riscv:rv32"   -ex "target extended-remote localhost:3333"   linux-on-litex-vexriscv/build/arty/software/bios/bios.elf
```

Hardware is not limited the way sim is: GDB `load` and `stepi` both work (CMSIS-DAP at
1 MHz vs `swdremote` pacing). Debug `demo.elf` (linked at `0x40000000`):

```gdb
monitor halt
load demo/demo.elf
set $pc = 0x40000000
break main
continue
bt
```

Expected: stop at `main` (typically around `0x4000069c`); `bt` shows `#0  main ()`.

---

## VexiiRiscv over SWD

The same SWD transport and `DebugModule` now also serve **VexiiRiscv**
[VexiiRiscv#184](https://github.com/SpinalHDL/VexiiRiscv/pull/184). No new
transport RTL was needed. VexiiRiscv builds its debug logic from SpinalHDL's
`DebugModuleSocFiber`, and the SWD DTM is added in that fiber's body with
`dm.withSwdTransport()`. `SwdPhy` / `SwdDp` / `SwdPhyDp` in the generated netlist are
byte-identical to the VexRiscv SMP cluster's, so everything on the host side (probe, OpenOCD fork,
configs) is reused unchanged. The SWD transport is the same SpinalHDL code in both CPUs, and the generated Verilog confirms it.


| SoC | Option | Top-level ports |
| --- | --- | --- |
| LiteX SoC (`vexiiriscv.soc.litex.SocGen`) | `--with-swd` | `debug_swd_swd_swclk`, `debug_swd_swd_swdio_{read,write,writeEnable}` |
| MicroSoc (`vexiiriscv.soc.micro.MicroSocGen`) | `--jtag-tap=false --swd=true` | `socCtrl_debugModule_swd_swd_*` |

- One DTM at a time (RISC-V Debug Spec Ch. 6): `--with-swd` together with `--with-jtag-tap` /
  `--with-jtag-instruction` is refused at elaboration.
- SWDIO is three wires (`read` / `write` / `writeEnable`); the tristate belongs to the integrator.
- A `--with-jtag-tap` netlist is unchanged by #184.

**LiteX integration — pending.** LiteX's `cpu/vexiiriscv` still pins a VexiiRiscv revision
without SWD, and its `--with-swd-debug` option for VexiiRiscv (four ports, `add_swd()`, reset
wiring) is not published yet; it will be proposed together with the pin bump.

### Hardware results

Same MCU-Link, wiring and OpenOCD fork as the VexRiscv lane above.

| Configuration | Board | Build | Result |
| --- | --- | --- | --- |
| RV32 `linux` (RV32IMA + S/U), 1 hart | Arty A7-35T, 100 MHz | WNS 0.233 ns, 41.6 % LUT | DPIDR `0x0ba11aab`, AP_IDR `0x74726976`, `misa=0x40141101`; halt / step / resume; GDB `load` (67 KB/s), `break main` / `help`, `stepi`, `bt` |
| RV64 `debian` (RV64IMAFDC + S/U), 1 hart | Arty A7-35T, 100 MHz | WNS 0.131 ns, 75 % LUT / 86 % BRAM | `XLEN=64`, `misa=0x800000000014112d`; halt / step / resume; GDB (`set arch riscv:rv64`): `load`, breakpoints, 64-bit register write / read-back, FPU registers (`fcsr`, `ft0`), `bt` |
| RV64 `debian`, **2 harts** | **Arty A7-100T, 80 MHz** | WNS 0.532 ns, 44 % LUT | both harts on one DTM; **independent** halt / step / resume per hart; GDB sees one thread per hart |

Two harts of the RV64 variant do not fit the A7-35T (estimated ~128 % LUT, ~126 % BRAM), hence A7-100T at 80 MHz is used which meets timing.

Log lines that are expected on VexiiRiscv:

- `Found 0 triggers` — LiteX's default VexiiRiscv configuration has no hardware triggers (same
  over JTAG); software breakpoints in RAM work.
- `Failed to read memory (addr=0x3ffffffc)` — GDB peeks at the word before `_start`, which is
  unmapped; the DM correctly reports the bus error.
- `Core N could not be made part of halt group 1` (two harts) — this DM implements no halt
  groups, which the spec allows; OpenOCD halts the harts one after the other.

### Two harts: OpenOCD configuration

One `riscv` target per hart, all on the **same** DTM (DMI is shared by every hart behind the DM;
the hart is chosen by `-coreid`, i.e. `hartsel`). Source it in place of
`vexriscv_swd_riscv_master.cfg`, after `openocd_arty_swd.cfg` and `vexriscv_swd.cfg`.

For GDB, one thread per hart:

```tcl
dtm create vexriscv.dtm -type vexriscv-gateway -dap vexriscv.dap -ap-num 0

target create vexriscv.rv0 riscv -dtm vexriscv.dtm -coreid 0 -rtos hwthread
target create vexriscv.rv1 riscv -dtm vexriscv.dtm -coreid 1 -rtos hwthread
target smp vexriscv.rv0 vexriscv.rv1

riscv set_command_timeout_sec 120
vexriscv.rv0 configure -event gdb-attach halt
```

```gdb
set arch riscv:rv64
target extended-remote localhost:3333
info threads
#  * 1  Thread 1 "vexriscv.rv0" ...
#    2  Thread 2 "vexriscv.rv1" ... 0x00000000000000a4 in ?? ()
thread 2
p/x $mhartid        # 0x1
```

For independent per-hart control, drop `-rtos hwthread` and `target smp`, then select a hart with
`targets vexriscv.rv0` / `targets vexriscv.rv1`. Halting hart 1 leaves hart 0 running
(`vexriscv.rv0 curstate` → `running`, `vexriscv.rv1 curstate` → `halted`), and each hart steps and
resumes on its own.

---

### DMI gateway vs Mem-AP (the RP2350 approach)

The closest production precedent is the Raspberry Pi **RP2350**: SWD pins, an ARM SW-DP, and a
RISC-V Debug Module behind it
([RP2350 datasheet](https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf) §3.5, §3.8).
Both designs are the same up to one layer. They differ only in the **access port** between the DP
and the DM:

| | RP2350 | This design (VexRiscv / VexiiRiscv) |
| --- | --- | --- |
| AP type | standard CoreSight **APB Mem-AP**, at `0x0a000` in the debug address space | custom 4-register **designer AP** — `AP_IDR` / `DMI_ADDR` / `DMI_DATA` / `POSTED_READ` ([Phase 2C](./Phase2C.md)) |
| Reaching DM register `n` | memory-mapped at `n × 4`: write the address to `TAR`, then access `DRW` (or `BD0`–`BD3`) | write `n` to `DMI_ADDR`, then read / write `DMI_DATA` |
| SWD packets per DM access | 1–4, depending on the access pattern | 1–2, depending on the access pattern |
| DP architecture | ADIv6 (`SELECT` holds the AP base address) | ADIv5 (`APSEL` field) |
| DP state at power-up | Dormant (needs the selection-alert wake-up sequence) | active |
| Standing in the RISC-V Debug Spec | **custom DTM** (Ch. 6) | **custom DTM** (Ch. 6) — the same |

**Why this design keeps the gateway.** What a Mem-AP would buy is abillity to speak Mem-AP lingo from ARM world which on the wire it is not cheap.

#### Speed

Both designs are an **address register plus a data register** — `TAR` + `DRW` on a Mem-AP, `DMI_ADDR` + `DMI_DATA` on the gateway However, the real difference is the Mem-AP's **banked window**. Host side tooling like OpenOCD's Mem-AP layer  reads through `BD0`–`BD3`: `TAR` is set to a 16-byte-aligned address, and the four words of that window are then reached without touching `TAR` again. But `BD0`–`BD3` sit in a different AP register bank from `TAR`, so moving to a new window costs a DP `SELECT` write, the `TAR` write, and a `SELECT` write back. 

The gateway keeps all its registers in bank 0 and never writes `SELECT`.

This is explained below for SWD packets per DM access for both the two backends:

| Access | Gateway | Mem-AP (`BD` path) |
| --- | --- | --- |
| Same register as the previous access | 1 | 1 |
| Another register in the same 4-register window | 2 | **1** |
| Register in a different window | **2** | 4 (`SELECT` + `TAR` + `SELECT` + `BD`) |
| End of a batch that read something | + 1 (`RDBUFF`) | + 1 (`RDBUFF`) |

Also RISC-V DM's registers cluster in those windows — `dmcontrol` / `dmstatus`, `abstractcs` /
`command`, and `data0`–`data3` each share one — so for real operations:

| Operation | Gateway | Mem-AP |
| --- | --- | --- |
| Halt: write `dmcontrol`, poll `dmstatus` N times | 2 + 2 + (N − 1) | 4 + N |
| Read a GPR, RV32: write `command`, poll `abstractcs`, read `data0` | 7 | 10 |
| Read a GPR, RV64: also read `data1` | 9 | 11 |
| Poll the same register | 1 each | 1 each |

So on the wire. the gateway is a few packets ahead.

#### Area

In **area** the gateway is clearly smaller. Its AP is a 7-bit address register plus one
DebugBus request path; the whole SWD DTM (PHY, DP, gateway, clock crossing) is 216 LUTs on an
Artix-7. The SWD DTM breaks down as:

| Part of `DebugTransportModuleSwd` | LUTs | FFs | Also needed with a Mem-AP? |
| --- | --- | --- | --- |
| `SwdPhy` — wire protocol | 95 | 130 | yes, same DP |
| `SwdDp` — DP registers | 25 | 50 | yes |
| Response clock crossing (`FlowCCByToggle`) | 34 | 70 | yes — any AP needs a crossing to the DM (Hazard3 uses an async APB bridge) |
| **Gateway AP + command clock crossing** | **60** | **115** | **no — this is the part a Mem-AP would replace** |
| Total | 216 | 409 | |

So the gateway costs at most 60 LUTs / 115 FFs, and part of that is the command-side clock crossing
a Mem-AP would need too. A Mem-AP in its place needs at least a 32-bit `TAR`, a `CSW` register
(access size, auto-increment, protection), the banked `BD` decode, an address incrementer and an
APB manager — roughly 100–150 LUTs by estimate (not synthesised).

#### Context - Mixed Architecture vs Pure RISC-V

RP2350 is a dual-architecture part: each core
slot holds an Arm Cortex-M33 and a Hazard3, selected at boot. Its debug complex is Arm CoreSight
around **one** SW-DP, with two AHB5 Mem-APs (debug address space `0x02000` / `0x04000`) for the two
Cortex-M33s, the APB Mem-AP at `0x0a000` for the RISC-V DM, and RP-AP for chip-level control
([datasheet](https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf) §3.5.2–3.5.3, Figure
6). The SW-DP and the Mem-AP infrastructure are there for the Arm cores anyway. And the Hazard3 DM
already exposes a byte-addressed APB port, as shown above. Connecting it through one more APB
Mem-AP therefore costs almost nothing extra, needs no new transport RTL, and makes the RISC-V
cores reachable through the same port, the same way, as the Arm ones.

This design starts from the opposite position: there is no Arm debug IP to reuse. The SW-DP is
written from scratch in SpinalHDL, and the SpinalHDL DM exposes a word-addressed `DebugBus(7)`, not
APB. Building a Mem-AP would add a CoreSight-shaped register set and an APB manager only to reach a
DM that doesn't speak APB; the gateway reaches `DebugBus` directly. The one thing the Mem-AP shape
would buy is support in tools that only speak Mem-AP — and that is a host-side problem, solved here
by the `vexriscv-gateway` OpenOCD backend without touching the RTL.

| | Mem-AP fits when | Gateway fits when |
| --- | --- | --- |
| Debug IP already on chip | an Arm CoreSight DAP is present (e.g. for Arm cores on the same die) | the DP is your own RTL |
| DM port | APB, byte-addressed (Hazard3) | word-addressed bus (`DebugBus`) |
| Host tooling | must work with tools that only drive Mem-APs | you control the host side (OpenOCD backend) |
| Area | the AP is already paid for | the smallest AP that does the job |

#### RISC-V-only chips: why the gateway is usually the better choice

Take the Arm cores away and RP2350's main reason for a Mem-AP disappears: there is no CoreSight
debug IP on the die to reuse. For a SoC or MCU whose only processors are RISC-V, the gateway is
usually the better fit:

- **No CoreSight IP to reuse.** The SW-DP has to be built anyway (here it is SpinalHDL). A Mem-AP
  on top of it adds `TAR`, `CSW`, the banked `BD` decode and an APB manager, with no functional
  gain: the DM is the only thing behind the AP.
- **The DM has a simple word-addressed port.** SpinalHDL's `DebugModule` speaks `DebugBus(7)`;
  the gateway connects to it directly, whereas a Mem-AP would first need an APB front end on the
  DM.
- **It is the smaller AP,** and on the wire it is even or slightly ahead (see the tables above) —
  by tens of LUTs and a few packets per operation, so a tie-breaker rather than the main reason.

---

## Black Magic Probe (OpenOCD alternative)

A [Black Magic Probe](https://black-magic.org/) (BMP) runs the GDB server **on the probe**: GDB
connects straight to its USB serial port, with no OpenOCD in between. Stock BMP firmware reads
this design's SW-DP but cannot use the DMI gateway AP. Support is proposed in
**blackmagic [#2322](https://codeberg.org/blackmagic-debug/blackmagic/pulls/2322)**
(`riscv_adi_dtm: support the SpinalHDL SWD "DMI gateway" AP`; branch
`disdi:feature/riscv-swd-dmi-gateway`). No RTL change was needed.

### Wiring (BMP v2.3, same Arty Pmod JB harness)

| BMP 10-pin | Signal | Arty |
| --- | --- | --- |
| 1 | VTref (sets the probe's I/O level) | JB12 (3.3 V) |
| 2 | SWDIO | JB7 |
| 4 | SWCLK | JB3 |
| 3 / 5 / 9 | GND | JB11, plus the second ground JP2.3 → JB5 |

### Hardware results

| Board / image | Result |
| --- | --- |
| **Arty A7-35T**, VexRiscv SMP (RV32IMA), golden image | `rv32ima (exts 00141101)`. `load demo.elf` (6552 B), `break main` `0x4000069c`, `stepi` → `0x400006b0`, `break help` `0x40000644`, `bt` `#0 help` / `#1 0x400006cc main` — **identical to the OpenOCD + MCU-Link lane**; `compare-sections` matches |
| **Arty A7-100T**, VexiiRiscv RV64 × 2 harts | DM v0.13, **both harts** found as two targets; attach, registers, single step, resume/halt per hart |


### Use

```sh
# Probe firmware (BMP v2.x), from the blackmagic tree with #2322  :
meson setup build-fw --cross-file cross-file/bmp-v1-v2-riscv.ini && ninja -C build-fw
dfu-util -d 1d50:6018,:6017 -s 0x08002000:leave -D build-fw/blackmagic_bmp_v1_v2_firmware.bin

# GDB, straight to the probe (no OpenOCD):
riscv64-unknown-elf-gdb -ex 'set arch riscv:rv32' -ex 'set mem inaccessible-by-default off' \
  -ex 'target extended-remote /dev/ttyACM0' -ex 'monitor swdp_scan' -ex 'attach 1' demo/demo.elf
(gdb) load
(gdb) break main
(gdb) continue
```
