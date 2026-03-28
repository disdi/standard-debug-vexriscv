# CSR Register

### Phase 1C: Debug CSRs (dcsr, dpc)


---

| Spec Feature (Chapter) | Vexriscv Debug Implementation | Implementation Details |
|---|---|---|
| **Ch 4: Core Debug (hart-side CSRs)** | | |
| Halt/Resume | ✅ `DebugHartBus` + `CsrPlugin` | `CsrPlugin.scala` (line 702+): `running` flag, `DebugHartBus` wiring, halt/resume handshake |
| Single-step | ✅ Implemented | `CsrPlugin.scala` (lines 807-845): `dcsr.step` with full FSM (IDLE→SINGLE→WAIT), timeout/redo handling |
| `dcsr` (0x7B0) | ✅ Implemented | `CsrPlugin.scala` (lines 792-851): `prv`, `step`, `nmip`, `mprven`, `cause`, `stoptime`, `stopcount`, `stepie`, `ebreakm/s/u`, `xdebugver=4` |
| `dpc` (0x7B1) | ✅ Implemented | `CsrPlugin.scala` (line 791): `Reg(UInt(32 bits))`, read/write via `rw(CSR.DPC, dpc)` |
| `dscratch0` (0x7B2) | ❌ Not implemented | — |
| `dscratch1` (0x7B3) | ❌ Not implemented | — |
| Debug mode entry | ✅ Implemented | `CsrPlugin.scala` (lines 1426-1443): saves PC→`dpc`, sets `dcsr.cause` (1=ebreak, 3=haltreq, 4=step), saves privilege→`dcsr.prv`, enters M-mode |
| Debug mode exit (resume) | ✅ Implemented | `CsrPlugin.scala` (lines 1488-1498): jumps to `dpc`, restores privilege from `dcsr.prv`, via `DebugHartBus.resume` |
| Halt cause reporting | ✅ Implemented | `dcsr.cause`: 1 (ebreak), 2 (trigger), 3 (haltreq), 4 (step) |
| `dcsr.ebreakm/s/u` | ✅ Implemented | `CsrPlugin.scala` (lines 1372-1377): per-privilege ebreak→debug detection |
| `dcsr.stoptime` | ✅ Implemented | `CsrPlugin.scala` (line 866): `stoptime` output gated by `debugMode` |
| `dcsr.stopcount` | ✅ Implemented | `CsrPlugin.scala` (line 1176): `mcycle` increment gated by `!debugMode \|\| !stopcount` |
| `dcsr.stepie` | ✅ Implemented | `CsrPlugin.scala` (line 1315): interrupts cleared when `step && !stepie` |
| Interrupt inhibition in debug | ✅ Implemented | `CsrPlugin.scala` (line 721): `inhibateInterrupts()` when `debugMode` |
| CSR access protection (0x7Bx) | ✅ Implemented | `CsrPlugin.scala` (line 1718): blocks non-debug access to 0x7B0-0x7BF |
| `DebugHartBus` wiring | ✅ Implemented | `CsrPlugin.scala` (lines 704-789): instruction injection, data CSR, all hartToDm/dmToHart signals |
| Reset control | ✅ `dmcontrol.ndmreset` → `io.ndmreset` | Both implementations provide ndmreset |

---