
class pipelined_core_if_driver extends uvm_driver#(pipelined_core_if_seq_item);
    `uvm_component_utils(pipelined_core_if_driver)

    pipelined_core_if_config cfg;
    virtual pipelined_core_if vif;

    function new(string name = "pipelined_core_if_driver", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(pipelined_core_if_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", {"Config must be set for: ", get_full_name()});
        vif = cfg.vif;
    endfunction

    virtual task main_phase(uvm_phase phase);
        super.main_phase(phase);
        // Hold off driving until reset is released.
        @(posedge vif.clk);
        wait (vif.rstn === 1'b1);
        forever begin
            seq_item_port.get_next_item(req);
            drive_item(req);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_item(pipelined_core_if_seq_item item);
        @(vif.drv_cb);   // synchronize to the driver clocking block
        task_utils::pipelined_core_if_drive_conditions(vif, item);
    endtask

endclass
