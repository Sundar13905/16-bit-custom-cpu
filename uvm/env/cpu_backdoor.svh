// ============================================================================
// cpu_backdoor.svh : abstract backdoor to the DUT's internal memories.
//
// The DUT has only clk/rst ports, so programs are loaded straight into
// IMEM / DMEM / the register file.  The concrete class lives in the top module
// (pipelined_core_tb.sv), where the hierarchical paths are legal, and is passed
// to the driver through uvm_config_db ("backdoor").
// ============================================================================
virtual class cpu_backdoor;
    pure virtual function void         write_imem(int unsigned a, logic [15:0] d);
    pure virtual function void         write_dmem(int unsigned a, logic [15:0] d);
    pure virtual function void         write_reg (int unsigned r, logic [15:0] d);
    pure virtual function logic [15:0] read_dmem (int unsigned a);
    pure virtual function logic [15:0] read_reg  (int unsigned r);
endclass
