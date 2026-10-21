package pipelined_core_pkg;

  `include "uvm_macros.svh"

  import uvm_pkg::*;
    import pipelined_core_if_pkg::*;
  `include "pipelined_core_v_sequencer.sv"
  `include "pipelined_core_v_sequence.sv"
  `include "pipelined_core_environment.sv"
  `include "pipelined_core_test.sv"

endpackage : pipelined_core_pkg
