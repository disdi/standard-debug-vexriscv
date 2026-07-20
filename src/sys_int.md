# Integration 

### System Integration


---

#### Spec Feature Coverage Summary

**SWD Specific Tasks:**
- [ ] Add `withSwdTransport()` to `DebugModuleFiber` (mutually exclusive with `withJtagTap()` per build)
- [ ] Provide SWD pinout constraints for FPGA synthesis (weak pull-up on `swdio` per ADI; IOBUF at SoC level)
- [ ] **Do not** connect JTAG-DTM and SWD-DTM to `DebugBus` concurrently unless explicit arbitration is added
- [ ] Add **custom** OpenOCD target

---