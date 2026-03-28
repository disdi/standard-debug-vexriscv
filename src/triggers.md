# Triggers

### Phase 1D: Trigger Module


---

| Spec Feature (Chapter) | Vexriscv Debug Implementation | Implementation Details |
|---|---|---|
| **Ch 5: Trigger Module (hart-side CSRs)** | | |
| `tselect` (0x7A0) | ✅ Implemented | `CsrPlugin.scala` (lines 870-875): WARL index, parameterized `debugTriggers` (default 2) |
| `tinfo` (0x7A4) | ✅ Implemented | `CsrPlugin.scala` (line 878): reports type 2 (mcontrol) support |
| `tdata1` (0x7A1) | ⚠️ Partial | `CsrPlugin.scala` (lines 922-942): `type=2`, `dmode`, `execute`, `m/s/u`, `action`. Missing: `timing`, `select`, `sizelo/hi`, `maskmax`, `chain`, `match`, `load`, `store`, `hit` |
| `tdata2` (0x7A2) | ✅ Implemented | `CsrPlugin.scala` (lines 944-953): 32-bit compare value, PC equality match |
| `tdata3` (0x7A3) | ❌ Not implemented | — |
| `tcontrol` (0x7A5) | ❌ Not implemented | No `mte`/`mpte` |
| Trigger type | ⚠️ mcontrol (type 2) only | Legacy type 2, not type 6 (mcontrol6). Spec recommends type 6 for new implementations |
| Match modes | ⚠️ Equal only | Only `match=0` (equality). No napot, >=, <, mask modes |
| Match targets | ⚠️ Execute address only | Only `execute` bit implemented. No `load`/`store` data/address match |
| Privilege filtering | ✅ Implemented | `m`, `s`, `u` bits with `privilegeHit` logic (lines 930-934) |
| `dmode` security | ✅ Implemented | `dmode` bit controls debug-only write access (line 925) |
| `action` field | ⚠️ Partial | Register exists but only `action=1` (enter debug) used in match logic |
| Trigger chaining | ❌ Not implemented | No `chain` bit |
| `dcsr.cause=2` on trigger | ✅ Implemented | `CsrPlugin.scala` (line 892): sets `dcsr.cause := 2` on trigger hit |
| Trigger hit → debug entry | ✅ Implemented | `CsrPlugin.scala` (lines 881-897): `decodeBreak` halts pipeline, enters debug mode |
| `mcontrol6` (type 6) | ❌ Not implemented | Only legacy type 2 exists |
| `icount` (type 3) | ❌ Not implemented | — |
| `itrigger`/`etrigger`/`tmexttrigger` | ❌ Not implemented | — |
| Hardware breakpoints | ⚠️ Spec-compliant but limited | Type 2 mcontrol with execute address match=0 only, privilege filtering, dmode security |
| `mcontext`/`scontext` | ❌ Not implemented | — |
| **SoC Integration** | | |
| DTM→DM→Hart wiring | ✅ Implemented | `DebugModuleFiber.scala` — multi-hart binding, clock-domain-safe pipelining |
| Tilelink SBA bridge | ✅ Implemented | `makeSysbusTilelink()` in DebugModuleFiber |

---