
class single_cycle_core_sequence extends uvm_sequence;
  `uvm_object_utils(single_cycle_core_sequence)
  `uvm_declare_p_sequencer(single_cycle_core_sequencer)

  function new(string name = "single_cycle_core_sequence");
    super.new(name);
  endfunction

  // Sequence array declarations
  single_cycle_core_if_seq seq_single_cycle_core_if_0;


  virtual task pre_body();
    super.pre_body();
    if (p_sequencer == null)
      `uvm_fatal("SEQ", "Virtual sequencer handle is null")
    seq_single_cycle_core_if_0 = single_cycle_core_if_seq::type_id::create("seq_single_cycle_core_if_0");

  endtask

  virtual task body();
    
      // Task sequence start

    // Every bus and every instance run TOGETHER: the fork covers them all, and
    // `join` waits for the slowest. Serialising them would hide anything that
    // only goes wrong when two buses are active at the same time.
    fork
      // single_cycle_core_if instance 0
      if (p_sequencer.single_cycle_core_if_seqr_0 != null) begin
          seq_single_cycle_core_if_0.start(p_sequencer.single_cycle_core_if_seqr_0);
      end
    join

   
  endtask
endclass
