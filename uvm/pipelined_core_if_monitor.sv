
class pipelined_core_if_monitor extends uvm_monitor;
    `uvm_component_utils(pipelined_core_if_monitor)

    pipelined_core_if_config cfg;
    virtual pipelined_core_if vif;
    pipelined_core_if_seq_item item;
    uvm_analysis_port#(pipelined_core_if_seq_item) item_collected_port;

    function new(string name = "pipelined_core_if_monitor", uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(pipelined_core_if_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", {"Config must be set for: ", get_full_name()});
        vif = cfg.vif;
    endfunction

    virtual task main_phase(uvm_phase phase);
        super.main_phase(phase);
        // Wait for reset release, then sample on the monitor clocking block.
        @(posedge vif.clk);
        wait (vif.rstn === 1'b1);
        forever begin
            @(vif.mon_cb);
            collect_item();
        end
    endtask

    virtual task collect_item();
        task_utils::pipelined_core_if_monitor_conditions(vif, item_collected_port);
    endtask

endclass
