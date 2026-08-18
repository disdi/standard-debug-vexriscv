# Phase 2A — SWD Protocol State Machine: Implementation & Verification



**Code Repository :**

Update submodules in [pythondata-cpu-vexriscv_smp](https://github.com/disdi/pythondata-cpu-vexriscv_smp) to below :

- SpinalHdl - https://github.com/disdi/SpinalHDL/tree/phase2a
- VexRiscv - https://github.com/disdi/VexRiscv/tree/phase2a

| Artifact | Path |
|---|---|
| RTL | `EXT/SpinalHDL/lib/src/main/scala/spinal/lib/cpu/riscv/debug/DebugTransportModuleSwd.scala` |
| Testbench | `EXT/VexRiscv/src/test/scala/vexriscv/DebugSwdTest.scala` |
| Run | `cd EXT/VexRiscv && sbt -batch "testOnly vexriscv.DebugSwdTest"` |

`EXT` = `pythondata-cpu-vexriscv-smp/pythondata_cpu_vexriscv_smp/verilog/ext`. `EXT/VexRiscv/build.sbt` compiles `EXT/SpinalHDL` from source, so the RTL and
testbench build in one sbt project with **no LiteX involvement**.

---

## 1. What is implemented — `SwdPhy`

`SwdPhy` is the ARM ADI SW-DP **line layer** (ADIv6.0 §B4): it speaks the 2-wire protocol
and terminates in a decoded-transaction seam. It contains no DP registers (Phase 2B) and no
`DebugBus` bridge (Phase 2C).

### 1.1 I/O

```text
swdio.i  : in  Bool   -- SWDIO as driven by the probe
swdio.o  : out Bool   -- SWDIO value when the target drives
swdio.oe : out Bool   -- target output enable
dp.cmd   : master Flow(SwdDpCmd)    -- decoded request        (2A -> 2B)
dp.rsp   : slave  Flow(SwdDpRsp)    -- ACK + read data        (2B -> 2A)
dp.wr    : master Flow(SwdDpWrite)  -- write commit           (2A -> 2B)
```

- **Clock = SWCLK.** The component's implicit clock domain is the probe-driven SWCLK.
  The target samples `swdio.i` and updates `swdio.o`/`swdio.oe` on the **rising edge**,
  matching the OpenOCD bitbang model (host sets data while SWCLK is low, samples target
  data while low).
- **No `inout`.** The tristate split (`i`/`o`/`oe`) is required because the cluster is a
  Verilog black box in LiteX.

### 1.2 The 2A↔2B seam (three flows)

A wire-protocol fact shapes the seam: **a write's ACK is sent before the 33-bit WDATA
phase**, so write data cannot ride in the request.

| Flow | Fired | Payload |
|---|---|---|
| `SwdDpCmd` | one-cycle pulse on the packet-request park edge, iff parity/stop/park all pass | `apNdp`, `rnw`, `addr = A[3:2]` |
| `SwdDpRsp` | must be presented by the DP **within the turnaround cycle** (an always-ready DP may simply hold it valid) | `ack` (OK=001/WAIT=010/FAULT=100), `rdata` |
| `SwdDpWrite` | one-cycle pulse after the 33rd WDATA bit | `data`, `parityOk` (false ⇒ WDATAERR material for 2B) |

The response is latched into a hold register on first sight (`rsp.valid` may be
combinational off `cmd` or held continuously); ACK and RDATA are driven from the
latched copy for the rest of the frame.


#### Read path — `READ_DATA → RELEASE → IDLE` (Fig B4-2)

![Read Operation](images/read_operation.png)


- 32 data bits LSB-first from `rspHold.rdata`, then even parity (`xorR`).
- No turnaround between ACK and RDATA (target keeps `oe=1`).
- `RELEASE`: `oDrive := False`, then `IDLE` (trailing Trn / release).

#### Write path — `WR_TRN → WRITE_DATA → IDLE` (Fig B4-1)

![Write Operation](images/write_operation.png)


- `WR_TRN`: two cycles with `oe=0` (`cnt` 0 then 1) = second turnaround.
- `WRITE_DATA`: shift in 32 bits + sample parity; fire `dp.wr` with `data` and `parityOk`.
- WDATA parity fail → `parityOk = false` (WDATAERR **material for 2B**), **not** protocol error.
- Return **direct** `WRITE_DATA → IDLE` (no `RELEASE`): host already owns the line. Diagram §1.4.2 also uses `WRITE_DATA --> IDLE`.

#### `ERROR` and line reset

| Diagram §1.4.2 | RTL |
|--------------|-----|
| `ERROR --> ERROR` (ignore traffic) | `ERROR`: `oDrive := False` only; no header parse |
| `ERROR --> IDLE` on line reset | `lineReset.hit` → **`RESET_WAIT`** → first low → **`IDLE`** |

Line reset is **orthogonal** (overrides any state): ≥50 consecutive highs on `swdio.i` while `!oDrive`; counter frozen/cleared while target drives so ACK/RDATA cannot fake a reset.

`RESET_WAIT` is an **RTL-only** gate so the target does not accept Start until the line has gone idle after the reset burst. Diagram §1.4.2 draws a direct `ERROR → IDLE`; recovery contract is the same.


---


## 2. How the testbench works — `DebugSwdTest`

### The bench is the probe

SWCLK is the DUT clock, and the bench **owns it**: no `forkStimulus` — every SWCLK cycle is
one call to `step(bit)`:

```text
fallingEdge(); set swdio.i = bit;      // host updates while SWCLK low
sample (swdio.o, swdio.oe);            // host samples while SWCLK low
risingEdge();                          // target samples/updates
```

This reproduces OpenOCD's `bitbang_swd_exchange` exactly: a host-driven bit is sampled by
the target at the rising edge ending its cycle; a target-driven bit read in cycle *k* is
the value the target registered at edge *k−1*. All multi-bit values are sent/collected
LSB first. `step` returns `(o, oe)`, so every helper can assert drive/release behavior
per cycle.


