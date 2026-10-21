
// Per-agent configuration: passed in via uvm_config_db#(pipelined_core_if_config).
class pipelined_core_if_config extends uvm_object;
    `uvm_object_utils(pipelined_core_if_config)

    // Build the agent as active (driver + sequencer) or passive (monitor only).
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    // Virtual interface handle for this agent instance.
    virtual pipelined_core_if vif;

    function new(string name = "pipelined_core_if_config");
        super.new(name);
    endfunction
endclass
