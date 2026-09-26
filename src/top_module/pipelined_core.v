`timescale 1ns / 1ps

module pipelined_core (
    input wire clk,
    input wire rst
);

    // ==========================================================
    // HAZARD CONTROL
    // ==========================================================

    wire hazard_pc_stall;
    wire hazard_if_id_stall;
    wire hazard_id_ex_flush;

    // ==========================================================
    // PC / IF STAGE
    // ==========================================================

    wire [15:0] pc_out;
    wire [15:0] next_pc;
    wire [15:0] instr;

    // ==========================================================
    // CONTROL-FLOW SIGNALS
    // ==========================================================

    wire ex_branch_taken;
    wire [15:0] ex_branch_target;

    wire ex_jump_taken;
    wire [15:0] ex_jump_target;

    wire ex_control_taken;

    // ==========================================================
    // NEXT PC
    // ==========================================================

    assign next_pc =
        hazard_pc_stall ?
            pc_out :
        ex_branch_taken ?
            ex_branch_target :
        ex_jump_taken ?
            ex_jump_target :
            pc_out + 16'd1;

    pc PC_U (
        .clk    (clk),
        .rst    (rst),
        .pc_in  (next_pc),
        .pc_out (pc_out)
    );

    instr_mem IMEM (
        .instr_addr (pc_out),
        .instr      (instr)
    );


    // ==========================================================
    // IF/ID PIPELINE REGISTER
    // ==========================================================

    wire [15:0] if_id_pc;
    wire [15:0] if_id_pc_plus1;
    wire [15:0] if_id_instr;

    if_id_reg IF_ID (
        .clk          (clk),
        .rst_n        (~rst),
        .stall        (hazard_if_id_stall),
        .flush        (ex_control_taken),

        .pc_in        (pc_out),
        .pc_plus1_in  (pc_out + 16'd1),
        .instr_in     (instr),

        .pc_out       (if_id_pc),
        .pc_plus1_out (if_id_pc_plus1),
        .instr_out    (if_id_instr)
    );


    // ==========================================================
    // ID STAGE
    // ==========================================================

    wire [2:0] id_opcode;
    wire [2:0] id_funct;

    assign id_opcode = if_id_instr[14:12];
    assign id_funct  = if_id_instr[2:0];


    // ----------------------------------------------------------
    // Register addresses
    // ----------------------------------------------------------

    wire [2:0] id_rf_read_addr1;
    wire [2:0] id_rf_read_addr2;
    wire [2:0] id_rf_write_addr;

    assign id_rf_read_addr1 =
        id_opcode == 3'b000 ? if_id_instr[8:6]  :   // R-type
        id_opcode == 3'b001 ? if_id_instr[8:6]  :   // LH
        id_opcode == 3'b010 ? if_id_instr[8:6]  :   // SH
        id_opcode == 3'b011 ? if_id_instr[8:6]  :   // I-type
        id_opcode == 3'b100 ? if_id_instr[11:9] :   // Branch
        id_opcode == 3'b110 ? if_id_instr[8:6]  :   // FPU
        id_opcode == 3'b111 ? if_id_instr[8:6]  :   // JALR
                                      3'b000;

    assign id_rf_read_addr2 =
        id_opcode == 3'b000 ? if_id_instr[5:3]  :   // R-type
        id_opcode == 3'b010 ? if_id_instr[11:9] :   // SH
        id_opcode == 3'b100 ? if_id_instr[8:6]  :   // Branch
        id_opcode == 3'b110 ? if_id_instr[5:3]  :   // FPU
                                      3'b000;

    assign id_rf_write_addr =
        id_opcode == 3'b000 ? if_id_instr[11:9] :
        id_opcode == 3'b001 ? if_id_instr[11:9] :
        id_opcode == 3'b011 ? if_id_instr[11:9] :
        id_opcode == 3'b101 ? if_id_instr[11:9] :
        id_opcode == 3'b110 ? if_id_instr[11:9] :
        id_opcode == 3'b111 ? if_id_instr[11:9] :
                                      3'b000;


    // ----------------------------------------------------------
    // Control
    // ----------------------------------------------------------

    wire       id_reg_write;
    wire       id_mem_read;
    wire       id_mem_write;
    wire       id_alu_src;

    wire       id_branch;
    wire [1:0] id_branch_type;

    wire       id_jump;
    wire       id_jalr;

    wire [3:0] id_alu_ctrl;

    wire       id_fpu_enable;
    wire [3:0] id_fpu_opcode;

    wire [1:0] id_wb_select;

    // WB select:
    // 00 = ALU/FPU result
    // 01 = memory data
    // 10 = PC + 1 (JAL/JALR)

    assign id_wb_select =
        id_mem_read ? 2'b01 :
        id_jump     ? 2'b10 :
                      2'b00;


    control_unit CTRL (
        .opcode      (id_opcode),
        .funct       (id_funct),

        .reg_write   (id_reg_write),
        .mem_read    (id_mem_read),
        .mem_write   (id_mem_write),
        .alu_src     (id_alu_src),

        .branch      (id_branch),
        .branch_type (id_branch_type),

        .jump        (id_jump),
        .jalr        (id_jalr),

        .alu_ctrl    (id_alu_ctrl),

        .fpu_enable  (id_fpu_enable),
        .fpu_opcode  (id_fpu_opcode)
    );


    // ----------------------------------------------------------
    // Register File
    // ----------------------------------------------------------

    wire [15:0] id_rd_data1;
    wire [15:0] id_rd_data2;

    wire [15:0] wb_write_data;
    wire        wb_reg_write;

    regfile RF (
        .clk        (clk),
        .rst        (rst),

        .reg_write  (wb_reg_write),

        .read_reg1  (id_rf_read_addr1),
        .read_reg2  (id_rf_read_addr2),

        .write_reg  (mem_wb_rd),
        .write_data (wb_write_data),

        .read_data1 (id_rd_data1),
        .read_data2 (id_rd_data2)
    );


    // ----------------------------------------------------------
    // Immediate Generator
    // ----------------------------------------------------------

    wire [15:0] id_imm;

    immgen IMMGEN (
        .instr   (if_id_instr),
        .imm_out (id_imm)
    );


    // ==========================================================
    // HAZARD UNIT
    // ==========================================================

    hazard_unit HAZARD_UNIT (
        .id_ex_mem_read (id_ex_mem_read),
        .id_ex_rd       (id_ex_rd),

        .if_id_rs1      (id_rf_read_addr1),
        .if_id_rs2      (id_rf_read_addr2),

        .pc_stall       (hazard_pc_stall),
        .if_id_stall    (hazard_if_id_stall),
        .id_ex_flush    (hazard_id_ex_flush)
    );


    // ==========================================================
    // ID/EX PIPELINE REGISTER
    // ==========================================================

    wire [15:0] id_ex_pc;
    wire [15:0] id_ex_pc_plus1;

    wire [15:0] id_ex_rs1_data;
    wire [15:0] id_ex_rs2_data;
    wire [15:0] id_ex_imm;

    wire [2:0] id_ex_rs1;
    wire [2:0] id_ex_rs2;
    wire [2:0] id_ex_rd;

    wire [3:0] id_ex_alu_control;

    wire       id_ex_alu_src;
    wire       id_ex_mem_read;
    wire       id_ex_mem_write;
    wire       id_ex_reg_write;

    wire [1:0] id_ex_wb_select;

    wire       id_ex_branch;
    wire [1:0] id_ex_branch_type;

    wire       id_ex_jump;
    wire       id_ex_jalr;

    wire       id_ex_fpu_enable;
    wire [3:0] id_ex_fpu_opcode;


    id_ex_reg ID_EX (
        .clk             (clk),
        .rst_n           (~rst),

        .flush           (hazard_id_ex_flush || ex_control_taken),

        .pc_in           (if_id_pc),
        .pc_plus1_in     (if_id_pc_plus1),

        .rs1_data_in     (id_rd_data1),
        .rs2_data_in     (id_rd_data2),

        .imm_in          (id_imm),

        .rs1_in          (id_rf_read_addr1),
        .rs2_in          (id_rf_read_addr2),
        .rd_in           (id_rf_write_addr),

        .alu_control_in  (id_alu_ctrl),
        .alu_src_in      (id_alu_src),

        .mem_read_in     (id_mem_read),
        .mem_write_in    (id_mem_write),

        .reg_write_in    (id_reg_write),
        .wb_select_in    (id_wb_select),

        .branch_in       (id_branch),
        .branch_type_in  (id_branch_type),

        .jump_in         (id_jump),
        .jalr_in         (id_jalr),

        .fpu_enable_in   (id_fpu_enable),
        .fpu_opcode_in   (id_fpu_opcode),

        .pc_out          (id_ex_pc),
        .pc_plus1_out    (id_ex_pc_plus1),

        .rs1_data_out    (id_ex_rs1_data),
        .rs2_data_out    (id_ex_rs2_data),

        .imm_out         (id_ex_imm),

        .rs1_out         (id_ex_rs1),
        .rs2_out         (id_ex_rs2),
        .rd_out          (id_ex_rd),

        .alu_control_out (id_ex_alu_control),
        .alu_src_out     (id_ex_alu_src),

        .mem_read_out    (id_ex_mem_read),
        .mem_write_out   (id_ex_mem_write),

        .reg_write_out   (id_ex_reg_write),
        .wb_select_out   (id_ex_wb_select),

        .branch_out      (id_ex_branch),
        .branch_type_out (id_ex_branch_type),

        .jump_out        (id_ex_jump),
        .jalr_out        (id_ex_jalr),

        .fpu_enable_out  (id_ex_fpu_enable),
        .fpu_opcode_out  (id_ex_fpu_opcode)
    );


    // ==========================================================
    // FORWARDING UNIT
    // ==========================================================

    wire [1:0] forward_a;
    wire [1:0] forward_b;

    forwarding_unit FORWARD_UNIT (
        .id_ex_rs1        (id_ex_rs1),
        .id_ex_rs2        (id_ex_rs2),

        .ex_mem_rd        (ex_mem_rd),
        .ex_mem_reg_write (ex_mem_reg_write),

        .mem_wb_rd        (mem_wb_rd),
        .mem_wb_reg_write (mem_wb_reg_write),

        .forward_a        (forward_a),
        .forward_b        (forward_b)
    );


    // ==========================================================
    // EX STAGE
    // ==========================================================

    wire [15:0] ex_forward_a;
    wire [15:0] ex_forward_b;

    wire [15:0] ex_alu_b;
    wire [15:0] ex_alu_out;
    wire        ex_zero;


    // ----------------------------------------------------------
    // Forwarding MUX for operand A
    // ----------------------------------------------------------

    assign ex_forward_a =
        forward_a == 2'b01 ? ex_mem_execution_result :
        forward_a == 2'b10 ? wb_write_data :
                             id_ex_rs1_data;


    // ----------------------------------------------------------
    // Forwarding MUX for operand B
    // ----------------------------------------------------------

    assign ex_forward_b =
        forward_b == 2'b01 ? ex_mem_execution_result :
        forward_b == 2'b10 ? wb_write_data :
                             id_ex_rs2_data;


    // ==========================================================
    // BRANCH DECISION
    // ==========================================================

    assign ex_branch_taken =
        id_ex_branch &&
        (
            (id_ex_branch_type == 2'b00 &&
             (ex_forward_a == ex_forward_b)) ||

            (id_ex_branch_type == 2'b01 &&
             (ex_forward_a != ex_forward_b)) ||

            (id_ex_branch_type == 2'b10 &&
             ($signed(ex_forward_a) < $signed(ex_forward_b))) ||

            (id_ex_branch_type == 2'b11 &&
             ($signed(ex_forward_a) >= $signed(ex_forward_b)))
        );

    assign ex_branch_target =
        id_ex_pc + id_ex_imm;


    // ==========================================================
    // JUMP DECISION
    // ==========================================================

    assign ex_jump_taken =
        id_ex_jump || id_ex_jalr;


    // ----------------------------------------------------------
    // JAL / JALR target
    // ----------------------------------------------------------
    //
    // JAL:
    //     target = PC + immediate
    //
    // JALR:
    //     target = Rs1 + immediate
    //
    // ex_forward_a is used for JALR so that a value produced by
    // a previous instruction can be forwarded into the target
    // calculation.
    // ----------------------------------------------------------

    assign ex_jump_target =
        id_ex_jalr ?
            (ex_forward_a + id_ex_imm) :
            (id_ex_pc + id_ex_imm);


    // ----------------------------------------------------------
    // Unified control-flow decision
    // ----------------------------------------------------------

    assign ex_control_taken =
        ex_branch_taken || ex_jump_taken;


    // ==========================================================
    // ALU OPERAND B SELECTION
    // ==========================================================

    assign ex_alu_b =
        id_ex_alu_src ?
            id_ex_imm :
            ex_forward_b;


    // ==========================================================
    // ALU
    // ==========================================================

    alu ALU (
        .a        (ex_forward_a),
        .b        (ex_alu_b),
        .alu_ctrl (id_ex_alu_control),
        .alu_out  (ex_alu_out),
        .zero     (ex_zero)
    );


    // ==========================================================
    // FPU
    // ==========================================================

    wire [15:0] ex_fpu_result;

    fpu FPU (
        .enable  (id_ex_fpu_enable),
        .a       (ex_forward_a),
        .b       (ex_forward_b),
        .opcode  (id_ex_fpu_opcode),
        .result  (ex_fpu_result)
    );


    // ==========================================================
    // UNIFIED EXECUTION RESULT
    // ==========================================================

    wire [15:0] ex_result;

    assign ex_result =
        id_ex_fpu_enable ?
            ex_fpu_result :
            ex_alu_out;


    // ==========================================================
    // EX/MEM PIPELINE REGISTER
    // ==========================================================

    wire [15:0] ex_mem_execution_result;
    wire [15:0] ex_mem_store_data;
    wire [15:0] ex_mem_pc_plus1;

    wire [2:0] ex_mem_rd;

    wire       ex_mem_mem_read;
    wire       ex_mem_mem_write;
    wire       ex_mem_reg_write;

    wire [1:0] ex_mem_wb_select;


    ex_mem_reg EX_MEM (
        .clk                   (clk),
        .rst_n                 (~rst),

        .execution_result_in   (ex_result),
        .store_data_in         (ex_forward_b),
        .pc_plus1_in           (id_ex_pc_plus1),

        .rd_in                 (id_ex_rd),

        .mem_read_in           (id_ex_mem_read),
        .mem_write_in          (id_ex_mem_write),
        .reg_write_in          (id_ex_reg_write),

        .wb_select_in          (id_ex_wb_select),

        .execution_result_out  (ex_mem_execution_result),
        .store_data_out        (ex_mem_store_data),
        .pc_plus1_out          (ex_mem_pc_plus1),

        .rd_out                (ex_mem_rd),

        .mem_read_out          (ex_mem_mem_read),
        .mem_write_out         (ex_mem_mem_write),
        .reg_write_out         (ex_mem_reg_write),

        .wb_select_out         (ex_mem_wb_select)
    );


    // ==========================================================
    // MEMORY STAGE
    // ==========================================================

    wire [15:0] mem_read_data;

    data_mem DMEM (
        .clk        (clk),

        .mem_read   (ex_mem_mem_read),
        .mem_write  (ex_mem_mem_write),

        .address    (ex_mem_execution_result),
        .write_data (ex_mem_store_data),

        .read_data  (mem_read_data)
    );


    // ==========================================================
    // MEM/WB PIPELINE REGISTER
    // ==========================================================

    wire [15:0] mem_wb_memory_data;
    wire [15:0] mem_wb_execution_result;
    wire [15:0] mem_wb_pc_plus1;

    wire [2:0] mem_wb_rd;

    wire       mem_wb_reg_write;
    wire [1:0] mem_wb_wb_select;


    mem_wb_reg MEM_WB (
        .clk                   (clk),
        .rst_n                 (~rst),

        .memory_data_in        (mem_read_data),
        .execution_result_in   (ex_mem_execution_result),
        .pc_plus1_in           (ex_mem_pc_plus1),

        .rd_in                 (ex_mem_rd),
        .reg_write_in          (ex_mem_reg_write),
        .wb_select_in          (ex_mem_wb_select),

        .memory_data_out       (mem_wb_memory_data),
        .execution_result_out  (mem_wb_execution_result),
        .pc_plus1_out          (mem_wb_pc_plus1),

        .rd_out                (mem_wb_rd),
        .reg_write_out         (mem_wb_reg_write),
        .wb_select_out         (mem_wb_wb_select)
    );


    // ==========================================================
    // WRITEBACK
    // ==========================================================

    assign wb_reg_write =
        mem_wb_reg_write;

    assign wb_write_data =
        mem_wb_wb_select == 2'b01 ? mem_wb_memory_data :
        mem_wb_wb_select == 2'b10 ? mem_wb_pc_plus1 :
                                     mem_wb_execution_result;

endmodule
