# Testing 

### Phase 4: Verification and Testing

---

#### Tasks

- [ ] Build simulation testbenches for SWD-DTM → `DebugBus` → DM → CPU path (bit-level SWD + DMI gateway)
- [ ] Send automated **SWD** stimuli via **custom** OpenOCD target (Phase 2D) on real CMSIS-DAP hardware
- [ ] Test `dmactive` activation/deactivation sequence
- [ ] Test abstract command error handling (all 7 `cmderr` codes)
- [ ] Test EBREAK behavior with `dcsr.ebreakm`/`ebreaks`/`ebreaku` combinations
- [ ] Test single-step across privilege mode transitions
- [ ] Test trigger module: each trigger type, chaining, `dmode` security
- [ ] Test System Bus Access error handling (if implemented)
- [ ] Test authentication mechanism (if implemented)
- [ ] Regression tests for all implemented features

---