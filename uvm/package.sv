package single_cycle_core_pkg;

  `include "uvm_macros.svh"

  import uvm_pkg::*;
    import single_cycle_core_if_pkg::*;
  `include "single_cycle_core_v_sequencer.sv"
  `include "single_cycle_core_v_sequence.sv"
  `include "single_cycle_core_environment.sv"
  `include "single_cycle_core_test.sv"

endpackage : single_cycle_core_pkg
