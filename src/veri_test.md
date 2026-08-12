# Testing

### Phase 4: Verification and Testing

Host-visible **sim** paths that already pass are tracked under [Phase 3](./sys_int.md)
(raw-AP smoke, `riscv` examine, GDB attach/regs, demo break/continue). This chapter is
the broader regression matrix — much of it still open, especially on hardware.

---

#### Done in sim (via Phase 3)

- [x] SWD-DTM → `DebugBus` → DM path at sbt (Phases 2A–2C) and LiteX Verilator SoC
- [x] OpenOCD master smoke: DPIDR + `dap apreg` → `dmstatus`
- [x] OpenOCD `riscv` examine + halt/resume/register access over SWD (patched builds)
- [x] GDB attach / registers / memory R/W over SWD
- [x] GDB `break main` / `continue` / backtrace on preloaded demo (no GDB `load`)

#### Still open

- [ ] Automated **SWD** stimuli via custom OpenOCD target on real **CMSIS-DAP** hardware (Arty)
- [ ] Test `dmactive` activation/deactivation sequence (formal matrix)
- [ ] Test abstract command error handling (all 7 `cmderr` codes)
- [ ] Test EBREAK behavior with `dcsr.ebreakm` / `ebreaks` / `ebreaku` combinations
- [ ] Test single-step across privilege mode transitions
- [ ] Test trigger module: each trigger type, chaining, `dmode` security
- [ ] Test System Bus Access error handling (if implemented)
- [ ] Test authentication mechanism (if implemented)
- [ ] Decide `dmstatus.version` claim (`2` = 0.13 vs `3` = 1.0)
- [ ] Regression suite for all implemented features (CI-friendly)

---
