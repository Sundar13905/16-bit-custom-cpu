// ============================================================================
// cpu_probe_if : white-box observation interface.
//
// The DUT (pipelined_core) only has clk/rst ports, so this interface is
// bound INTO the DUT (see pipelined_core_tb.sv) and its ports are connected to internal
// pipeline nets.  It is strictly read-only: nothing here drives the DUT.
// ============================================================================
interface cpu_probe_if (
    input logic        clk,
    input logic        rst,

    // IF stage
    input logic [15:0] pc_out,
    input logic [15:0] if_instr,

    // ID stage
    input logic [15:0] if_id_pc,
    input logic [15:0] if_id_instr,
    input logic [2:0]  id_rs1,            // id_rf_read_addr1 (0 when unused)
    input logic [2:0]  id_rs2,            // id_rf_read_addr2 (0 when unused)
    input logic        hz_stall,          // load-use: PC + IF/ID hold
    input logic        hz_flush,          // load-use: ID/EX bubble

    // EX stage
    input logic [15:0] id_ex_pc,
    input logic [1:0]  fwd_a,
    input logic [1:0]  fwd_b,
    input logic [15:0] ex_op_a,           // forwarded operand A
    input logic [15:0] ex_op_b,           // forwarded operand B (pre imm-mux)
    input logic [15:0] ex_result,
    input logic        ex_branch_taken,
    input logic [15:0] ex_branch_target,
    input logic        ex_jump_taken,
    input logic [15:0] ex_jump_target,
    input logic        ex_ctrl_taken,

    // MEM stage
    input logic        mem_we,
    input logic        mem_re,
    input logic [15:0] mem_addr,
    input logic [15:0] mem_wdata,
    input logic [15:0] mem_rdata,

    // WB stage
    input logic        wb_we,
    input logic [2:0]  wb_rd,
    input logic [15:0] wb_data
);
endinterface
