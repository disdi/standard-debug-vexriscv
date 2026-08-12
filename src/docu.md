# Documentation

### Phase 5: Documentation & Developer Interface

---

#### Done

- [x] Phase 2A–2C architecture chapters in this book (`SwdPhy` / `SwdDp` / `SwdDmiGateway`)
- [x] Operator how-to for **sim** three-terminal attach (JTAG and SWD) — [Phase 3](./sys_int.md)
- [x] Document placeholder `DPIDR`, `AP_IDR`, and Phase 2C `DMI_ADDR` / `DMI_DATA` / `POSTED_READ` map (see [Phase 2C](./Phase2C.md))

#### Still open

- [ ] Broader user-facing guide beyond sim (FPGA CMSIS-DAP, probe-rs, multi-probe notes)
- [ ] Finalize published identification constants once IDs leave placeholder status
- [ ] Document which optional RISC-V debug-spec features are implemented vs stubbed
  (`dmstatus.version`, abstract commands surface, triggers, SBA)
- [x] Published OpenOCD Vexriscv fork: [disdi/openocd `vexriscv-gateway`](https://github.com/disdi/openocd/tree/vexriscv-gateway) (9786 + fixes + gateway; still unmerged upstream)

---
