# Debug Module

### Phase 1B: Core DM Registers (Minimal Control Plane)

**Dependency:** Phase 1A (DMI bus exists)
**Deliverable:** Can halt/resume a hart through standard `dmcontrol`/`dmstatus`

---

**Tasks:**
- [ ] Create `DebugModule.scala` — DMI address decoder, register file
- [ ] Implement `dmcontrol` (0x10) — `dmactive`, `haltreq`, `resumereq`, `ndmreset`, `hartsello` (single hart = hart 0)
- [ ] Implement `dmstatus` (0x11) — `version=3` (1.0), `authenticated=1` (no auth), `anyhalted`/`allhalted`/`anyrunning`/`allrunning`
- [ ] Implement `dmactive` state machine — activation/deactivation with reset behavior
- [ ] Wire DM hart interface to VexRiscv pipeline (reuse existing `haltIt`/`resetIt` signals)
- [ ] Implement mutual exclusion on `dmcontrol` writes (only one of `resumereq`/`hartreset`/`ackhavereset`/`setresethaltreq`/`clrresethaltreq` may be 1)

---

**GDB/OpenOCD at this phase:**
```
OpenOCD: Connects, reads dmstatus.version=3 ✅
OpenOCD: Writes haltreq=1, hart halts ✅
OpenOCD: Polls dmstatus.allhalted=1 ✅
OpenOCD: Reads abstractcs → not implemented, gets 0 ❌
OpenOCD: Tries abstract register read of dcsr → fails ❌
OpenOCD: "Error: failed to read dcsr"
GDB: Connects with warnings, can't read registers
```
| GDB Command | Works? | Reason |
|---|---|---|
| `target remote :3333` | ⚠️ Connects with warnings | OpenOCD finds DM but can't read registers |
| `continue` | ✅ | `dmcontrol.resumereq` |
| `Ctrl+C` (halt) | ✅ | `dmcontrol.haltreq` |
| `monitor reset halt` | ✅ | `dmcontrol.ndmreset` + `haltreq` |
| `info registers` | ❌ | Needs abstract register access |
| `stepi` | ❌ | Needs `dcsr.step` |
| `break` / `load` / `x/...` | ❌ | Needs memory access |

**Practical use:** CPU can be halted and resumed. CPU can be also reset it. Verify the hello world program is running (UART output appears when resumed, stops when halted). 
Cannot inspect or modify anything.

---

