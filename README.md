# 16-Bit Custom CPU

A custom 16-bit RISC-V-style processor implemented in Verilog HDL. The project progresses from a single-cycle processor to a 5-stage pipelined architecture with hazard handling and an integrated IEEE-754 half-precision floating-point unit.

## Overview

This project implements a custom 16-bit instruction set architecture with:

* 16-bit instructions and datapath
* 8 general-purpose registers
* Separate instruction and data memories
* RISC-V-style instruction organization
* Single-cycle processor
* IEEE-754 half-precision FPU
* FADD and FMUL instructions
* Planned 5-stage pipelined processor
* Hazard detection and forwarding
* Planned cryptographic co-processor

The processor is developed incrementally, with each stage validated through Verilog simulation.

---

## Project Status

| Component                     | Status                      |
| ----------------------------- | --------------------------- |
| Base single-cycle CPU         | ✅ Functional                |
| R-type ALU instructions       | ✅ Functional                |
| Immediate instructions        | ✅ Implemented               |
| Load / Store                  | ✅ Functional                |
| Branch instructions           | ✅ Implemented and exercised |
| JAL / JALR                    | ✅ Implemented and exercised |
| IEEE-754 half-precision FPU   | ✅ Functional                |
| FADD                          | ✅ Verified                  |
| FMUL                          | ✅ Verified                  |
| FPU CPU integration           | ✅ Verified                  |
| 5-stage pipeline architecture | 🟡 In Progress              |
| Hazard detection              | ⬜ Not Started               |
| Forwarding unit               | ⬜ Not Started               |
| Pipeline branch handling      | ⬜ Not Started               |
| Pipelined FPU integration     | ⬜ Not Started               |
| Crypto co-processor           | ⬜ Not Started               |

---

## Repository Structure

```text
16-bit-custom-cpu/
│
├── src/
│   ├── single_cycle_core.v
│   ├── pipelined_core.v
│   ├── alu.v
│   ├── fpu.v
│   ├── control_unit.v
│   ├── regfile.v
│   ├── pc.v
│   ├── immgen.v
│   ├── instr_mem.v
│   ├── data_mem.v
│   ├── mux2to1.v
│   ├── mux3to1.v
│   └── ...
│
├── testbenches/
│   ├── top_testbench/
│   │   └── single_cycle_core_tb.v
│   ├── fpu_tb.v
│   ├── regfile_tb.v
│   ├── alu_tb.v
│   └── ...
│
├── uvm/
│   └── Early UVM verification environment
│
├── hack/
│   └── Local simulation artifacts
│
└── vcd/
    └── Local waveform artifacts
```

---

# Instruction Set Architecture

The processor uses 16-bit instructions and 8 general-purpose registers.

## Register File

```text
R0 - R7
```

Each register is 16 bits wide.

`R0` is maintained as zero and writes to R0 are ignored.

---

## R-Type Instructions

| Instruction | Operation                    |
| ----------- | ----------------------------- |
| ADD         | `Rd = Rs1 + Rs2`              |
| SUB         | `Rd = Rs1 - Rs2`              |
| SLT         | Signed less-than comparison   |
| OR          | Bitwise OR                    |
| AND         | Bitwise AND                   |
| SRL         | Logical right shift           |
| SLL         | Logical left shift            |
| SRA         | Arithmetic right shift        |

---

## Immediate Instructions

| Instruction | Operation                            |
| ----------- | ------------------------------------- |
| ADDI        | `Rd = Rs1 + imm`                      |
| SUBI        | `Rd = Rs1 - imm`                      |
| SLTI        | Signed less-than immediate            |
| ORI         | Bitwise OR with immediate             |
| ANDI        | Bitwise AND with immediate            |
| SRLI        | Logical right shift by immediate      |
| SLLI        | Logical left shift by immediate       |
| SRAI        | Arithmetic right shift by immediate   |

---

## Memory Instructions

