`timescale 1ns / 1ps

module datapath(
    input clk,
    input reset,
    // Control signals from control unit
    input reg_write,
    input mem_read,
    input mem_write,
    input alu_src,
    input branch,
    input jump,
    input [3:0] alu_ctrl,
    output zero,
    // Connection to instruction memory
    output [15:0] pc_out,
    input [15:0] instr
);

    // Internal wires
    wire [15:0] read_data1, read_data2;
    wire [15:0] write_data;
    wire [15:0] alu_b_input;
    wire [15:0] alu_result;
    wire [15:0] mem_data;

    // ────────────────
    // Register File
    // ────────────────
    register_file RF (
        .clk(clk),
        .wr_en(reg_write),
        .rd_addr1(instr[11:9]),   // rs
        .rd_addr2(instr[8:6]),    // rt
        .wr_addr(instr[5:3]),     // rd
        .wr_data(write_data),
        .rd_data1(read_data1),
        .rd_data2(read_data2)
    );

    // ────────────────
    // ALU Input MUX
    // ────────────────
    assign alu_b_input = (alu_src) ? {10'b0, instr[5:0]} : read_data2;

    // ────────────────
    // ALU
    // ────────────────
    alu #(.WIDTH(16)) ALU_U (
        .a(read_data1),
        .b(alu_b_input),
        .alu_ctrl(alu_ctrl),
        .alu_out(alu_result),
        .zero(zero)
    );

    // ────────────────
    // Data Memory
    // ────────────────
    data_mem DMEM (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .address(alu_result),
        .write_data(read_data2),
        .read_data(mem_data)
    );

    // ────────────────
    // Write Back MUX
    // ────────────────
    assign write_data = (mem_read) ? mem_data : alu_result;

    // ────────────────
    // PC (Program Counter)
    // ────────────────
    reg [15:0] pc_reg;
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_reg <= 16'b0;
        else
            pc_reg <= pc_reg + 16'd2;  // increment by instruction size (2 bytes)
    end

    assign pc_out = pc_reg;

endmodule
