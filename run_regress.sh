#!/bin/bash
# ============================================================================
# run_regress.sh : compile once, run every test x every seed with coverage,
# then merge the coverage of all runs and write the reports (cov_report.sh).
# Run from the project root.
#
#   ./run_regress.sh                 10 tests x seeds 1..5
#   SEEDS="1 2" ./run_regress.sh
#   COV=all ./run_regress.sh         functional + code coverage of the DUT
#
# Output:  logs/regress_summary.txt   PASS/FAIL per run
#          cov_report/                 merged coverage (see cov_report.sh)
# ============================================================================
SEEDS=${SEEDS:-"1 2 3 4 5"}
TESTS="cpu_smoke_test cpu_rand_test cpu_hazard_test cpu_wbid_bug_test cpu_ctrl_test \
cpu_mem_test cpu_fpu_test cpu_crypto_test cpu_reset_test cpu_full_test"
WAIVE="+WAIVE_KNOWN_BUG +WAIVE_FMUL_SUBNORM"

if [ "$COV" = "all" ]; then COVOPT="-coverage all -covdut pipelined_core"; else COVOPT="-coverage U"; fi

mkdir -p logs cov_summary
rm -rf cov_work cov_report

# ---- compile + elaborate once ----
xrun -64bit -sv -uvm -clean -elaborate \
     -timescale 1ns/1ps -access +rwc \
     -f files.f -top pipelined_core_tb -nowarn DSEMEL \
     $COVOPT -l logs/compile.log || { echo "COMPILE FAILED, see logs/compile.log"; exit 1; }

# ---- run ----
: > logs/regress_summary.txt
for t in $TESTS; do
  for s in $SEEDS; do
    r=${t}_s$s
    xrun -64bit -R -nowarn DSEMEL \
         -covoverwrite -covworkdir cov_work -covscope scope -covtest $r \
         +UVM_TESTNAME=$t +UVM_VERBOSITY=UVM_LOW $WAIVE +COV_SUMMARY=cov_summary/$r.txt \
         -svseed $s -l logs/$r.log > /dev/null 2>&1
    if grep -q "TEST PASSED" logs/$r.log; then res=PASS; else res=FAIL; fi
    tot=$(tail -1 cov_summary/$r.txt 2>/dev/null | awk '{print $2}')
    printf "%-20s seed %-3s %s   coverage this run %s %%\n" $t $s $res "$tot" | tee -a logs/regress_summary.txt
  done
done
echo "$(grep -c PASS logs/regress_summary.txt) passed, $(grep -c FAIL logs/regress_summary.txt) failed" | tee -a logs/regress_summary.txt

# ---- merged coverage ----
./cov_report.sh
