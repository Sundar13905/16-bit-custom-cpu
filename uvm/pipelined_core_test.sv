
class pipelined_core_test extends uvm_test;
    `uvm_component_utils(pipelined_core_test)
    
    pipelined_core_environment env;
    pipelined_core_sequence vseq;
    
    // Constructor
    function new(string name = "pipelined_core_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new
    
    // Build Phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info("TEST_CLASS", "BUILD_PHASE", UVM_NONE)
        
        // Create environment and sequence
        env = pipelined_core_environment::type_id::create("env", this);
        vseq = pipelined_core_sequence::type_id::create("vseq");
    endfunction : build_phase
    
    // Main Phase
    virtual task main_phase(uvm_phase phase);
        int unsigned drain_ns = 100;   // tail time after the sequence completes
        super.main_phase(phase);
        phase.raise_objection(this);

        `uvm_info("TEST_CLASS", "MAIN_PHASE", UVM_NONE)
        void'($value$plusargs("DRAIN_NS=%d", drain_ns));
        vseq.start(env.v_seqr);
        #(drain_ns);

        phase.drop_objection(this);
    endtask : main_phase

endclass 

// ---------------------------------------------------------------------------
// Variants of the test above. They exist so the Simulate step offers more than
// one thing to run: the same environment and the same stimulus, at a different
// transaction count. Both set `num_items` through the config DB, which every
// generated VIP sequence reads; +NUM_ITEMS=<n> on the command line still wins.
//
// Add your own the same way - anything in this file that extends pipelined_core_test
// shows up in the Simulate step's test list automatically.
// ---------------------------------------------------------------------------

// A quick pass: enough to prove the environment is wired up, fast enough to run
// after every edit.
class pipelined_core_smoke_test extends pipelined_core_test;
    `uvm_component_utils(pipelined_core_smoke_test)

    function new(string name = "pipelined_core_smoke_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        uvm_config_db#(int unsigned)::set(null, "*", "num_items", 5);
        super.build_phase(phase);
        `uvm_info("TEST_CLASS", "smoke test: 5 items per agent", UVM_NONE)
    endfunction : build_phase
endclass

// A long pass. More transactions is the cheapest way to widen coverage on a
// randomised stimulus, so this is the one to run before believing a result.
class pipelined_core_stress_test extends pipelined_core_test;
    `uvm_component_utils(pipelined_core_stress_test)

    function new(string name = "pipelined_core_stress_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    virtual function void build_phase(uvm_phase phase);
        uvm_config_db#(int unsigned)::set(null, "*", "num_items", 200);
        super.build_phase(phase);
        `uvm_info("TEST_CLASS", "stress test: 200 items per agent", UVM_NONE)
    endfunction : build_phase

    virtual task main_phase(uvm_phase phase);
        // A longer run needs a longer tail before the objection drops.
        super.main_phase(phase);
    endtask : main_phase
endclass