| Instruction | Operation                      |
| ----------- | ------------------------------- |
| LH          | Load 16-bit value from memory  |
| SH          | Store 16-bit value to memory   |

---

## Control-Flow Instructions

| Instruction | Operation                               |
| ----------- | ----------------------------------------- |
| BEQ         | Branch if equal                         |
| BNE         | Branch if not equal                     |
| BLT         | Branch if signed less than              |
| BGE         | Branch if signed greater than or equal  |
| JAL         | Jump and link                           |
| JALR        | Jump and link register                  |

For JAL and JALR:

```text
Rd = PC + 1
```

before transferring control to the target address.

---

# Floating-Point Unit

The FPU operates on IEEE-754 half-precision values.

### Format

```text
15          10 9        0
+-------------+----------+
| S | Exponent | Fraction |
+-------------+----------+
  1      5          10
```

The FPU currently supports:

| Operation | FPU Opcode |
| --------- | ---------- |
| FADD      | `4'b0000`  |
| FMUL      | `4'b0001`  |

The implementation includes floating-point sign, exponent, and significand processing, normalization, and rounding logic.

---

# FPU Instruction Encoding

The FPU instructions use opcode `110`.

### FADD

```text
FADD Rd, Rs1, Rs2
```

Example:

```text
FADD R3,R1,R2
```

Machine code:

```text
16'h6650
```

### FMUL

```text
FMUL Rd, Rs1, Rs2
```

Example:

```text
FMUL R4,R1,R2
```

Machine code:

```text
16'h6851
```

---

# Single-Cycle Processor

The current single-cycle processor connects:

```text
PC
 │
 ▼
Instruction Memory
 │
 ▼
Control Unit
 │
 ├───────────────┐
 ▼               ▼
Register File   Immediate Generator
 │               │
 └──────┬────────┘
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

The single-cycle processor currently provides the working baseline for the pipelined implementation.

---

# Verification

The current integration testbench exercises the processor using actual 16-bit machine instructions.

## Single-Cycle Integration Tests

### Test 1

R-Type operations:

```text
ADD
SUB
SLT
OR
AND
SRL
SLL
SRA
```

### Test 2

Immediate operations:

```text
ADDI
SUBI
SLTI
ORI
ANDI
SRLI
SLLI
SRAI
```

### Test 3

```text
SH
LH
```

### Tests 4–7

```text
BEQ
BNE
BLT
BGE
```

### Tests 8–9

```text
JAL
JALR
```

### Test 10

CPU-integrated FPU:

```text
FADD 1.0 + 2.0 = 3.0
FMUL 1.0 × 2.0 = 2.0
```

### Test 11

Standalone FPU arithmetic:

```text
1.0 + (-1.0) = 0.0
1.5 + 1.5   = 3.0

1.0 × 2.0   = 2.0
1.5 × 2.0   = 3.0
-1.0 × 2.0  = -2.0
0.0 × 2.0   = 0.0
```

All six standalone FPU cases currently pass.

The latest simulation also confirms both CPU-integrated FPU operations pass:

```text
PASS: FADD 1.0 + 2.0 = 3.0
PASS: FMUL 1.0 * 2.0 = 2.0
```

---

# Pipelined Processor

The next major development stage is a 5-stage pipeline:

```text
IF → ID → EX → MEM → WB
```

## Pipeline Stages

### IF — Instruction Fetch

* Program counter
* Instruction memory
* PC increment

### ID — Instruction Decode

* Instruction decoding
* Register file reads
* Immediate generation
* Control generation

### EX — Execute

* ALU operations
* FPU operations
* Branch comparison
* Branch target calculation
* JAL/JALR target calculation

### MEM — Memory Access

* LH
* SH
* Data memory access

### WB — Writeback

* ALU result
* FPU result
* Load result
* JAL/JALR link address

---

## Pipeline Registers

The pipeline will use:

```text
IF/ID
ID/EX
EX/MEM
MEM/WB
```

These registers will carry both datapath values and control signals between stages.

---

# Hazard Handling

The pipelined processor will include two major mechanisms.

## Data Forwarding

Forwarding paths will handle dependencies such as:

```text
ADD R1,R2,R3
SUB R4,R1,R5
```

Planned forwarding paths:

```text
EX/MEM → EX
MEM/WB → EX
```

Both ALU and FPU results will participate in the forwarding network.

---

## Load-Use Hazard Detection

For dependencies such as:

```text
LH  R1,0(R2)
ADD R3,R1,R4
```

the hazard detection unit will insert a pipeline stall when forwarding cannot provide the required value in time.

---

# Control Hazards

Branches and jumps will be resolved in the execution stage.

The pipeline will provide:

* PC redirection
* IF/ID flushing
* ID/EX flushing
* Branch and jump control handling

---

# Pipelined FPU Integration

The FPU will be integrated into the EX stage alongside the integer ALU.

```text
             ID/EX
                │
        ┌───────┴───────┐
        │               │
        ▼               ▼
       ALU             FPU
        │               │
        └───────┬───────┘
                │
             EX/MEM
