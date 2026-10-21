
class task_utils;
    static task pipelined_core_if_drive_conditions(virtual pipelined_core_if vif, pipelined_core_if_seq_item item);
        // ---- drive the DUT inputs ----
        
    endtask

    static task pipelined_core_if_monitor_conditions(virtual pipelined_core_if vif, uvm_analysis_port#(pipelined_core_if_seq_item) item_collected_port);
        pipelined_core_if_seq_item item = pipelined_core_if_seq_item::type_id::create("item");
        // ---- sample the DUT ----
        item_collected_port.write(item);
    endtask

    static function void pipelined_core_if_scoreboard_conditions(pipelined_core_if_seq_item pkt, string name = "SCB");
        `uvm_info(name, $sformatf("Received packet:\n%s", pkt.sprint()), UVM_LOW)
        //TODO make your scoreboard logic here
    endfunction
endclass
