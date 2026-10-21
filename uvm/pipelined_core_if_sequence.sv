
class pipelined_core_if_seq extends uvm_sequence#(pipelined_core_if_seq_item);
    `uvm_object_utils(pipelined_core_if_seq)

    // Number of transactions to generate (override with +NUM_ITEMS=<n>).
    int unsigned num_items = 20;

    function new(string name = "pipelined_core_if_seq");
        super.new(name);
    endfunction

    virtual task body();
        //TODO customize your stimulus here
        begin int unsigned cfg_n;
          if (uvm_config_db#(int unsigned)::get(null, "*", "num_items", cfg_n))
            num_items = cfg_n;
        end
        void'($value$plusargs("NUM_ITEMS=%d", num_items));
        for (int unsigned i = 0; i < num_items; i++) begin
            req = pipelined_core_if_seq_item::type_id::create("req");
            start_item(req);
            if (!req.randomize())
                `uvm_error(get_type_name(), "randomize() failed")
            finish_item(req);
        end
    endtask
endclass
