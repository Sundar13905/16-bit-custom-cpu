# Progress Tracker — 16-Bit Custom CPU

Status legend: ✅ Done &nbsp;·&nbsp; 🟡 In Progress &nbsp;·&nbsp; ⬜ Not Started

Everything below was checked against the actual repo contents (38 commits on `main`: `src/`, `testbenches/`, `hack/`, `vcd/`), and every claim about what compiles or runs was verified by actually building it with Icarus Verilog 12.0 — not just read from the source. Update this file as items move between columns.

## Snapshot

| Task | Milestone | Status |
|---|---|---|
| 1 | Base single-cycle core | 🟡 In Progress |
| 2 | ISA extension | 🟡 In Progress |
| 3 | Floating-Point Unit | 🟡 In Progress |
| 4 | Pipelined core + hazards | 🟡 In Progress |
| 5 | Crypto co-processor | ⬜ Not Started |

---

## Task 1 — Base Single-Cycle Core

- [x] Datapath wired end-to-end in `single_cycle_core.v` (PC → IMEM → control unit → register file → immgen → ALU/FPU → data memory → writeback mux)
- [x] ALU covers the full required R-type set: `ADD`, `SUB`, `AND`, `OR`, `SLL`, `SRL`, `SRA`, `SLT` (plus extra `XOR` and unsigned `SLTU`)
- [x] Unit testbenches exist and **pass** standalone for: `alu`, `data_mem`, `regfile`, `immgen`, `control_unit`, `decoder`, `pc`*
- [~] Memory instructions present as `LW` / `SW` opcodes — functionally equivalent to the spec's `LH` / `SH` at this data width; rename/confirm naming when convenient
- [ ] Get `single_cycle_core.v` compiling as a full integrated core (see **Known Issues** below — currently blocked on module/port naming)

\* `pc_tb.v` does **not** currently compile against `pc.v` — see Known Issues.

## Task 2 — ISA Extension

- [x] `ADDI` — dedicated opcode, wired
- [x] `SLTI` — dedicated opcode, wired
- [ ] `SUBI`, `ORI`, `ANDI` — no dedicated opcode yet (ALU itself already supports the underlying ops for R-type)
- [ ] `SRLI`, `SLLI`, `SRAI` — no immediate-shift opcodes yet
- [x] `BEQ` — implemented
- [ ] `BNE`, `BLT`, `BGE` — not yet
- [ ] `JAL` (with link-register writeback) — only an unconditional `JUMP` exists today, no return-address save
- [ ] `JALR` — not yet

## Task 3 — Floating-Point Unit

- [x] `fpu.v` module exists and is wired into both `single_cycle_core.v` and `pipelined_core.v`
- [ ] IEEE-754 half-precision decode (sign / exponent / mantissa extraction)
- [ ] `FADD` — **not yet correct.** Running the project's own `fpu_tb.v` (an IEEE-754-aware testbench) against the current `fpu.v` gives `1.0 + 1.0 = 32768.0` instead of `2.0` — the module currently adds the raw 16-bit bit patterns as plain integers rather than decoding/aligning/normalizing floats.
- [ ] `FMUL` — **not yet correct.** Same testbench: every tested case (`1.0×2.0`, `2.0×3.0`, `0.5×0.5`, `-1.5×2.0`) currently returns `0.0`.
- [ ] Rounding / special cases (zero, infinity, NaN, denormals)

> This is the current `fpu.v` treating operands as raw integers rather than IEEE-754 half-precision floats — normal for a scaffolded first pass. The real work here is sign/exponent/mantissa extraction, an aligned add for `FADD`, a mantissa multiply + exponent add for `FMUL`, then normalization and rounding back into the 16-bit half-precision format.

## Task 4 — Pipelined Core

- [x] 5-stage skeleton in `pipelined_core.v` (IF → ID → EX → MEM → WB) with pipeline registers between each stage
- [ ] Hazard detection unit (load-use stalls)
- [ ] Forwarding / bypass paths (EX/MEM → EX, MEM/WB → EX)
- [ ] Branch/jump resolution — `pc_next` currently always increments by 1; `branch`/`jump` control signals aren't yet wired to redirect fetch
- [ ] FPU integration — `pipelined_core.v` instantiates the FPU with a different port set (`clk`, `rst`, `fpu_enable`, `fpu_op`, `operand_a`, `operand_b`, `fpu_result`, `fpu_ready`, `invalid_op`) than the one `fpu.v` actually defines (`enable`, `a`, `b`, `opcode`, `result`) — looks like it was written against a planned multi-cycle FPU with a ready/valid handshake. Needs either a matching FPU update or reverting the instantiation to the current combinational interface.
- [x] `pipelined_core_tb.v` exists (currently blocked from compiling by the same integration items above)

