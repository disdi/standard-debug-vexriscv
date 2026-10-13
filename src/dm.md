# Debug Module

### Phase 1B: Core DM Registers

Status of SpinalHDL `DebugModule` on upstream `dev` `8ae0019178ba` ([SpinalHDL#1977](https://github.com/SpinalHDL/SpinalHDL/pull/1977), merged 2026-10-13), checked on hardware (Arty A7, VexRiscv and VexiiRiscv, over SWD) against the ratified RISC-V Debug Specification 1.0. The System Bus Access rows are that merge; the other rows were checked on its parent `58837d37` and #1977 does not change them.

---
| Spec Feature (Chapter) | Vexriscv Debug Implementation | Implementation Details |
|---|---|---|
| **Ch 3: Debug Module (DM)** |  |  |
| `dmcontrol` (0x10) | ✅ Implemented | `dmactive`, `ndmreset`, `haltreq`, `resumereq`, `ackhavereset`, `hartsello/hi`. Missing (optional): `hasel`, `setresethaltreq`/`clrresethaltreq`, `hartreset`, `keepalive`. `ackhavereset` acked the previously selected hart: fixed in [SpinalHDL#1972](https://github.com/SpinalHDL/SpinalHDL/pull/1972) (merged) |
| `dmstatus` (0x11) | ✅ Implemented | `version=2` (0.13), `authenticated=1`, all halted/running/unavail/nonexistent/resumeack/havereset flags, `impebreak=1`. A nonexistent hart read as halted, running and unavailable at once: fixed in [SpinalHDL#1972](https://github.com/SpinalHDL/SpinalHDL/pull/1972) (merged) |
| `hartinfo` (0x12) | ✅ Implemented | `dataaddr=0`, `datasize=0`, `dataaccess=0`, `nscratch=0` |
| `abstractcs` (0x16) | ✅ Implemented | `datacount`, `progbufsize`, `busy`, `cmderr`. Only codes 0–4 are raised; the unused `OTHER` code would encode as 6 instead of 7 (latent) |
| `command` (0x17) — Access Register | ⚠️ Implemented, open issues | cmdtype=0 with full FSM: transfer, write, postexec, aarsize validation. GPRs; FPRs only with a 64-bit FPU on VexRiscv, never on VexiiRiscv. CSRs and `aarpostincrement` return NOT_SUPPORTED (allowed). A command to a nonexistent hart hung `busy`: fixed in [SpinalHDL#1972](https://github.com/SpinalHDL/SpinalHDL/pull/1972) (merged). Open: FPR access on a hart without an FPU returns cmderr 2 instead of 3; a `command` write while `busy` or `cmderr≠0` replaces the stored command |
| `command` (0x17) — Access Memory | ❌ Not implemented | Returns NOT_SUPPORTED (optional) |
| `command` (0x17) — Quick Access | ❌ Not implemented | Returns NOT_SUPPORTED (optional) |
| `abstractauto` (0x18) | ⚠️ Implemented, open issue | `autoexecdata` and `autoexecProgbuf` for burst access. Open: a write while `busy` takes effect |
| `progbuf0-N` (0x20+) | ⚠️ Implemented, open issue | Parameterized progbuf memory (2 words), multi-word execution with counter, redo support, exception → `cmderr=3`. Reads return 0 (allowed in 1.0). Open: a write while `busy` takes effect |
| `data0-N` (0x04+) | ✅ Implemented | Memory-backed, hart writes via `fromHarts`, host reads async. 1 word on RV32, 2 on RV64 |
| `sbcs` (0x38) — System Bus Access | ✅ Implemented (optional, VexiiRiscv `--debug-sysbus` only) | `sbversion=1`, `sbasize=32`, `sbaccess32` only, `sbbusyerror`, `sbbusy`, `sbreadonaddr`, `sbautoincrement`, `sbreadondata`, `sberror`. Not present on VexRiscv. Bus errors and unaligned addresses were not reported in `sberror`: fixed in [SpinalHDL#1977](https://github.com/SpinalHDL/SpinalHDL/pull/1977) (merged) |
| `sbaddress0` (0x39) | ✅ Implemented | Read/write with auto-increment. It did not increment after writes or after the `sbreadonaddr` read, and writes were dropped while `sberror≠0`: fixed in [SpinalHDL#1977](https://github.com/SpinalHDL/SpinalHDL/pull/1977) (merged) |
| `sbdata0` (0x3c) | ✅ Implemented | Read/write with bus triggers. Block writes with `sbautoincrement` all landed on the first address, `sbdata0` was overwritten by the write acknowledge, and a read while busy did not set `sbbusyerror`: fixed in [SpinalHDL#1977](https://github.com/SpinalHDL/SpinalHDL/pull/1977) (merged) |
| `sbaddress1-3` / `sbdata1-3` | ❌ Not implemented | 32-bit address/data only |
| `sbcs` 8/16/64/128-bit access | ❌ Not implemented | Only `sbaccess32` supported; other sizes set `sberror=4` |
| `haltsum0` (0x40) | ✅ Implemented | Per-hart halted bits, up to 32 harts |
| `haltsum1-3` | ❌ Not implemented | Only `haltsum0` exists |
| `authdata` (0x30) | ❌ Not implemented | Always authenticated |
| `confstrptr0-3` | ❌ Not implemented | — |
| `nextdm` (0x1d) | ❌ Not implemented | — |
| `dmcs2` (0x32) | ❌ Not implemented | — |
| Hart arrays (`hawindowsel`/`hawindow`) | ❌ Not implemented | — |
| `custom0-15` | ❌ Not implemented | — |
| Multi-hart support | ⚠️ Implemented, open issue | Parameterized `p.harts`, per-hart buses, `hartSel` selection; independent halt/resume and abstract commands per hart (2-hart VexiiRiscv). Hart-selection bugs fixed in [SpinalHDL#1972](https://github.com/SpinalHDL/SpinalHDL/pull/1972) (merged). Open: an abstract register read occasionally returns the other hart's value right after a reset |
---
