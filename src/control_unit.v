`timescale 1ns / 1ps

module control_unit (
    input  wire [2:0] opcode,       // instr[14:12]
    input  wire [2:0] funct,        // instr[2:0]

    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        alu_src,

    output reg        branch,
    output reg [1:0]  branch_type,

    output reg        jump,
    output reg        jalr,

    output wire [3:0] alu_ctrl,

    output reg        fpu_enable,
    output reg [3:0]  fpu_opcode
);

    // ==========================================================
    // ALU operation type
    //
    // 00 = ADD
    // 01 = SUB
    // 10 = Decode funct
    // ==========================================================

    reg [1:0] alu_op;


    // ==========================================================
    // Main Control Unit
    // ==========================================================

    always @(*) begin

        // ------------------------------------------------------
        // Default control values
        // ------------------------------------------------------

        reg_write   = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        alu_src     = 1'b0;

        branch      = 1'b0;
        branch_type = 2'b00;

        jump        = 1'b0;
        jalr        = 1'b0;

        alu_op      = 2'b00;

        fpu_enable  = 1'b0;
        fpu_opcode  = 4'b0000;


        // ======================================================
        // Instruction Decode
        // ======================================================

        case (opcode)

            // ==================================================
            // R-TYPE
            //
            // opcode = 000
            //
            // ADD
            // SUB
            // SLT
            // SRL
            // SLL
            // SRA
            // OR
            // AND
            // ==================================================

            3'b000: begin

                reg_write = 1'b1;

                // ALU uses register operands
                alu_src = 1'b0;

                // ALU operation determined by funct
                alu_op = 2'b10;

            end


            // ==================================================
            // LOAD HALFWORD
            //
            // opcode = 001
            // funct  = 010
            //
            // LH Rd, imm(Rs1)
            // ==================================================

            3'b001: begin

                reg_write = 1'b1;

                mem_read = 1'b1;

                // ALU calculates address:
                // Rs1 + immediate
                alu_src = 1'b1;

                alu_op = 2'b00;

            end


            // ==================================================
            // STORE HALFWORD
            //
            // opcode = 010
            // funct  = 010
            //
            // SH Rs2, imm(Rs1)
            // ==================================================

            3'b010: begin

                reg_write = 1'b0;

                mem_write = 1'b1;

                // ALU calculates address:
                // Rs1 + immediate
                alu_src = 1'b1;

                alu_op = 2'b00;

            end


            // ==================================================
            // IMMEDIATE TYPE
            //
            // opcode = 011
            //
            // ADDI
            // SUBI
            // SLTI
            // SRLI
            // SLLI
            // SRAI
            // ORI
            // ANDI
            // ==================================================

            3'b011: begin

                reg_write = 1'b1;

                // ALU second operand = immediate
                alu_src = 1'b1;

                // Operation determined by funct
                alu_op = 2'b10;

            end


            // ==================================================
            // BRANCH
            //
            // opcode = 100
            //
            // funct = 000 -> BEQ
            // funct = 001 -> BNE
            // funct = 100 -> BLT
            // funct = 011 -> BGE
            // ==================================================

            3'b100: begin

                reg_write = 1'b0;

                branch = 1'b1;

                // Branch compares two registers
                alu_src = 1'b0;

                // ALU can perform subtraction for comparison
                alu_op = 2'b01;

                case (funct)

                    // ------------------------------------------
                    // BEQ
                    // ------------------------------------------
                    3'b000: begin
                        branch_type = 2'b00;
                    end

                    // ------------------------------------------
                    // BNE
                    // ------------------------------------------
                    3'b001: begin
                        branch_type = 2'b01;
                    end

                    // ------------------------------------------
                    // BLT
                    // ------------------------------------------
                    3'b100: begin
                        branch_type = 2'b10;
                    end

                    // ------------------------------------------
                    // BGE
                    // ------------------------------------------
                    3'b011: begin
                        branch_type = 2'b11;
                    end

                    default: begin
                        branch_type = 2'b00;
                    end

                endcase

            end


            // ==================================================
            // JUMP AND LINK
            //
            // opcode = 101
            //
            // JAL Rd, offset
            // ==================================================

            3'b101: begin

                reg_write = 1'b1;

                jump = 1'b1;

                jalr = 1'b0;

            end


            // ==================================================
            // FPU
            //
            // opcode = 110
            //
            // funct = 000 -> FADD
            // funct = 001 -> FMUL
            //
            // Internal FPU opcode:
            //
            // 0000 -> FADD
            // 0001 -> FMUL
            // ==================================================
            3'b110: begin
        fpu_enable = 1'b1;
        reg_write  = 1'b1;

        case (funct)
            3'b000: begin
                fpu_opcode = 4'b0000;
            end

            3'b001: begin
                fpu_opcode = 4'b0001;
            end

            default: begin
                fpu_opcode = 4'b0000;
            end
        endcase
    end


            // ==================================================
            // JUMP AND LINK REGISTER
            //
            // opcode = 111
            //
            // JALR Rd, Rs1, imm
            // ==================================================

            3'b111: begin

                reg_write = 1'b1;

                jump = 1'b1;

                jalr = 1'b1;

                // Target address:
                // Rs1 + immediate
                alu_src = 1'b1;

                alu_op = 2'b00;

            end


            // ==================================================
            // DEFAULT / NOP
            // ==================================================

            default: begin

                reg_write   = 1'b0;
                mem_read    = 1'b0;
                mem_write   = 1'b0;
                alu_src     = 1'b0;

                branch      = 1'b0;
                branch_type = 2'b00;

                jump        = 1'b0;
                jalr        = 1'b0;

                alu_op      = 2'b00;

                fpu_enable  = 1'b0;
                fpu_opcode  = 4'b0000;

            end

        endcase

    end


    // ==========================================================
    // ALU Decoder
    // ==========================================================

    alu_decoder ALU_DECODER (
        .alu_op   (alu_op),
        .funct    (funct),
        .alu_ctrl (alu_ctrl)
    );

endmodule



// ============================================================
// ALU DECODER
// ============================================================

module alu_decoder (
    input  wire [1:0] alu_op,
    input  wire [2:0] funct,

    output reg [3:0] alu_ctrl
);

    always @(*) begin

        case (alu_op)

            // ==================================================
            // ADD
            //
            // Used for:
            // LH address
            // SH address
            // JALR target
            // ==================================================

            2'b00: begin
                alu_ctrl = 4'b0000;
            end


            // ==================================================
            // SUB
            //
            // Used for branch comparison
            // ==================================================

            2'b01: begin
                alu_ctrl = 4'b0001;
            end


            // ==================================================
            // Decode funct
            //
            // Used for R-type and immediate instructions
            // ==================================================

            2'b10: begin

                case (funct)

                    // ADD / ADDI
                    3'b000: begin
                        alu_ctrl = 4'b0000;
                    end

                    // SUB / SUBI
                    3'b001: begin
                        alu_ctrl = 4'b0001;
                    end

                    // SLT / SLTI
                    3'b010: begin
                        alu_ctrl = 4'b1000;
                    end

                    // SRL / SRLI
                    3'b011: begin
                        alu_ctrl = 4'b0110;
                    end

                    // OR / ORI
                    3'b100: begin
                        alu_ctrl = 4'b0011;
                    end

                    // SLL / SLLI
                    3'b101: begin
                        alu_ctrl = 4'b0101;
                    end

                    // AND / ANDI
                    3'b110: begin
                        alu_ctrl = 4'b0010;
                    end

                    // SRA / SRAI
                    3'b111: begin
                        alu_ctrl = 4'b0111;
                    end

                    default: begin
                        alu_ctrl = 4'b0000;
                    end

                endcase

            end


            // ==================================================
            // Default
            // ==================================================

            default: begin
                alu_ctrl = 4'b0000;
            end

        endcase

    end

endmodule
