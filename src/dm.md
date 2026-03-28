# Debug Module

### Phase 1B: Core DM Registers


---
| Spec Feature (Chapter) | Vexriscv Debug Implementation | Implementation Details |
|---|---|---|
| **Ch 3: Debug Module (DM)** | | |
| `dmcontrol` (0x10) | ✅ Implemented | `dmactive`, `ndmreset`, `haltreq`, `resumereq`, `ackhavereset`, `hartsello/hi`. Missing: `hasel`, `setresethaltreq`, `hartreset`, `keepalive` |
| `dmstatus` (0x11) | ✅ Implemented | `version`, `authenticated=1`, all halted/running/unavail/nonexistent/resumeack/havereset flags, `impebreak=1` |
| `hartinfo` (0x12) | ✅ Implemented | `dataaddr=0`, `datasize=0`, `dataaccess=0`, `nscratch=0` |
| `abstractcs` (0x16) | ✅ Implemented | `datacount`, `progbufsize`, `busy`, `cmderr` (all 7 error codes) |
| `command` (0x17) — Access Register | ✅ Implemented | cmdtype=0 with full FSM: transfer, write, postexec, aarsize validation, GPR+FPU register access |
| `command` (0x17) — Access Memory | ❌ Not implemented | Returns NOT_SUPPORTED |
| `command` (0x17) — Quick Access | ❌ Not implemented | Returns NOT_SUPPORTED |
| `abstractauto` (0x18) | ✅ Implemented | `autoexecdata` and `autoexecProgbuf` for burst access |
| `progbuf0-N` (0x20+) | ✅ Implemented | Parameterized progbuf memory, multi-word execution with counter, redo support |
| `data0-N` (0x04+) | ✅ Implemented | Memory-backed, hart writes via `fromHarts`, host reads async |
| `sbcs` (0x38) — System Bus Access | ✅ Implemented (optional) | `sbversion=1`, `sbaccess`, `sbbusyerror`, `sbbusy`, `sbreadonaddr`, `sbautoincrement`, `sbreadondata`, `sberror`, 32-bit only |
| `sbaddress0` (0x39) | ✅ Implemented | Read/write with auto-increment |
| `sbdata0` (0x3c) | ✅ Implemented | Read/write with bus triggers |
| `sbaddress1-3` / `sbdata1-3` | ❌ Not implemented | 32-bit address/data only |
| `sbcs` 8/16/64/128-bit access | ❌ Not implemented | Only `sbaccess32` supported |
| `haltsum0` (0x40) | ✅ Implemented | Per-hart halted bits, up to 32 harts |
| `haltsum1-3` | ❌ Not implemented | Only `haltsum0` exists |
| `authdata` (0x30) | ❌ Not implemented | Always authenticated |
| `confstrptr0-3` | ❌ Not implemented | — |
| `nextdm` (0x1d) | ❌ Not implemented | — |
| `dmcs2` (0x32) | ❌ Not implemented | — |
| Hart arrays (`hawindowsel`/`hawindow`) | ❌ Not implemented | — |
| `custom0-15` | ❌ Not implemented | — |
| Multi-hart support | ✅ Implemented | Parameterized `p.harts`, per-hart buses, `hartSel` selection |
---
