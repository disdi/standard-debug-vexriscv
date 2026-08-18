# Phase 2C — DMI Gateway, Clock Crossing & DebugModule Integration

**Code Repository :**
- pythondata-cpu-vexriscv_smp - https://github.com/disdi/pythondata-cpu-vexriscv_smp/tree/phase2c

OR

Update submodules in [pythondata-cpu-vexriscv_smp](https://github.com/disdi/pythondata-cpu-vexriscv_smp) to below :

- SpinalHdl - https://github.com/disdi/SpinalHDL/tree/phase2c
- VexRiscv - https://github.com/disdi/VexRiscv/tree/phase2c

| Artifact | Path |
|---|---|
| RTL (`SwdDmiGateway`, `DebugTransportModuleSwd`) | `EXT/SpinalHDL/lib/src/main/scala/spinal/lib/cpu/riscv/debug/DebugTransportModuleSwd.scala` (same file as 2A/2B) |
| Fiber hook (`withSwdTransport()`) | `EXT/SpinalHDL/lib/src/main/scala/spinal/lib/cpu/riscv/debug/DebugModuleFiber.scala` |
| Testbench (incl. `SwdDmTestTop`) | `EXT/VexRiscv/src/test/scala/vexriscv/DebugSwdDmTest.scala` |
| Run | `cd EXT/VexRiscv && sbt -batch "testOnly vexriscv.DebugSwdDmTest"` (all: `"testOnly vexriscv.DebugSwdTest vexriscv.DebugSwdDpTest vexriscv.DebugSwdDmTest"`) |

`EXT` = `pythondata-cpu-vexriscv-smp/pythondata_cpu_vexriscv_smp/verilog/ext`. Still zero LiteX involvement.

---

## 1.Implementation of DMI for SWD


### 1.1 `SwdDmiGateway` — the RISC-V DMI gateway AP

Sits behind the 2B AP seam (`SwdApCmd`/`SwdApRsp`) and drives a `DebugBus` master —
the **same `DebugCmd`/`DebugRsp` interface the JTAG DTM produces**, which is the whole
point of the transport-agnostic design.

The DMI needs a 7-bit address and 32 bits of data. SWD offers, per transaction, one bit of DP/AP selection and two bits of register address. Four AP registers, total.


| AP `A[3:2]` | Register | Access | Behavior |
|---|---|---|---|
| `00` | `AP_IDR` | RO | identification constant (default `0x74726976` "triv") — completes locally in 1 SWCLK cycle |
| `01` | `DMI_ADDR` | RW | latches the 7-bit DMI word address; readable back — local |
| `10` | `DMI_DATA` | RW | performs the `DebugBus` transaction at `DMI_ADDR` (RnW from the SWD packet) |
| `11` | `POSTED_READ` | RO | last completed DMI **read** result — local |

Writes to RO registers complete OK with no effect. `SELECT.APSEL` is not decoded
(single-AP design). AP reads launch at the request (posted, per 2B); AP writes launch at
the WDATA commit carrying the data.

### 1.2 `DebugTransportModuleSwd` — the full transport

SWD pins → `SwdPhy` (2A) → `SwdDp` (2B) → `SwdDmiGateway` (2C) → `DebugBus`. The SWD side
elaborates under `ClockDomain(swclk, resetKind = BOOT)`; the `DebugBus` side under the
provided `debugCd`. This is the SWD counterpart of `DebugTransportModuleJtagTap`.

`DebugModuleFiber.withSwdTransport(dpidr, apIdr)` instantiates it alongside
`withJtagTap()` — same one-transport-per-build rule (direct `io.ctrl` connection, no
arbitration).

### 1.3 End-to-end dmstatus read (the step-2 exit), graphically

![phase2c](images/phase2c.png)

---

## 2. Testbench — `DebugSwdDmTest`

- **DUT = `SwdDmTestTop`**: the full transport + a real `DebugModule` (version 2, 1 hart,
  `progBufSize=2`, `datacount=1`) with a **stubbed `DebugHartBus`** — running, never
  halted, `hartToDm`/`resume.rsp` idle.
- **Two genuinely asynchronous clocks**: the shared `SwdHostDriver` bit-bangs SWCLK
  (bench-owned, via a `ClockDomain` handle over the pin) while `dut.clockDomain`
  free-runs via `forkStimulus` — DMI completion latency is variable by construction.
- **Host-style retry helpers**: `apWriteRetry`/`apReadRetry`/`rdbuff` retry on WAIT with
  bounded attempts — the same loop a real OpenOCD target would run. `dmiRead`/`dmiWrite`
  compose them into DMI operations.
- **Failure forensics built in**: on any unexpected ACK the harness reads CTRL/STAT and
  includes the sticky flags in the assertion message (`ackCheck`) — this is what cracked
  the phantom-completion bug (§4.2). The `sim(name, seed = …)` hook pins a failing seed
  for deterministic reproduction.

---

## 3. Verification

```sh
cd ~/fpga/pythondata-cpu-vexriscv-smp/pythondata_cpu_vexriscv_smp/verilog/ext/VexRiscv
sbt -batch "testOnly vexriscv.DebugSwdDmTest"
# expect: Tests: succeeded 7, failed 0, canceled 0, ignored 0, pending 0
sbt -batch "testOnly vexriscv.DebugSwdTest vexriscv.DebugSwdDpTest vexriscv.DebugSwdDmTest"
# expect: Tests: succeeded 25, failed 0, canceled 0, ignored 0, pending 0
```

---

## 4. Summary

Phases 2A–2C complete the **target-side RTL** of the SWD plan; the DebugBus now speaks SWD end-to-end in simulation. 
