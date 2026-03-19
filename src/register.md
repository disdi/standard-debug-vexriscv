# Register

### Phase 1C: Abstract Register Access

**Dependency:** Phase 1B (DM registers, halt/resume working)
**Deliverable:** Can read/write GPRs and CSRs through abstract commands

---

**Tasks:**
- [ ] Implement `abstractcs` (0x16) — `datacount` (min 1 for RV32), `progbufsize`, `busy`, `cmderr`
- [ ] Implement `data0` (0x04) — at minimum 1 data register (`datacount>=1` for RV32, `>=2` for RV64)
- [ ] Implement `command` (0x17) — Access Register command (cmdtype=0)
- [ ] Implement abstract command state machine: `idle` → `busy` → `complete/error`
- [ ] Implement `cmderr` error codes: `busy(1)`, `not supported(2)`, `exception(3)`, `halt/resume(4)`
- [ ] Implement register number decoding: GPRs (0x1000-0x101f), CSRs (0x0000-0x0fff)
- [ ] Wire abstract register access to hart — either via instruction injection (reuse existing injection port) or direct register file access

---

**GDB/OpenOCD at this phase:**
```
OpenOCD: Reads abstractcs, gets datacount=1 ✅
OpenOCD: Abstract command reads x1-x31 ✅
OpenOCD: Abstract command reads mstatus, misa ✅
OpenOCD: Abstract command reads dcsr → CSR doesn't exist yet, cmderr=2 ⚠️
OpenOCD: Identifies hart as rv32i ✅
GDB: Connects, reads registers, but dcsr/dpc warnings
```
| GDB Command | Works? | Reason |
|---|---|---|
| `target remote :3333` | ⚠️ Connects, dcsr/dpc warnings | dcsr CSR not yet on hart |
| `continue` / `Ctrl+C` | ✅ | halt/resume |
| `info registers` | ✅ | Abstract register access reads x0-x31 + CSRs |
| `set $a0 = 42` | ✅ | Abstract register write |
| `stepi` / `next` / `step` | ❌ | Needs `dcsr.step` |
| `break` / `load` / `x/...` | ❌ | Needs memory access |
| `backtrace` | ❌ | Needs stack memory read |

**Practical use:** Halt the running hello world and inspect all CPU registers. See what function it's in (from PC), stack pointer value, arguments in a0-a7. Can modify registers. 
Cannot see memory, set breakpoints, or single-step.

---
