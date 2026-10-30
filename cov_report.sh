#!/bin/bash
# ============================================================================
# cov_report.sh : merge every run in cov_work/scope/ with IMC and write
#   cov_report/summary.txt   one line per covergroup (merged over all runs)
#   cov_report/detail.txt    every coverpoint / cross bin, hit counts, holes
#   cov_report/html/         same, browsable
# Run from the project root after run_xrun.sh or run_regress.sh.
#   GUI:  imc -load cov_merged     (after this script)
# ============================================================================
[ -d cov_work/scope ] || { echo "no cov_work/scope: run ./run_xrun.sh or ./run_regress.sh first"; exit 1; }
mkdir -p cov_report logs
imc -exec uvm/scripts/cov_report.tcl -logfile logs/imc.log
echo
echo "==== merged functional coverage (cov_report/summary.txt) ===="
cat cov_report/summary.txt 2>/dev/null || echo "IMC did not write the report; see logs/imc.log"
