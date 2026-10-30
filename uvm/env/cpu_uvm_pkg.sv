// ============================================================================
// cpu_uvm_pkg : UVM verification environment for the 16-bit pipelined core
// ============================================================================
`include "uvm_macros.svh"

package cpu_uvm_pkg;
    import uvm_pkg::*;

    `include "cpu_isa.svh"
    `include "cpu_ref_model.svh"
    `include "cpu_txn.svh"
    `include "cpu_backdoor.svh"
    `include "cpu_agent.svh"
    `include "cpu_scoreboard.svh"
    `include "cpu_coverage.svh"
    `include "cpu_env.svh"
    `include "cpu_base_seq.svh"
    `include "cpu_seqs.svh"
    `include "cpu_tests.svh"
endpackage
