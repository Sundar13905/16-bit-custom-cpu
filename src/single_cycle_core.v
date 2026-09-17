`timescale 1ns / 1ps


module single_cycle_core (
    input clk,          // system clock
    input rst           // asynchronous reset
);


    wire [15:0] instr;           // Current instruction
    wire [15:0] pc_out;          // Current PC
    wire [15:0] branch_addr;     // Calculated branch target (from immgen)
    wire [15:0] next_pc;         // Next PC value (internal)

    wire reg_write;
    wire mem_read;
    wire mem_write;
    wire alu_src;
    wire branch;
    wire jump;
    wire [3:0] alu_ctrl;
    wire fpu_enable;
    wire [3:0] fpu_opcode;

    
    wire [15:0] rd_data1, rd_data2;
    wire [15:0] alu_b_input;
    wire [15:0] alu_out;
    wire [15:0] mem_data;
    wire [15:0] imm_out;
    wire [15:0] write_data;
    wire [15:0] fpu_result;
    wire zero_flag;


    // -------------------------
    // Program Counter (PC)
    // -------------------------
    pc PC_U (
        .clk(clk),
        .reset(rst),
        .branch(branch),
        .jump(jump),
        .branch_addr(imm_out),
        .pc_out(pc_out)
    );


    // Instruction Memory

    instr_mem IMEM (
        .instr_addr(pc_out),
        .instr(instr)
    );


    // Control Unit

    control_unit CTRL (
        .opcode(instr[15:12]),
        .funct(instr[2:0]),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .branch(branch),
        .jump(jump),
        .alu_ctrl(alu_ctrl),
        .fpu_enable(fpu_enable),
        .fpu_opcode(fpu_opcode)
    );

    // -------------------------
    // Register File
    // -------------------------
    register_file RF (
        .clk(clk),
        .wr_en(reg_write),
        .rd_addr1(instr[11:9]),
        .rd_addr2(instr[8:6]),
        .wr_addr(instr[5:3]),
        .wr_data(write_data),
        .rd_data1(rd_data1),
        .rd_data2(rd_data2)
    );

    // -------------------------
    // Immediate Generator
    // -------------------------
    immgen IMMGEN (
        .instr(instr),
        .imm_out(imm_out)
    );

    // -------------------------
    // ALU Input MUX
    // -------------------------
    assign alu_b_input = (alu_src) ? imm_out : rd_data2;

    // -------------------------
    // Integer ALU
    // -------------------------
    alu ALU (
        .a(rd_data1),
        .b(alu_b_input),
        .alu_ctrl(alu_ctrl),
        .alu_out(alu_out),
        .zero(zero_flag)
    );

    // -------------------------
    // Floating Point Unit (FPU)
    // -------------------------
    fpu FPU (
        .enable(fpu_enable),
        .a(rd_data1),
        .b(rd_data2),
        .opcode(fpu_opcode),
        .result(fpu_result)
    );

    // -------------------------
    // Data Memory
    // -------------------------
    data_mem DMEM (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .address(alu_out),
        .write_data(rd_data2),
        .read_data(mem_data)
    );

    // -------------------------
    // Write-back MUX
    // -------------------------
    assign write_data = (fpu_enable) ? fpu_result :
                        (mem_read)   ? mem_data   :
                                       alu_out;

    // =================================================================
    // END OF MODULE CONNECTIONS
    // =================================================================

endmodule
