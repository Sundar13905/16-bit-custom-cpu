
class pipelined_core_if_agent extends uvm_agent;
    `uvm_component_utils(pipelined_core_if_agent)

    pipelined_core_if_config    cfg;
    pipelined_core_if_monitor m_monitor;
    pipelined_core_if_sequencer m_sequencer;
    pipelined_core_if_driver m_driver;

    function new(string name = "pipelined_core_if_agent", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        `uvm_info("AGENT_CLASS", "BUILD_PHASE", UVM_NONE)

        // Fetch this agent's configuration; fall back to a default ACTIVE object.
        if (!uvm_config_db#(pipelined_core_if_config)::get(this, "", "cfg", cfg)) begin
            `uvm_warning("NOCFG", {"No config set for ", get_full_name(), " - using defaults"})
            cfg = pipelined_core_if_config::type_id::create("cfg");
        end
        // Make the config visible to the driver and monitor below.
        uvm_config_db#(pipelined_core_if_config)::set(this, "*", "cfg", cfg);

        // The monitor is always present (active or passive).
        m_monitor = pipelined_core_if_monitor::type_id::create("m_monitor", this);

        // Driver and sequencer only exist in an ACTIVE agent.
        if (cfg.is_active == UVM_ACTIVE) begin
            m_sequencer = pipelined_core_if_sequencer::type_id::create("m_sequencer", this);
            m_driver    = pipelined_core_if_driver::type_id::create("m_driver", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        `uvm_info("AGENT_CLASS", "CONNECT_PHASE", UVM_NONE)
        if (cfg.is_active == UVM_ACTIVE)
            m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
    endfunction

endclass : pipelined_core_if_agent