```

FADD and FMUL results will proceed through the same pipeline structure used for other execution results.

The forwarding network will also support dependencies on FPU results.

---

# Current Pipeline Development Plan

The pipeline is being developed in the following order:

1. Define IF/ID pipeline register
2. Define ID/EX pipeline register
3. Define EX/MEM pipeline register
4. Define MEM/WB pipeline register
5. Connect the existing datapath through the five stages
6. Integrate ALU execution
7. Integrate FPU execution
8. Implement forwarding
9. Implement load-use hazard detection
10. Implement branch/jump flushing
11. Create pipelined processor testbench
12. Verify instruction sequences involving dependencies

---

# Known Issues

The current repository still contains several items that are being cleaned up as the design transitions from the single-cycle implementation to the pipelined implementation.

### Pipelined Core

The existing `pipelined_core.v` is not yet the final implementation. It requires:

* Alignment with the current `regfile.v` interface
* Alignment with the current combinational `fpu.v` interface
* Correct 3-bit opcode extraction
* Consistent register-field decoding
* Pipeline register implementation
* Forwarding logic
* Hazard detection
* Branch/jump flushing

The pipeline will be restructured around the current working single-cycle datapath rather than treating the existing incomplete pipeline as the final architecture.

### Verification

Tests 1–9 of the current single-cycle integration testbench primarily provide signal traces. They should eventually be converted into self-checking tests with explicit expected values.

### Standalone FPU Testbench

The older `fpu_tb.v` must use:

```text
FADD = 4'b0000
FMUL = 4'b0001
```

to match the current FPU implementation.

---

# Building and Simulation

The project can be simulated using Icarus Verilog.

## Single-Cycle Core

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

The integration testbench currently exercises the single-cycle processor and FPU.

---

# Development Roadmap

```text
[x] Task 1 — Base single-cycle processor
[x] Task 2 — ISA extensions
[x] Task 3 — IEEE-754 half-precision FPU
[ ] Task 4 — 5-stage pipelined processor
[ ] Hazard detection
[ ] Forwarding
[ ] Branch/jump flushing
[ ] Pipelined FPU integration
[ ] Task 5 — Cryptographic co-processor
```

---

# Design Goals

The final processor is intended to demonstrate:

* Custom ISA design
* RTL datapath design
* Control-unit design
* Integer ALU architecture
* IEEE-754 floating-point arithmetic
* Pipeline architecture
* Data hazard resolution
* Control hazard handling
* Forwarding
* Processor verification
* Hardware/software interface design

The design is being developed incrementally so that each architectural stage can be verified before moving to the next.

---

## Tools

* Verilog HDL
* Icarus Verilog
* Xilinx Vivado
* GTKWave / FST waveform analysis

---

## License

License information will be added when the project license is finalized.
