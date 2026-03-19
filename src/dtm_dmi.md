# Debug Transport Module 

### Phase 1A: DMI Bus + JTAG DTM (Foundation Layer)

**Dependency:** None — this is the transport, can be tested standalone
**Deliverable:** Standard JTAG TAP that can read/write DMI addresses

---


**Tasks:**
- [ ] Implement JTAG TAP state machine with standard IR codes (BYPASS 0x1f, IDCODE 0x01, dtmcs, dmi)
- [ ] Implement `IDCODE` register with manufacturer/part/version fields
- [ ] Implement `dtmcs` register — `version=1`, `abits`, `idle`, `dmistat`, `dmireset`, `dmihardreset`
- [ ] Implement `dmi` shift register — `op` (2-bit), `address` (abits-wide), `data` (32-bit)
- [ ] Implement DMI request/response handshake with busy detection (`dmistat=3`)
- [ ] Create DMI bus interface (SpinalHDL Bundle) — internal bus between DTM and DM
- [ ] Implement `dmihardreset` and `dmireset` for error recovery

**GDB/OpenOCD at this phase:**
```
OpenOCD: JTAG scan detects IDCODE ✅
OpenOCD: Reads dtmcs, gets abits/version ✅
OpenOCD: Writes dmcontrol.dmactive=1 via DMI... but no DM exists ❌
OpenOCD: "Error: no debug module found" ❌
GDB: Cannot connect
```
| GDB Command | Works? | Reason |
|---|---|---|
| JTAG chain detection | ✅ | IDCODE readable |
| `target remote :3333` | ❌ | No DM to respond to DMI reads |
| Everything else | ❌ | — |

---

**Practical use:** Validates JTAG connectivity and DMI bus. OpenOCD can scan the chain and see the IDCODE. Raw DMI read/write can be tested via OpenOCD scripts.

---
