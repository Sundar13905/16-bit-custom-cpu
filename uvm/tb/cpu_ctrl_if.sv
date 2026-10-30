// ============================================================================
// cpu_ctrl_if : the only signal the TB actively drives is rst (clk is free
// running).  Program/data memories and the register file are internal arrays
// in the DUT; they are loaded and read through cpu_backdoor (see
// env/cpu_backdoor.svh and pipelined_core_tb.sv), not through this interface,
// because an interface used as a virtual interface must not contain
// hierarchical references outside its own body (IEEE 1800 25.9).
// ============================================================================
interface cpu_ctrl_if (input logic clk);
    logic rst;
endinterface
