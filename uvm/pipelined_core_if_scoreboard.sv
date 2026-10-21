
class pipelined_core_if_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(pipelined_core_if_scoreboard)

    uvm_analysis_imp#(pipelined_core_if_seq_item, pipelined_core_if_scoreboard) item_collected_export;

    function new(string name = "pipelined_core_if_scoreboard", uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        item_collected_export = new("item_collected_export",this);
    endfunction

    virtual function void write(pipelined_core_if_seq_item pkt);
        task_utils::pipelined_core_if_scoreboard_conditions(pkt, get_name());
    endfunction

endclass
