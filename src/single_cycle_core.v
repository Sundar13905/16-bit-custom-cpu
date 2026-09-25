`timescale 1ns / 1ps

module single_cycle_core (

    input wire clk,
    input wire rst

);

    // ==========================================================
    // Instruction / PC
    // ==========================================================

    wire [15:0] instr;
    wire [15:0] pc_out;
    wire [15:0] next_pc;


    // ==========================================================
    // Instruction fields
    // ==========================================================

    wire [2:0] opcode;
    wire [2:0] funct;

    assign opcode = instr[14:12];
    assign funct  = instr[2:0];


    // ==========================================================
    // Register addresses
    // ==========================================================

    wire [2:0] rf_read_addr1;
    wire [2:0] rf_read_addr2;
    wire [2:0] rf_write_addr;


    /*
        R-type
        Rd  = [11:9]
        Rs1 = [8:6]
        Rs2 = [5:3]

        I-type
        Rd  = [11:9]
        Rs1 = [8:6]

        LH
        Rd  = [11:9]
        Rs1 = [8:6]

        SH
        Rs2 = [11:9]
        Rs1 = [8:6]

        Branch
        Rs1 = [11:9]
        Rs2 = [8:6]

        JAL
        Rd = [11:9]

        JALR
        Rd  = [11:9]
        Rs1 = [8:6]
    */


    assign rf_read_addr1 =
        instr[14:12] == 3'b000 ? instr[8:6] :
        instr[14:12] == 3'b001 ? instr[8:6] :
        instr[14:12] == 3'b010 ? instr[8:6] :
        instr[14:12] == 3'b011 ? instr[8:6] :
        instr[14:12] == 3'b100 ? instr[11:9] :
        instr[14:12] == 3'b110 ? instr[8:6] :
        instr[14:12] == 3'b111 ? instr[8:6] :
                                  3'b000;
        


    assign rf_read_addr2 =    instr[14:12] == 3'b000 ? instr[5:3]  :   // R-type: Rs2
    instr[14:12] == 3'b010 ? instr[11:9] :   // SH: data register
    instr[14:12] == 3'b100 ? instr[8:6]  :   // Branch: Rs2
    instr[14:12] == 3'b110 ? instr[5:3]  :   // FPU: Rs2
                              3'b000;


    assign rf_write_addr =
        instr[14:12] == 3'b000 ? instr[11:9] :
        instr[14:12] == 3'b001 ? instr[11:9] :
        instr[14:12] == 3'b011 ? instr[11:9] :
        instr[14:12] == 3'b101 ? instr[11:9] :
        instr[14:12] == 3'b110 ? instr[11:9] :
        instr[14:12] == 3'b111 ? instr[11:9] :
                                  3'b000;


    // ==========================================================
    // Control signals
    // ==========================================================

    wire        reg_write;
    wire        mem_read;
    wire        mem_write;
    wire        alu_src;

    wire        branch;
    wire [1:0]  branch_type;

    wire        jump;
    wire        jalr;

    wire [3:0]  alu_ctrl;

    wire        fpu_enable;
    wire [3:0]  fpu_opcode;


    // ==========================================================
    // Datapath signals
    // ==========================================================

    wire [15:0] rd_data1;
    wire [15:0] rd_data2;

    wire [15:0] alu_b_input;
    wire [15:0] alu_out;

    wire [15:0] imm_out;

    wire [15:0] mem_data;

    wire [15:0] fpu_result;

    wire [15:0] write_data;

    wire        zero_flag;


    // ==========================================================
    // Program Counter
    // ==========================================================

    pc PC_U (

        .clk    (clk),
        .rst    (rst),

        .pc_in  (next_pc),

        .pc_out (pc_out)

    );


    // ==========================================================
    // Instruction Memory
    // ==========================================================

    instr_mem IMEM (

        .instr_addr (pc_out),
        .instr      (instr)

    );


    // ==========================================================
    // Control Unit
    // ==========================================================

    control_unit CTRL (

        .opcode      (opcode),
        .funct       (funct),

        .reg_write   (reg_write),
        .mem_read    (mem_read),
        .mem_write   (mem_write),
        .alu_src     (alu_src),

        .branch      (branch),
        .branch_type (branch_type),

        .jump        (jump),
        .jalr        (jalr),

        .alu_ctrl    (alu_ctrl),

        .fpu_enable  (fpu_enable),
        .fpu_opcode  (fpu_opcode)

    );


    // ==========================================================
    // Register File
    // ==========================================================

    regfile RF (

        .clk        (clk),
        .reg_write  (reg_write),

        .read_reg1  (rf_read_addr1),
        .read_reg2  (rf_read_addr2),

        .write_reg  (rf_write_addr),
        .write_data (write_data),

        .read_data1 (rd_data1),
        .read_data2 (rd_data2)

    );


    // ==========================================================
    // Immediate Generator
    // ==========================================================

    immgen IMMGEN (

        .instr   (instr),
        .imm_out (imm_out)

    );


    // ==========================================================
    // ALU input selection
    // ==========================================================

    assign alu_b_input =
        alu_src ? imm_out : rd_data2;


    // ==========================================================
    // ALU
    // ==========================================================

    alu ALU (

        .a        (rd_data1),
        .b        (alu_b_input),

        .alu_ctrl (alu_ctrl),

        .alu_out  (alu_out),
        .zero     (zero_flag)

    );


    // ==========================================================
    // FPU
    // ==========================================================

    fpu FPU (

        .enable  (fpu_enable),

        .a       (rd_data1),
        .b       (rd_data2),

        .opcode  (fpu_opcode),

        .result  (fpu_result)

    );


    // ==========================================================
    // Data Memory
    // ==========================================================

    data_mem DMEM (

        .clk       (clk),

        .mem_read  (mem_read),
        .mem_write (mem_write),

        .address   (alu_out),

        .write_data(rd_data2),

        .read_data (mem_data)

    );


    // ==========================================================
    // Branch condition
    // ==========================================================

    reg branch_taken;

    always @(*) begin

        branch_taken = 1'b0;

        if (branch) begin

            case (branch_type)

                // BEQ
                2'b00: begin
                    branch_taken = (rd_data1 == rd_data2);
                end

                // BNE
                2'b01: begin
                    branch_taken = (rd_data1 != rd_data2);
                end

                // BLT
                2'b10: begin
                    branch_taken =
                        ($signed(rd_data1) < $signed(rd_data2));
                end

                // BGE
                2'b11: begin
                    branch_taken =
                        ($signed(rd_data1) >= $signed(rd_data2));
                end

                default:
                    branch_taken = 1'b0;

            endcase

        end

    end


    // ==========================================================
    // Next PC
    // ==========================================================

    reg [15:0] next_pc_reg;

    always @(*) begin

        // Normal sequential execution
        next_pc_reg = pc_out + 16'd1;

        // Branch
        if (branch_taken)
            next_pc_reg = pc_out + imm_out;

        // JAL
        if (jump && !jalr)
            next_pc_reg = pc_out + imm_out;

        // JALR
        if (jalr)
            next_pc_reg = rd_data1 + imm_out;

    end

    assign next_pc = next_pc_reg;


    // ==========================================================
    // Write-back
    // ==========================================================

    assign write_data =
        fpu_enable ? fpu_result :
        mem_read   ? mem_data   :
        (jump ? (pc_out + 16'd1) : alu_out);


endmodule
