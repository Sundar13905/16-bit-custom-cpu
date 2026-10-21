
class pipelined_core_if_seq_item extends uvm_sequence_item;

    `uvm_object_utils_begin(pipelined_core_if_seq_item)
    `uvm_object_utils_end

    function new(string name = "pipelined_core_if_seq_item");
        super.new(name);
    endfunction

endclass
