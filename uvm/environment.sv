
class single_cycle_core_environment extends uvm_env;
    `uvm_component_utils(single_cycle_core_environment)

    // Components
    single_cycle_core_if_scoreboard single_cycle_core_if_sc;
    single_cycle_core_if_agent single_cycle_core_if_agt_0;

    single_cycle_core_sequencer v_seqr;

    // Constructor
    function new(string name = "single_cycle_core_environment", uvm_component parent);
        super.new(name, parent);
    endfunction : new

    // Build Phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info("ENV_CLASS", "BUILD_PHASE", UVM_NONE)

        // Create components
    single_cycle_core_if_sc = single_cycle_core_if_scoreboard::type_id::create("single_cycle_core_if_sc", this);
    single_cycle_core_if_agt_0 = single_cycle_core_if_agent::type_id::create("single_cycle_core_if_agt_0", this);

        
        // Create and configure virtual sequencer
        v_seqr = single_cycle_core_sequencer::type_id::create("v_seqr", this);
        
       
    endfunction

    // Connect Phase
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info("ENV_CLASS", "CONNECT_PHASE", UVM_NONE)

        // Connect agents to scoreboard and virtual sequencer
    single_cycle_core_if_agt_0.m_monitor.item_collected_port.connect(single_cycle_core_if_sc.item_collected_export);
    v_seqr.single_cycle_core_if_seqr_0 = single_cycle_core_if_agt_0.m_sequencer;

   
    endfunction : connect_phase
endclass
