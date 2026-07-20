# Debug Transport Module 

### Phase 3: System Integration


---

#### Spec Feature Coverage Summary

| Spec Feature (Chapter) | Vexriscv Debug Implementation | Implementation Details |
|---|---|---|
| **Ch 6: Debug Transport Module (DTM)** | | |
| JTAG TAP with IDCODE/dtmcs/dmi | ✅ Implemented | `DebugTransportModuleJtag.scala` — standard IR codes, dtmcs with version/abits/idle/dmistat, dmi with op/address/data |
| DMI bus protocol | ✅ Implemented | `DebugInterfaces.scala` — `DebugBus` with `DebugCmd`/`DebugRsp`, `DebugBusSlaveFactory` |
| DMI busy/error handling | ✅ Implemented | `dmihardreset`, `dmireset`, pending/overrun detection |
| Cross-clock-domain DMI | ✅ Implemented | `ccToggle` for JTAG↔debug clock domains |
| JTAG tunnel support | ✅ Implemented | `JtagTunnel.scala` — tunneling through outer TAP |


---