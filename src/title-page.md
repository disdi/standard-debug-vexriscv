# Standard Debug Spec Milestone

Below are milestones planned in the project :

- [Phase 1A](./dtm_dmi.md) JTAG DTM + DMI Bus
- [Phase 1B](./dm.md) Core DM (dmcontrol/dmstatus)
- [Phase 1C](./csr.md) Debug CSRs
- [Phase 1D](./triggers.md) Triggers
- [Phase 2A](./Phase2A.md) SWD protocol state machine (`SwdPhy`)
- [Phase 2B](./Phase2B.md) SW-DP register file (`SwdDp`)
- [Phase 2C](./Phase2C.md) DMI gateway + clock crossing
- [Phase 3](./sys_int.md) Integration
- [Phase 4](./veri_test.md) Testing
- [Phase 5](./docu.md) Documentation

Phase 1 adds missing features in DebugModule from [ratified RISC-V Debug Specification](https://docs.riscv.org/reference/debug/).

Phase 2 adds a **target-side Arm Serial Wire Debug (SWD)** front-end that still drives the same RISC-V `DebugBus` used by the JTAG DTM. The Arm specification  is at [ADIv5.0–ADIv5.2 (IHI0031)](https://developer.arm.com/documentation/ihi0031/latest/).

```text
Host (SWCLK / SWDIO)
        │
   ┌────▼────┐
   │ SwdPhy  │  Phase 2A — wire protocol (framing, turnaround, line reset)
   └────┬────┘
        │ SwdDpCmd / SwdDpRsp / SwdDpWrite
   ┌────▼────┐
   │  SwdDp  │  Phase 2B — DP registers + ACK policy (OK / WAIT / FAULT)
   └────┬────┘
        │ SwdApCmd / SwdApRsp
   ┌────▼──────────┐
   │ SwdDmiGateway │  Phase 2C — custom DMI AP + SWCLK↔debug CDC
   └────┬──────────┘
        │ DebugBus (same as JTAG DTM)
   ┌────▼────────┐
   │ DebugModule │  Phases 1B–1D
   └─────────────┘
```

---

## How the SWD protocol works

### What SWD is

**Serial Wire Debug** is a **2-wire, synchronous, packet-based** host↔target link:

| Signal | Role |
|--------|------|
| **SWCLK** | Clock (usually driven by the probe/host) |
| **SWDIO** | Bidirectional data (one bit per clock) |

There is **no separate reset pin**. Recovery uses a **line reset** on SWDIO.

Logically, SWD talks to a **Debug Port (DP)**. The DP either answers for itself (DP registers) or forwards accesses to an **Access Port (AP)** that reaches the real debug resource. In this project the AP is a custom **RISC-V DMI gateway**, which drives the existing `DebugBus` into the Debug Module.

### One transaction on the wire

Every SWD access is **request → ACK → (optional data)**.

#### Packet request (host → target, 8 bits)

After optional idle cycles (SWDIO low), the host sends:

| Bit(s) | Name | Meaning |
|--------|------|---------|
| 1 | **Start** | Always `1` |
| 1 | **APnDP** | `0` = DP register, `1` = AP register |
| 1 | **RnW** | `0` = write, `1` = read |
| 2 | **A[2:3]** | Register address bits A[3:2] (LSB-first on the wire) |
| 1 | **Parity** | Even parity over APnDP, RnW, A[2], A[3] |
| 1 | **Stop** | Always `0` |
| 1 | **Park** | Host drives `1`, then releases the line |

All multi-bit fields are **LSB first**.

#### Turnaround (Trn)

When drive ownership changes, neither side should drive for a short period (default **1** SWCLK). That prevents bus fight on SWDIO.

#### ACK (target → host, 3 bits)

| Encoding (value) | Name | Wire order (LSB first) |
|------------------|------|-------------------------|
| `0b001` | **OK** | `1, 0, 0` |
| `0b010` | **WAIT** | `0, 1, 0` |
| `0b100` | **FAULT** | `0, 0, 1` |

The numeric value and the bit order on the wire are easy to confuse: OK is value `001`, so the **first** driven bit is `1`.

#### Data phase (only if ACK = OK in this implementation)

| Direction | When | Format |
|-----------|------|--------|
| **Write** | After OK + **second** turnaround | 32-bit WDATA + even parity (host → target) |
| **Read** | After OK, **no** turnaround (target keeps the line) | 32-bit RDATA + even parity (target → host) |

### Errors and special sequences

| Condition | Target behaviour |
|-----------|------------------|
| **Protocol error** (bad request parity / Stop / Park) | Do **not** drive ACK; stay silent until **line reset** |
| **WDATA parity fail** | ACK already sent; DP sets **WDATAERR** and drops the write (not a line silence) |
| **WAIT** | Busy (e.g. previous AP access outstanding); host typically retries |
| **FAULT** | Sticky error set; host clears via **ABORT** |
| **Line reset** | SWDIO HIGH for **≥ 50** SWCLK, then **≥ 2** idle (LOW) |
| **Idle** | SWDIO low between frames, or back-to-back Start with zero idle |

---

### Clock and pins

```text
Clock domain = SWCLK (probe-driven)

swdio.i  ← host/probe (or pad input)
swdio.o  → pad output value when target drives
swdio.oe → pad output enable
```

- Target samples `i` and updates `o`/`oe` on **rising** SWCLK (OpenOCD bitbang model).

### Minimal mental model (one frame)

1. Host clocks an 8-bit **header** (Start…Park).
2. Phy validates it; if bad → silence until line reset.
3. If good → phy fires **cmd** and needs **rsp.ack** for the next few clocks.
4. Phy drives **ACK** (value chosen by Phase 2B).
5. If OK and read → phy streams **rdata + parity** from the DP.
6. If OK and write → phy releases the line, samples **wdata + parity**, fires **wr**.
7. If WAIT/FAULT → phy stops after ACK (no data phase here).
8. Host may retry, clear sticky via ABORT  or line-reset.

---
