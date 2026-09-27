<div align="center">

# 🧠 16-Bit Custom CPU

### A custom 16-bit RISC-V-style processor, built up from a single-cycle core to a fully verified 5-stage pipeline with an integrated IEEE-754 FPU.

![Language](https://img.shields.io/badge/HDL-Verilog-blue?style=flat-square)
![Simulator](https://img.shields.io/badge/Simulator-Icarus%20Verilog-orange?style=flat-square)
![Pipeline](https://img.shields.io/badge/Pipeline-5--Stage-brightgreen?style=flat-square)
![FPU](https://img.shields.io/badge/FPU-IEEE--754%20Half--Precision-yellow?style=flat-square)
![Main Testbench](https://img.shields.io/badge/Main%20Testbench-61%2F61%20Passing-success?style=flat-square)

</div>

---

> **TL;DR** — The 5-stage pipelined core (`pipelined_core.v`) is complete: forwarding, load-use hazard detection, branch/jump flushing, and a pipelined FPU are all implemented and pass the main regression testbench, **61/61 checks green**. Next up: the **UVM verification environment** and the **cryptographic co-processor**.

## 📑 Table of Contents

- [Overview](#-overview)
- [Project Status](#-project-status)
- [Repository Structure](#-repository-structure)
- [Instruction Set Architecture](#-instruction-set-architecture)
- [Floating-Point Unit](#-floating-point-unit)
- [Single-Cycle Processor](#-single-cycle-processor)
- [Pipelined Processor](#-pipelined-processor)
- [Hazard Handling](#-hazard-handling)
- [Verification](#-verification)
- [Building and Simulation](#️-building-and-simulation)
- [Development Roadmap](#️-development-roadmap)
- [Design Goals](#-design-goals)
- [Tools](#-tools)
- [License](#-license)

---

## 🔎 Overview

This project implements a custom 16-bit instruction set architecture with:

- 🧩 16-bit instructions and datapath
- 📦 8 general-purpose registers
- 🗂️ Separate instruction and data memories
- 🏗️ RISC-V-style instruction organization
- ✅ A functionally verified single-cycle processor
- ✅ A functionally verified 5-stage pipelined processor
- 🔢 IEEE-754 half-precision FPU (`FADD`, `FMUL`) integrated into both cores
- ➡️ Data forwarding (`EX/MEM → EX`, `MEM/WB → EX`) for ALU and FPU results
- ⏸️ Load-use hazard detection with pipeline stalling
- 🔀 Branch/jump resolution in EX, with IF/ID and ID/EX flushing
- 🧪 A UVM verification environment in progress
- 🔐 A cryptographic co-processor on the roadmap

The processor is developed incrementally, with each stage validated through Verilog simulation using Icarus Verilog.

---

## 📊 Project Status

> The **pipelined core testbench** (`testbenches/top_testbench/pipelined_core_tb.v`) is the main testbench in this repository — fully self-checking, and the one to run to validate the design.

#### Core Architecture

| Component | Status |
| :-- | :-- |
| Base single-cycle CPU | ✅ Functional |
| R-type ALU instructions | ✅ Functional |
| Immediate instructions | ✅ Implemented |
| Load / Store | ✅ Functional |
| Branch instructions | ✅ Implemented and exercised |
| JAL / JALR | ✅ Implemented and exercised |
| IEEE-754 half-precision FPU | ✅ Functional |
| ↳ FADD | ✅ Verified |
| ↳ FMUL | ✅ Verified |
| FPU ↔ CPU integration (single-cycle) | ✅ Verified |

#### 5-Stage Pipeline

| Component | Status |
| :-- | :-- |
| Pipeline datapath | ✅ Implemented |
| Pipeline registers `IF/ID` `ID/EX` `EX/MEM` `MEM/WB` | ✅ Implemented |
| Hazard detection (load-use) | ✅ Implemented and verified |
| Forwarding unit (ALU / FPU) | ✅ Implemented and verified |
| Branch / jump handling | ✅ Implemented and verified |
| Pipelined FPU integration | ✅ Implemented and verified |

#### Verification

| Component | Status |
| :-- | :-- |
| 🟢 **Main testbench — `pipelined_core_tb.v`** | ✅ **Properly functional** — 22 tests / 61 checks, all passing |
| `single_cycle_core_tb.v` | ✅ Functional integration testbench for the single-cycle core |

#### On the Roadmap

| Component | Status |
| :-- | :-- |
| UVM verification environment | 🟡 In progress |
| Cryptographic co-processor | ⬜ Planned |

---

## 🗂️ Repository Structure

```text
16-bit-custom-cpu/
│
├── src/
│   ├── single_cycle_core.v      ✅ Verified single-cycle top-level core
│   ├── top_module/
│   │   └── pipelined_core.v     ✅ Verified 5-stage pipelined top-level core
│   │
│   ├── alu.v
│   ├── fpu.v
│   ├── control_unit.v           # Control unit used by both cores
│   ├── regfile.v
│   ├── pc.v
│   ├── immgen.v
│   ├── instr_mem.v
│   ├── data_mem.v
│   ├── mux2to1.v
│   ├── mux3to1.v
│   │
│   ├── if_id_reg.v              # IF/ID pipeline register
│   ├── id_ex_reg.v              # ID/EX pipeline register
│   ├── ex_mem_reg.v             # EX/MEM pipeline register
│   ├── mem_wb_reg.v             # MEM/WB pipeline register
│   ├── forwarding_unit.v        # EX/MEM + MEM/WB forwarding for ALU/FPU operands
│   ├── hazard_unit.v            # Load-use hazard detection / stall logic
│   ├── dff.v                    # Generic parameterized flip-flop utility
│   │
│   ├── decoder.v                # Decode logic exploration
│   ├── datapath.v               # Datapath logic exploration
│   └── instr_mem_test.v         # Standalone instruction-memory sanity check
│
├── testbenches/
│   ├── top_testbench/
│   │   ├── single_cycle_core_tb.v
│   │   └── pipelined_core_tb.v  ✅ 22-test self-checking pipeline regression — MAIN TESTBENCH
│   │
│   ├── fpu_tb.v
│   ├── alu_tb.v
│   ├── regfile_tb.v
│   ├── register_file_tb.v
│   ├── control_unit_tb.v
│   ├── data_mem_tb.v
│   ├── decoder_tb.v
│   ├── immgen_tb.v
│   ├── instr_mem_tb.v
│   └── pc_tb.v
│
├── uvm/
│   └── 🧪 UVM verification environment (environment.sv, sequence.sv,
│       sequencer.sv, package.sv, testbench.sv)
│
├── hack/
│   └── Local simulation artifacts
│
└── vcd/
    └── Local waveform artifacts
```

---

## 🧮 Instruction Set Architecture

The processor uses 16-bit instructions and 8 general-purpose registers.

### Register File

```text
R0 - R7        (each 16 bits wide)
```

> `R0` is hard-wired to zero — writes to `R0` are always ignored.

<br>

### R-Type Instructions

| Instruction | Operation |
| :-: | :-- |
| `ADD` | `Rd = Rs1 + Rs2` |
| `SUB` | `Rd = Rs1 - Rs2` |
| `SLT` | Signed less-than comparison |
| `OR`  | Bitwise OR |
| `AND` | Bitwise AND |
| `SRL` | Logical right shift |
| `SLL` | Logical left shift |
| `SRA` | Arithmetic right shift |

### Immediate Instructions

| Instruction | Operation |
| :-: | :-- |
| `ADDI` | `Rd = Rs1 + imm` |
| `SUBI` | `Rd = Rs1 - imm` |
| `SLTI` | Signed less-than immediate |
| `ORI`  | Bitwise OR with immediate |
| `ANDI` | Bitwise AND with immediate |
| `SRLI` | Logical right shift by immediate |
| `SLLI` | Logical left shift by immediate |
| `SRAI` | Arithmetic right shift by immediate |

### Memory Instructions

| Instruction | Operation |
| :-: | :-- |
| `LH` | Load 16-bit value from memory |
| `SH` | Store 16-bit value to memory |

### Control-Flow Instructions

| Instruction | Operation |
| :-: | :-- |
| `BEQ`  | Branch if equal |
| `BNE`  | Branch if not equal |
| `BLT`  | Branch if signed less than |
| `BGE`  | Branch if signed greater than or equal |
| `JAL`  | Jump and link |
| `JALR` | Jump and link register |

For `JAL` and `JALR`:

```text
Rd = PC + 1
```

before transferring control to the target address.

---

## 🔢 Floating-Point Unit

The FPU operates on **IEEE-754 half-precision** values.

```text
15          10 9        0
 +-------------+----------+
 | S | Exponent | Fraction |
 +-------------+----------+
   1      5          10
```

| Operation | FPU Opcode |
| :-: | :-: |
| `FADD` | `4'b0000` |
| `FMUL` | `4'b0001` |

The implementation includes floating-point sign, exponent, and significand processing, normalization, and rounding logic. It is instantiated combinationally in both the single-cycle core and the EX stage of the pipelined core.

### FPU Instruction Encoding

FPU instructions use opcode `110`.

<table>
<tr><th>FADD</th><th>FMUL</th></tr>
<tr><td>

```text
FADD Rd, Rs1, Rs2
```
e.g. `FADD R3,R1,R2`
→ `16'h6650`

</td><td>

```text
FMUL Rd, Rs1, Rs2
```
e.g. `FMUL R4,R1,R2`
→ `16'h6851`

</td></tr>
</table>

---

## 🧱 Single-Cycle Processor

The single-cycle processor connects:

```text
PC → Instruction Memory → Control Unit
                              │
                 ┌────────────┴────────────┐
                 ▼                         ▼
          Register File           Immediate Generator
                 │                         │
                 └────────────┬────────────┘
                              ▼
                          ALU / FPU
                              │
                              ▼
                          Data Memory
                              │
                              ▼
                          Writeback
                              │
                              ▼
                        Register File
```

✅ This core is fully functional and passes its full integration testbench, including the CPU-integrated FPU.

---

## 🚀 Pipelined Processor

The 5-stage pipeline is implemented in `src/top_module/pipelined_core.v`:

```text
  IF   →   ID   →   EX   →   MEM   →   WB
Fetch    Decode   Execute   Memory   Writeback
```

<details>
<summary><strong>IF — Instruction Fetch</strong></summary>
<br>

- Program counter
- Instruction memory
- Next-PC selection (sequential, stalled, branch target, or jump target)
</details>

<details>
<summary><strong>ID — Instruction Decode</strong></summary>
<br>

- Instruction decoding via `control_unit.v`
- Register-field extraction per opcode
- Register file reads
- Immediate generation
- Hazard-unit stall/flush decisions
</details>

<details>
<summary><strong>EX — Execute</strong></summary>
<br>

- ALU operations
- FPU operations (`FADD` / `FMUL`)
- Operand forwarding from `EX/MEM` and `MEM/WB`
- Branch comparison and target calculation
- JAL/JALR target calculation (with forwarding into JALR's base register)
</details>

<details>
<summary><strong>MEM — Memory Access</strong></summary>
<br>

- `LH`
- `SH`
- Data memory access
</details>

<details>
<summary><strong>WB — Writeback</strong></summary>
<br>

- ALU result
- FPU result
- Load result
- JAL/JALR link address (`PC + 1`)
</details>

### Pipeline Registers

| Register | Boundary |
| :-- | :-- |
| `if_id_reg.v`  | IF ↔ ID |
| `id_ex_reg.v`  | ID ↔ EX |
| `ex_mem_reg.v` | EX ↔ MEM |
| `mem_wb_reg.v` | MEM ↔ WB |

Each carries the relevant datapath values and control signals forward, and supports the stall/flush signals needed for hazard handling.

---

## 🛡️ Hazard Handling

### ➡️ Data Forwarding

`forwarding_unit.v` resolves dependencies such as:

```text
ADD R1,R2,R3
SUB R4,R1,R5
```

Implemented forwarding paths:

```text
EX/MEM → EX
MEM/WB → EX
```

Both ALU and FPU operands participate in the forwarding network, and store-data for `SH` is also forwarded.

### ⏸️ Load-Use Hazard Detection

`hazard_unit.v` detects dependencies such as:

```text
LH  R1,0(R2)
ADD R3,R1,R4
```

and inserts a one-cycle stall (PC hold, IF/ID hold, ID/EX bubble) when forwarding cannot supply the value in time.

### 🔀 Control Hazards

Branches and jumps are resolved in the EX stage. On a taken branch or jump, the pipeline:

1. Redirects the PC to the computed target
2. Flushes the instruction in IF/ID
3. Flushes the instruction in ID/EX

This logic is implemented directly in `pipelined_core.v` via the unified `ex_control_taken` signal.

### 🔢 Pipelined FPU Integration

```text
                ID/EX
                  │
         ┌────────┴────────┐
         ▼                 ▼
        ALU               FPU
         │                 │
         └────────┬────────┘
                   ▼
                EX/MEM
```

`FADD`/`FMUL` results proceed through the same `EX/MEM → MEM/WB → writeback` path used for other execution results, and participate in the forwarding network like any other result.

---

## 🧪 Verification

### Single-Cycle Integration Tests
`testbenches/top_testbench/single_cycle_core_tb.v`

| Test | Covers |
| :-: | :-- |
| 1 | R-type: `ADD`, `SUB`, `SLT`, `OR`, `AND`, `SRL`, `SLL`, `SRA` |
| 2 | Immediate: `ADDI`, `SUBI`, `SLTI`, `ORI`, `ANDI`, `SRLI`, `SLLI`, `SRAI` |
| 3 | `SH`, `LH` |
| 4–7 | `BEQ`, `BNE`, `BLT`, `BGE` |
| 8–9 | `JAL`, `JALR` |
| 10 | CPU-integrated FPU: `1.0 + 2.0 = 3.0`, `1.0 × 2.0 = 2.0` |
| 11 | Standalone FPU arithmetic (6 cases, incl. negatives and zero) |

Tests 10–11 are self-checking:

```text
PASS: FADD 1.0 + 2.0 = 3.0
PASS: FMUL 1.0 * 2.0 = 2.0
PASS: 1.0 + (-1.0) = 0.0
PASS: 1.5 + 1.5 = 3.0
PASS: 1.0 * 2.0 = 2.0
PASS: 1.5 * 2.0 = 3.0
PASS: -1.0 * 2.0 = -2.0
PASS: 0.0 * 2.0 = 0.0
```

### 🟢 Pipelined Core Integration Tests — Main Testbench
`testbenches/top_testbench/pipelined_core_tb.v`

Fully self-checking (`check_reg` / `check_mem` tasks with expected values), covering **22 scenarios**:

| # | Test | | # | Test |
| :-: | :-- | :-: | :-: | :-- |
| 1 | R-type arithmetic / logical | | 12 | BNE taken |
| 2 | R-type shift operations | | 13 | BLT taken |
| 3 | Signed SLT / SLTI | | 14 | BGE taken |
| 4 | Immediate arithmetic / logical | | 15 | Branch forwarding from ALU result |
| 5 | Immediate shift operations | | 16 | JAL |
| 6 | SH / LH + address forwarding | | 17 | JALR direct target |
| 7 | EX/MEM + MEM/WB ALU forwarding | | 18 | JALR + target forwarding |
| 8 | Load-use hazard | | 19 | FPU pipeline + forwarding |
| 9 | Load-to-branch hazard | | 20 | FPU arithmetic cases |
| 10 | BEQ taken | | 21 | FPU negative / zero cases |
| 11 | BEQ not taken | | 22 | ALU result → SH store-data forwarding |

Latest simulation result:

```text
FULL 16-BIT PIPELINED CPU REGRESSION SUMMARY
============================================================
PASS COUNT = 61
FAIL COUNT = 0
ALL PIPELINE REGRESSION TESTS PASSED
============================================================
```

---

## ⚙️ Building and Simulation

The project is simulated using **Icarus Verilog**. The two top-level core testbenches are the entry points for exercising the FPU, ALU, hazard, and forwarding logic end-to-end.

### Single-Cycle Core

```bash
iverilog -o single_cycle_tb.vvp \
  testbenches/top_testbench/single_cycle_core_tb.v \
  src/single_cycle_core.v \
  src/pc.v \
  src/regfile.v \
  src/alu.v \
  src/control_unit.v \
  src/data_mem.v \
  src/immgen.v \
  src/instr_mem.v \
  src/fpu.v \
  src/mux2to1.v \
  src/mux3to1.v

vvp single_cycle_tb.vvp
```

### Pipelined Core 🟢 *(main testbench)*

```bash
iverilog -o pipelined_tb.vvp \
  testbenches/top_testbench/pipelined_core_tb.v \
  src/top_module/pipelined_core.v \
  src/pc.v \
  src/regfile.v \
  src/alu.v \
  src/control_unit.v \
  src/data_mem.v \
  src/immgen.v \
  src/instr_mem.v \
  src/fpu.v \
  src/if_id_reg.v \
  src/id_ex_reg.v \
  src/ex_mem_reg.v \
  src/mem_wb_reg.v \
  src/forwarding_unit.v \
  src/hazard_unit.v

vvp pipelined_tb.vvp
```

Both testbenches print `PASS`/`FAIL` for each checked instruction sequence and a final regression summary.

---

## 🛣️ Development Roadmap

```text
[x] Task 1 — Base single-cycle processor
[x] Task 2 — ISA extensions
[x] Task 3 — IEEE-754 half-precision FPU
[x] Task 4 — 5-stage pipelined processor
    [x] Pipeline registers (IF/ID, ID/EX, EX/MEM, MEM/WB)
    [x] Hazard detection (load-use)
    [x] Forwarding (ALU + FPU operands, store data)
    [x] Branch/jump flushing
    [x] Pipelined FPU integration
    [x] Self-checking main pipeline regression testbench (22 tests / 61 checks)
```

#### 🔜 Up Next

```text
[ ] Task 5 — UVM verification environment
[ ] Task 6 — Cryptographic co-processor
```

---

## 🎯 Design Goals

The final processor is intended to demonstrate:

| | | |
|---|---|---|
| 🏗️ Custom ISA design | 🧮 RTL datapath design | 🎛️ Control-unit design |
| ➕ Integer ALU architecture | 🔢 IEEE-754 floating-point arithmetic | 🚀 Pipeline architecture |
| 🧯 Data hazard resolution | 🔀 Control hazard handling | ➡️ Forwarding |
| 🧪 Processor verification | 🔌 Hardware/software interface design | |

The design is being developed incrementally so that each architectural stage can be verified before moving to the next. With the 5-stage pipeline now implemented — forwarding, hazard, and control-flow complete — and passing its main testbench, the focus moves on to the **UVM verification environment** and the **cryptographic co-processor**.

---

## 🧰 Tools

- Verilog HDL
- Icarus Verilog
- Xilinx Vivado
- GTKWave / FST waveform analysis

---

## 📄 License

License information will be added when the project license is finalized.
