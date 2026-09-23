// Note: the Verilator flow does not default RSP=REQ, so both params are spelled out.
`ifdef VERILATOR
class single_cycle_core_sequencer extends uvm_sequencer#(uvm_sequence_item, uvm_sequence_item);
`else
class single_cycle_core_sequencer extends uvm_sequencer;
`endif
  `uvm_component_utils(single_cycle_core_sequencer)

  // Sequencer array declarations
single_cycle_core_if_sequencer single_cycle_core_if_seqr_0;

  function new(string name = "v_sequencer", uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction
endclass
