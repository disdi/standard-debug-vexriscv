# CSR Register

### Phase 1D: Debug CSRs (dcsr, dpc)

**Dependency:** Phase 1C (can read/write CSRs via abstract commands)
**Deliverable:** Proper halt cause reporting, single-step via `dcsr.step`, PC via `dpc`

**Tasks:**
- [ ] Implement `dcsr` (0x7B0) as actual hart CSR — `xdebugver=4`, `cause` (5 values), `step`, `ebreakm`/`ebreaks`/`ebreaku`, `prv`, `stepie`, `stopcount`, `stoptime`, `mprven`, `nmip`
- [ ] Implement `dpc` (0x7B1) as actual hart CSR — captures PC on debug entry
- [ ] Implement `dscratch0` (0x7B2) — debug scratch register for debugger use
- [ ] Implement debug mode entry: set `dcsr.cause`, save PC to `dpc`, save privilege to `dcsr.prv`
- [ ] Implement debug mode exit via `dret` instruction — restore PC from `dpc`, privilege from `dcsr.prv`
- [ ] Implement `dcsr.step` — single-step (migrate existing `stepIt` logic to use this CSR)
- [ ] Implement `dcsr.ebreakm`/`ebreaks`/`ebreaku` — per-privilege ebreak behavior (replace `disableEbreak`)
- [ ] Migrate `godmode` behavior to proper debug mode privilege rules (Sec 4.1)

**GDB/OpenOCD at this phase:**
```
OpenOCD: Reads dcsr ✅ xdebugver=4, cause=3 (haltreq)
OpenOCD: Reads dpc ✅ exact halt PC
OpenOCD: "Examined RISC-V core; found 1 hart, rv32i" ✅ CLEAN CONNECT
GDB: Full register display with proper PC, single-step works
```
| GDB Command | Works? | Reason |
|---|---|---|
| `target remote :3333` | ✅ Clean connect | Full DM + dcsr/dpc |
| `continue` / `Ctrl+C` | ✅ | halt/resume |
| `info registers` | ✅ | Abstract register access + dcsr/dpc |
| `stepi` | ✅ | `dcsr.step=1`, resumereq, poll halted, `dcsr.cause=4` |
| `set $pc = addr` | ✅ | Write `dpc` via abstract command |
| `next` / `step` (source-level) | ❌ | Needs memory read for source line mapping |
| `break` / `load` / `x/...` / `bt` | ❌ | Needs memory access |

**Practical use:** Halt hello world, see exactly where it stopped (PC with source line if ELF has debug info), read all registers, and single-step instruction by instruction. Watch the program counter advance through the code. 
Cannot see memory, set breakpoints, or do source-level stepping.
