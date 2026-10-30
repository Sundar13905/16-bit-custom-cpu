# UVM environment with functional coverage: Cadence Xcelium

Full UVM environment for `src/top_module/pipelined_core.v`: constrained-random and directed
program sequences, a driver that loads programs through a backdoor, a shadow-pipeline monitor,
an instruction-set reference model (ALU, binary16 FPU, Feistel crypto), a lock-step scoreboard,
and a functional coverage model with 28 covergroups.

## Run (from this folder, the one with `src/` and `uvm/`)

```bash
chmod +x *.sh
./run_xrun.sh                      # cpu_full_test, seed 1, functional coverage on
./run_xrun.sh cpu_rand_test 7      # any test, any seed
./run_regress.sh                   # 10 tests x 5 seeds, then merged coverage report
./cov_report.sh                    # (re)merge whatever is in cov_work/ and print the report
imc -load cov_merged               # browse the merged coverage in the IMC GUI
```

Options: `COV=all` adds code coverage (block/expression/toggle/FSM) of `pipelined_core`,
`GUI=1` opens SimVision, `STRICT=1` turns the known-bug waivers off, `SEEDS="1 2"` for the
regression.

The single command that `run_xrun.sh` runs is:

```bash
xrun -64bit -sv -uvm -clean -timescale 1ns/1ps -access +rwc -f files.f -top pipelined_core_tb \
     -nowarn DSEMEL -coverage U -covoverwrite -covworkdir cov_work -covscope scope \
     -covtest cpu_full_test_s1 +UVM_TESTNAME=cpu_full_test +UVM_VERBOSITY=UVM_LOW \
     +WAIVE_KNOWN_BUG +WAIVE_FMUL_SUBNORM +COV_SUMMARY=cov_summary/cpu_full_test_s1.txt \
     -svseed 1 -l logs/cpu_full_test_s1.log
```

## Where the coverage ends up

| File | What |
| :-- | :-- |
| `logs/<test>_s<seed>.log` | log; ends with `*** TEST PASSED ***` and a per-covergroup coverage table (`[COV]` lines) |
| `cov_summary/<test>_s<seed>.txt` | the same coverage table as plain text, one run |
| `cov_work/scope/<test>_s<seed>/` | Xcelium coverage database of that run |
| `cov_report/summary.txt` | IMC: merged covergroup coverage over all runs |
| `cov_report/detail.txt` | IMC: every coverpoint / cross bin with hit counts (holes show as 0) |
| `cov_report/html/` | IMC HTML report |
| `logs/regress_summary.txt` | PASS/FAIL and coverage per run (regression) |

The per-run table is computed by the testbench itself with the standard
`get_inst_coverage()`, so it reads the same on any simulator. The merged numbers come from IMC.
Reference numbers from the open-source check (Verilator 5.052, same code): `cpu_full_test` seed 1
reaches 99.85 % on its own (2 of 936 bins still empty), the full regression (10 tests x 5 seeds)
merged reaches 100 % (936/936 bins, 28 covergroups) with 50/50 runs passing. IMC may count
cross bins slightly differently, so expect the same picture, not necessarily identical bin totals.

## Tests

| Test | What it does |
| :-- | :-- |
| `cpu_smoke_test` | 4 directed programs |
| `cpu_rand_test` | constrained-random programs (`+N_PROG=<n>`, default 20) |
| `cpu_hazard_test` | producer x consumer x RAW distance 1..4 matrix |
| `cpu_wbid_bug_test` | distance-3 matrix; passes only if the seeded WB->ID bypass bug IS detected |
| `cpu_ctrl_test` | branches, JAL/JALR, back-to-back redirects |
| `cpu_mem_test` | load/store, address corners, store->load distances |
| `cpu_fpu_test` | binary16 corner values (zero, subnormal, Inf, NaN, rounding) |
| `cpu_crypto_test` | ENC/DEC chains |
| `cpu_reset_test` | reset in the middle of a program (store in MEM, redirect in EX, stall) |
| `cpu_full_test` | all of the above in one run |

## Known RTL bugs (kept on purpose) and the waivers

1. **WB->ID bypass missing** (`KNOWN_BUG_WB_ID`): an instruction that reads a register in the
   same cycle the instruction 3 ahead writes it in WB gets the old value. This is the seeded
   bug you chose to keep.
2. **FMUL with a subnormal operand** (`KNOWN_BUG_FMUL_SUBNORM`): `fp16_mul` in `fpu.v` does not
   normalise subnormal inputs, e.g. `0x8200 * 0x7800` gives `0xC200`, the right answer is `0xBC00`.

`+WAIVE_KNOWN_BUG +WAIVE_FMUL_SUBNORM` (on by default in the scripts) turn exactly these two
scoreboard errors into warnings; every other mismatch is still an error. With `STRICT=1` the
tests that hit them fail, which is the expected result.

## Layout

| Path | Contents |
| :-- | :-- |
| `files.f` | compile list (RTL + UVM, in order) |
| `uvm/tb/pipelined_core_tb.sv` | top: clock, DUT, probe `bind`, backdoor class, `run_test()` |
| `uvm/tb/cpu_probe_if.sv` | read-only white-box probe bound inside the DUT |
| `uvm/tb/cpu_ctrl_if.sv` | reset |
| `uvm/env/` | `cpu_uvm_pkg.sv` (package) and the class files it includes: ISA, reference model, transactions, backdoor, agent (driver/monitor/sequencer), scoreboard, coverage, env |
| `uvm/seq/`, `uvm/tests/` | sequences and the 10 tests |
| `uvm/scripts/cov_report.tcl` | IMC batch script used by `cov_report.sh` |
| `old_uvm_skeleton/` | your original generated skeleton, not compiled (kept for reference) |

## Changes from the zip you sent

- `uvm/` now holds the full environment; the generated skeleton moved to `old_uvm_skeleton/`.
- `src/top_module/pipelined_core.v`: 7 wire declarations moved to the top of the module
  (used before declared; Xcelium rejects that). No logic change. Same as the previous fix.
- `files.f`: only the RTL that `pipelined_core` uses, so there are no duplicate-module warnings
  (`datapath.v` and `decoder.v` both define `decoder`; `testbenches/` has another `pipelined_core_tb`).

## If something goes wrong

- Compile error: send `logs/<run>.log` (or `logs/compile.log` from the regression).
- `cov_report.sh` writes nothing: send `logs/imc.log`. IMC report options differ a little
  between versions; the per-run tables in `cov_summary/` do not depend on IMC.
- `-uvm` uses the UVM that ships with Xcelium. The environment uses only the API common to
  UVM 1.1d, 1.2 and IEEE 1800.2, so any of them works (`-uvmhome CDNS-1.2` to pick one).
