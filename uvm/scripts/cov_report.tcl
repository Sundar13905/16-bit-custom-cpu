# ============================================================================
# cov_report.tcl : IMC batch script (called by cov_report.sh)
#   imc -exec uvm/scripts/cov_report.tcl
# Merges every run under cov_work/scope into cov_merged, then writes text and
# HTML covergroup reports into cov_report/.
# ============================================================================
set runs {}
foreach d [lsort [glob -nocomplain -type d cov_work/scope/*]] {
    if {[file tail $d] ne "cov_merged"} { lappend runs $d }
}
if {[llength $runs] == 0} { puts "cov_report.tcl: no runs in cov_work/scope"; exit }
puts "cov_report.tcl: merging [llength $runs] run(s)"

merge {*}$runs -overwrite -out cov_merged

# depending on the IMC version the merged run lands in ./cov_merged or
# under cov_work/scope/
if {[file isdirectory cov_merged]} { load -run cov_merged } else { load -run cov_work/scope/cov_merged }

report -summary -metrics covergroup -out cov_report/summary.txt
report -detail  -metrics covergroup -all -out cov_report/detail.txt
report -html -detail -metrics covergroup -out cov_report/html
exit