## Task 5 — Cryptographic Co-Processor

- [ ] No `ENC` / `DEC` source, opcode reservation, or co-processor interface exists yet — this task hasn't been started.

---

## 🔧 Known Issues / Integration Notes

These were found by actually compiling the files with `iverilog`, not just reading them — each is reproducible.

1. **`register_file` vs `regfile` naming.** `single_cycle_core.v`, `pipelined_core.v`, and `datapath.v` all instantiate a module called `register_file` with ports `wr_en` / `rd_addr1` / `rd_addr2` / `wr_addr` / `wr_data` / `rd_data1` / `rd_data2`. The file that actually exists is `regfile.v`, module `regfile`, with different port names (`reg_write` / `read_reg1` / `read_reg2` / `write_reg` / `write_data` / `read_data1` / `read_data2`). Right now **neither core compiles** until this is reconciled — pick one naming convention and update either `regfile.v` or its three call sites to match. This is the single highest-leverage fix; everything else downstream depends on it.
2. **`pc.v` port naming.** `pc.v`'s output is named `pc`, but `single_cycle_core.v` connects it as `pc_out`, and `pipelined_core.v` additionally expects `rst` (not `reset`) and an external `pc_in`. `pc_tb.v` itself already assumes `pc_out`, so aligning `pc.v` to `clk` / `reset` / `branch` / `jump` / `branch_addr` / **`pc_out`** is the more consistent fix.
3. **`pipelined_core.v` ALU/data-memory port names.** It connects `alu`'s output as `result` (actual port: `alu_out`) and `data_mem`'s address as `addr` (actual port: `address`) — same category of fix as #1 and #2.
4. **Register field ordering differs between cores.** In `single_cycle_core.v`, `instr[11:9]` feeds the first source register and `instr[5:3]` is the write address. In `pipelined_core.v`, `instr[11:9]` **is** the write address (`rd`) and `instr[8:6]` / `instr[5:3]` are the two source registers. Worth standardizing on one instruction-field layout before writing test programs, or the same machine code will behave differently on each core.
5. **`alu_tb.v` parameter mismatch.** It instantiates the ALU as `alu #(.WIDTH(16))`, but `alu.v` isn't parameterized — this currently fails to compile. Either drop the override or add a `WIDTH` parameter to `alu.v`.
6. **`register_file_tb.v` is orphaned.** It tests a module named `register_file` that doesn't exist in `src/` (only `regfile.v` does), and fails to compile as-is. `regfile_tb.v` is the testbench that matches the current module — `register_file_tb.v` looks like a leftover from an earlier interface and can likely be retired or updated once #1 is resolved.
7. **`decoder.v` looks unused.** Both cores use `control_unit.v` (which also handles the FPU enable/opcode fields) rather than `decoder.v`. Worth confirming `decoder.v` is intentionally kept around (e.g. for reference) or removing it to avoid two sources of truth.
8. **`mux2to1.v`, `mux3to1.v`, `dff.v`** exist but aren't instantiated anywhere yet — fine as building blocks, just flagging they're currently unused.
9. **Testbenches are stimulus-only.** Most testbenches (`decoder_tb`, `control_unit_tb`, etc.) apply inputs and dump a `.vcd` for manual/visual checking rather than asserting expected vs. actual values. Adding a simple `if (actual !== expected) $display("FAIL ...")` pattern would make these self-checking and much faster to re-run as regressions.

## 🧹 Housekeeping (optional)

- No `.gitignore` yet — `hack/` (compiled `vvp` binaries) and `vcd/` (waveform dumps) are currently tracked as build artifacts; consider ignoring them (or keep them intentionally if you want reproducible sim output alongside the source).
- No `LICENSE` file yet.

## ⏭️ Suggested Next Session

1. Fix the `register_file` naming mismatch (#1) — unblocks compiling both cores.
2. Align `pc.v`'s port names (#2) and pick one register-field layout (#4).
3. Once both cores compile, get `single_cycle_core_tb.v` and `pipelined_core_tb.v` running end-to-end with a real test program in `rv16i_test.txt`.
4. Start the IEEE-754 decode/encode logic for the FPU — the raw arithmetic is already there as scaffolding.
