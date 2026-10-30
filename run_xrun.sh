#!/bin/bash
# ============================================================================
# run_xrun.sh : compile + run ONE test of the UVM environment with Xcelium and
# collect functional (covergroup) coverage.  Run from the project root.
#
#   ./run_xrun.sh                         cpu_full_test, seed 1
#   ./run_xrun.sh cpu_rand_test 7         any test, any seed
#   COV=all ./run_xrun.sh                 functional + code coverage of the DUT
#   GUI=1   ./run_xrun.sh cpu_smoke_test  open SimVision
#   STRICT=1 ./run_xrun.sh                no known-bug waivers (test FAILS on
#                                         the two documented RTL bugs, by design)
#
# Output:  logs/<test>_s<seed>.log               simulation log
#          cov_summary/<test>_s<seed>.txt         plain-text coverage of this run
#          cov_work/scope/<test>_s<seed>/         Xcelium coverage database
#          (merged report over all runs: ./cov_report.sh)
# ============================================================================
TEST=${1:-cpu_full_test}
SEED=${2:-${SEED:-1}}
RUN=${TEST}_s${SEED}

WAIVE="+WAIVE_KNOWN_BUG +WAIVE_FMUL_SUBNORM"
[ -n "$STRICT" ] && WAIVE=""

if [ "$COV" = "all" ]; then
    COVOPT="-coverage all -covdut pipelined_core"   # + block/expr/toggle/fsm of the DUT
else
    COVOPT="-coverage U"                            # U = functional: covergroups
fi

EXTRA=""
[ -n "$GUI" ] && EXTRA="-gui"

mkdir -p logs cov_summary
xrun -64bit -sv -uvm -clean \
     -timescale 1ns/1ps \
     -access +rwc \
     -f files.f \
     -top pipelined_core_tb \
     -nowarn DSEMEL \
     $COVOPT -covoverwrite -covworkdir cov_work -covscope scope -covtest $RUN \
     +UVM_TESTNAME=$TEST +UVM_VERBOSITY=UVM_LOW \
     $WAIVE +COV_SUMMARY=cov_summary/$RUN.txt \
     -svseed $SEED \
     -l logs/$RUN.log \
     $EXTRA
status=$?

echo
grep -E "TEST (PASSED|FAILED)|known-bug hits" logs/$RUN.log | sed 's/^.*\] //'
[ -f cov_summary/$RUN.txt ] && tail -1 cov_summary/$RUN.txt
exit $status
