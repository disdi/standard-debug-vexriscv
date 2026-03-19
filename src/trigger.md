# Trigger

**Dependency:** Phase 1D (dcsr exists for `cause=2` trigger reporting)
**Deliverable:** Hardware breakpoints and data watchpoints through standard trigger CSRs

---

**Tasks:**
- [ ] Implement `tselect` (0x7A0, Sec 5.7.1) — WARL trigger index selection (support N triggers, parameterized)
- [ ] Implement `tdata1` (0x7A1, Sec 5.7.2) — `type`, `dmode`, `data` with type multiplexing
- [ ] Implement `tdata2` (0x7A2, Sec 5.7.3) — compare value (address or data)
- [ ] Implement `tinfo` (0x7A4, Sec 5.7.5) — `version=1`, `info` (supported type bitmask)
- [ ] Implement `mcontrol6` (type 6, Sec 5.7.12) — start with: `execute=1`, `match=0` (equal), `action=1` (enter debug mode), `select=0` (address)
- [ ] Extend `mcontrol6` with `store=1`/`load=1` + `select=1` (data) for watchpoints
- [ ] Implement `dmode` bit security — only Debug Mode can write triggers with `dmode=1`
- [ ] Implement `dcsr.cause=2` (trigger) on trigger match
- [ ] Migrate existing `hardwareBreakpoints` PC-match logic to use trigger CSRs

---

**GDB/OpenOCD at this phase — everything from Phase 1E, plus:**
| GDB Command | Phase 1E | Phase 1F |
|---|---|---|
| `hbreak *0x80000100` | ❌ | ✅ Hardware breakpoint, no memory modification |
| `hbreak main` | ❌ | ✅ Works on ROM/flash code |
| `watch counter` | ❌ | ✅ Data watchpoint (fires on write to `&counter`) |
| `rwatch buffer` | ❌ | ✅ Read watchpoint (fires on read from `&buffer`) |
| `break` on flash/ROM | ❌  | ✅ Hardware BP doesn't modify memory |

---
