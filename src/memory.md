# Memory

### Phase 1E: Memory Access (Program Buffer)
**Spec Reference:** Sec 3.5 (Program Buffer), Sec 3.14.15 (`progbuf0`), Sec 3.14.6 (`abstractcs.progbufsize`)
**Dependency:** Phase 1C (abstract command framework working)
**Deliverable:** Debugger can read/write target memory. **This is the "fully functional hello world debugger" milestone.**

**Approach:** Program Buffer is recommended for VexRiscv since the instruction injection port already exists and can be reused. OpenOCD's RISC-V driver knows how to synthesize memory read/write sequences using `lw`/`sw` instructions in the program buffer.

**Tasks:**
- [ ] Implement `progbuf0` (0x20) — minimum 1 word (2 is better: one for the access instruction, one for `ebreak`)
- [ ] Optionally implement `progbuf1` (0x21) — allows the access instruction + explicit `ebreak`
- [ ] Report `progbufsize` in `abstractcs`
- [ ] Implement Access Register command with `postexec=1` — execute program buffer after register transfer
- [ ] Implement `impebreak` in `dmstatus` — implicit ebreak after last progbuf word (saves a progbuf slot)
- [ ] Wire program buffer execution to existing instruction injection port
- [ ] Handle `cmderr=3` (exception) if progbuf instruction causes a fault

**How OpenOCD uses progbuf for memory access:**
```
Memory Read (e.g., read 32-bit word at address A):
  1. Write "lw s0, 0(s0)" into progbuf0
  2. Write address A into data0
  3. Execute: Access Register command (regno=s0, write=1, transfer=1, postexec=1)
     → DM writes A into s0, then executes progbuf → "lw s0, 0(s0)" loads mem[A] into s0
  4. Read: Access Register command (regno=s0, write=0, transfer=1)
     → DM reads s0 into data0
  5. Read data0 → contains mem[A]

Memory Write (e.g., write value V to address A):
  1. Write "sw s1, 0(s0)" into progbuf0
  2. Write address A to s0, value V to s1 (via abstract register write)
  3. Execute postexec → stores V to mem[A]
```

**GDB/OpenOCD at this phase:**
```
OpenOCD: Sees progbufsize >= 1 in abstractcs ✅
OpenOCD: Memory read/write via progbuf lw/sw sequences ✅
GDB: Full debugging capability for hello world
```
| GDB Command | Works? | Reason |
|---|---|---|
| `target remote :3333` | ✅ | Full connect |
| `load hello.elf` | ✅ | Memory write via progbuf |
| `break main` | ✅ Software BP | Writes `ebreak` (0x00100073) to memory at breakpoint address |
| `continue` | ✅ | Resume, halts when ebreak hit, `dcsr.cause=1` (ebreak) |
| `stepi` / `step` / `next` | ✅ | `dcsr.step` + memory read for source line mapping |
| `info registers` | ✅ | Abstract register access |
| `x/4x 0x80000000` | ✅ | Memory read via progbuf |
| `x/s &message` | ✅ | Reads "Hello, World!\n" from memory |
| `print variable` | ✅ | Register + memory read |
| `backtrace` | ✅ | Stack memory read (walks frame pointers) |
| `set *0x80001000 = 0x41` | ✅ | Memory write via progbuf |
| `hbreak` (hardware BP) | ❌ | Needs trigger module |
| `watch variable` | ❌ | Needs trigger module data watchpoints |

**Typical hello world debug session at this phase:**
```
$ riscv32-unknown-elf-gdb hello.elf
(gdb) target remote :3333
Remote debugging using :3333
0x80000080 in _start ()

(gdb) load
Loading section .text, size 0x1234 lma 0x80000000
Loading section .data, size 0x100 lma 0x80002000
Start address 0x80000000, load size 4916

(gdb) break main
Breakpoint 1 at 0x80000124: file hello.c, line 3.

(gdb) continue
Breakpoint 1, main () at hello.c:3
3    const char *message = "Hello, World!\n";

(gdb) next
4    uart_puts(message);

(gdb) print message
$1 = 0x80001000 "Hello, World!\n"

(gdb) info registers
ra  0x800000e4   sp  0x80010000   gp  0x80002800
a0  0x80001000   a1  0x00000000   ...

(gdb) backtrace
#0  main () at hello.c:4
#1  0x800000a0 in _start ()

(gdb) x/4i $pc
0x80000128: lui   a0,0x80001
0x8000012c: addi  a0,a0,0
0x80000130: jal   ra,0x80000200 <uart_puts>
0x80000134: j     0x80000134

(gdb) continue
Continuing.    ← "Hello, World!" appears on UART