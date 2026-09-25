`timescale 1ns / 1ps
//======================================================================
// 16-bit Pipelined RISC Core
//---------------------------------------------------------------------
// Pipeline stages: IF | ID | EX | MEM | WB
// Compatible with the provided ALU, FPU, Control Unit, Register File,
// and Memory modules.
//======================================================================

module pipelined_core(
    input  clk,
    input  rst
);

    //------------------------------------------------------------
    // IF Stage: Instruction Fetch
    //------------------------------------------------------------
    wire [15:0] pc_current;
    wire [15:0] pc_next;
    wire [15:0] instruction;

    // Program Counter
    pc pc_inst (
        .clk(clk),
        .rst(rst),
        .pc_in(pc_next),
        .pc_out(pc_current)
    );

    // Instruction Memory
    instr_mem instr_mem_inst (
        .instr_addr(pc_current),
        .instr(instruction)
    );

    // Next PC = PC + 1
    assign pc_next = pc_current + 16'd1;

    //------------------------------------------------------------
    // IF/ID Pipeline Register
    //------------------------------------------------------------
    reg [15:0] ifid_pc;
    reg [15:0] ifid_instr;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ifid_pc    <= 16'h0000;
            ifid_instr <= 16'h0000;
        end else begin
            ifid_pc    <= pc_current;
            ifid_instr <= instruction;
        end
    end

    //------------------------------------------------------------
    // ID Stage: Instruction Decode
    //------------------------------------------------------------
    wire [3:0] opcode = ifid_instr[15:12];
    wire [2:0] rd     = ifid_instr[11:9];
    wire [2:0] rs1    = ifid_instr[8:6];
    wire [2:0] rs2    = ifid_instr[5:3];
    wire [2:0] funct  = ifid_instr[2:0];
    wire [15:0] imm;

    // Immediate Generator
    immgen immgen_inst (
        .instr(ifid_instr),
        .imm_out(imm)
    );

    // Control Unit
    wire reg_write_en;
    wire mem_read_en;
    wire mem_write_en;
    wire alu_src_sel;
    wire branch_en;
    wire jump_en;
    wire [3:0] alu_ctrl_sig;
    wire fpu_enable_sig;
    wire [3:0] fpu_op_sig;

    control_unit control_inst (
        .opcode(opcode),
        .funct(funct),
        .reg_write(reg_write_en),
        .mem_read(mem_read_en),
        .mem_write(mem_write_en),
        .alu_src(alu_src_sel),
        .branch(branch_en),
        .jump(jump_en),
        .alu_ctrl(alu_ctrl_sig),
        .fpu_enable(fpu_enable_sig),
        .fpu_opcode(fpu_op_sig)
    );

    // Register File
    wire [15:0] reg_data1;
    wire [15:0] reg_data2;
    wire [15:0] wb_write_data;
    wire [2:0]  wb_write_addr;
    wire        wb_reg_write_en;

    regfile regfile_inst (
        .clk(clk),
        .wr_en(wb_reg_write_en),
        .rd_addr1(rs1),
        .rd_addr2(rs2),
        .wr_addr(wb_write_addr),
        .wr_data(wb_write_data),
        .rd_data1(reg_data1),
        .rd_data2(reg_data2)
    );

    //------------------------------------------------------------
    // ID/EX Pipeline Register
    //------------------------------------------------------------
    reg [15:0] idex_pc;
    reg [15:0] idex_rd_data1;
    reg [15:0] idex_rd_data2;
    reg [15:0] idex_imm;
    reg [2:0]  idex_rd;
    reg [3:0]  idex_alu_ctrl;
    reg        idex_reg_write;
    reg        idex_mem_read;
    reg        idex_mem_write;
    reg        idex_alu_src;
    reg        idex_branch;
    reg        idex_jump;
    reg        idex_fpu_enable;
    reg [3:0]  idex_fpu_op;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            idex_pc          <= 16'h0000;
            idex_rd_data1    <= 16'h0000;
            idex_rd_data2    <= 16'h0000;
            idex_imm         <= 16'h0000;
            idex_rd          <= 3'b000;
            idex_alu_ctrl    <= 4'b0000;
            idex_reg_write   <= 1'b0;
            idex_mem_read    <= 1'b0;
            idex_mem_write   <= 1'b0;
            idex_alu_src     <= 1'b0;
            idex_branch      <= 1'b0;
            idex_jump        <= 1'b0;
            idex_fpu_enable  <= 1'b0;
            idex_fpu_op      <= 4'b0000;
        end else begin
            idex_pc          <= ifid_pc;
            idex_rd_data1    <= reg_data1;
            idex_rd_data2    <= reg_data2;
            idex_imm         <= imm;
            idex_rd          <= rd;
            idex_alu_ctrl    <= alu_ctrl_sig;
            idex_reg_write   <= reg_write_en;
            idex_mem_read    <= mem_read_en;
            idex_mem_write   <= mem_write_en;
            idex_alu_src     <= alu_src_sel;
            idex_branch      <= branch_en;
            idex_jump        <= jump_en;
            idex_fpu_enable  <= fpu_enable_sig;
            idex_fpu_op      <= fpu_op_sig;
        end
    end

    //------------------------------------------------------------
    // EX Stage: ALU + FPU
    //------------------------------------------------------------
    wire [15:0] ex_alu_src1 = idex_rd_data1;
    wire [15:0] ex_alu_src2 = (idex_alu_src) ? idex_imm : idex_rd_data2;
    wire [15:0] ex_alu_result;
    wire        ex_alu_zero;

    // Integer ALU
    alu alu_inst (
        .a(ex_alu_src1),
        .b(ex_alu_src2),
        .alu_ctrl(idex_alu_ctrl),
        .alu_out(ex_alu_result),
        .zero(ex_alu_zero)
    );

    // Floating-Point Unit
    wire [15:0] ex_fpu_result;
    wire        ex_fpu_ready;
    wire        ex_invalid_op;

    fpu fpu_inst (
        .clk(clk),
        .rst(rst),
        .fpu_enable(idex_fpu_enable),
        .fpu_op(idex_fpu_op),
        .operand_a(ex_alu_src1),
        .operand_b(ex_alu_src2),
        .fpu_result(ex_fpu_result),
        .fpu_ready(ex_fpu_ready),
        .invalid_op(ex_invalid_op)
    );

    // Result Selection: Integer or FPU
    wire [15:0] ex_result = idex_fpu_enable ? ex_fpu_result : ex_alu_result;

    //------------------------------------------------------------
    // EX/MEM Pipeline Register
    //------------------------------------------------------------
    reg [15:0] exmem_result;
    reg [15:0] exmem_rd_data2;
    reg [2:0]  exmem_rd;
    reg        exmem_reg_write;
    reg        exmem_mem_read;
    reg        exmem_mem_write;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            exmem_result    <= 16'h0000;
            exmem_rd_data2  <= 16'h0000;
            exmem_rd        <= 3'b000;
            exmem_reg_write <= 1'b0;
            exmem_mem_read  <= 1'b0;
            exmem_mem_write <= 1'b0;
        end else begin
            exmem_result    <= ex_result;
            exmem_rd_data2  <= idex_rd_data2;
            exmem_rd        <= idex_rd;
            exmem_reg_write <= idex_reg_write;
            exmem_mem_read  <= idex_mem_read;
            exmem_mem_write <= idex_mem_write;
        end
    end

    //------------------------------------------------------------
    // MEM Stage: Data Memory
    //------------------------------------------------------------
    wire [15:0] mem_read_data;

    data_mem data_mem_inst (
        .clk(clk),
        .mem_read(exmem_mem_read),
        .mem_write(exmem_mem_write),
        .address(exmem_result),
        .write_data(exmem_rd_data2),
        .read_data(mem_read_data)
    );

    //------------------------------------------------------------
    // MEM/WB Pipeline Register
    //------------------------------------------------------------
    reg [15:0] memwb_read_data;
    reg [15:0] memwb_result;
    reg [2:0]  memwb_rd;
    reg        memwb_reg_write;
    reg        memwb_mem_to_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            memwb_read_data  <= 16'h0000;
            memwb_result     <= 16'h0000;
            memwb_rd         <= 3'b000;
            memwb_reg_write  <= 1'b0;
            memwb_mem_to_reg <= 1'b0;
        end else begin
            memwb_read_data  <= mem_read_data;
            memwb_result     <= exmem_result;
            memwb_rd         <= exmem_rd;
            memwb_reg_write  <= exmem_reg_write;
            memwb_mem_to_reg <= exmem_mem_read;
        end
    end

    //------------------------------------------------------------
    // WB Stage: Write-Back
    //------------------------------------------------------------
    assign wb_write_data   = (memwb_mem_to_reg) ? memwb_read_data : memwb_result;
    assign wb_write_addr   = memwb_rd;
    assign wb_reg_write_en = memwb_reg_write;

endmodule
