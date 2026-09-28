`timescale 1ns / 1ps

module control_unit (

    input  wire [2:0] opcode,
    input  wire [2:0] funct,

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
    output reg [3:0]  fpu_opcode,

    // ==========================================================
    // CRYPTO CONTROL
    // ==========================================================
    output reg        crypto_enable,
    output reg        crypto_dec

);

    // ==========================================================
    // ALU OP
    //
    // 00 = ADD
    // 01 = SUB
    // 10 = Decode funct
    // ==========================================================

    reg [1:0] alu_op;

    // ==========================================================
    // MAIN CONTROL
    // ==========================================================

    always @(*) begin

        // ------------------------------------------------------
        // Default values
        // ------------------------------------------------------

        reg_write    = 1'b0;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        alu_src      = 1'b0;

        branch       = 1'b0;
        branch_type  = 2'b00;

        jump         = 1'b0;
        jalr         = 1'b0;

        alu_op       = 2'b00;

        fpu_enable   = 1'b0;
        fpu_opcode   = 4'b0000;

        // Crypto defaults
        crypto_enable = 1'b0;
        crypto_dec    = 1'b0;

        // ======================================================
        // OPCODE DECODE
        // ======================================================

        case (opcode)

            // --------------------------------------------------
            // R-TYPE
            // 000
            // --------------------------------------------------

            3'b000: begin

                reg_write = 1'b1;
                alu_src   = 1'b0;
                alu_op    = 2'b10;

            end

            // --------------------------------------------------
            // LH
            // 001
            // --------------------------------------------------

            3'b001: begin

                reg_write = 1'b1;
                mem_read  = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b00;

            end

            // --------------------------------------------------
            // SH
            // 010
            // --------------------------------------------------

            3'b010: begin

                reg_write = 1'b0;
                mem_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b00;

            end

            // --------------------------------------------------
            // IMMEDIATE
            // 011
            // --------------------------------------------------

            3'b011: begin

                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b10;

            end

            // --------------------------------------------------
            // BRANCH
            // 100
            //
            // funct 000 = BEQ
            // funct 001 = BNE
            // funct 100 = BLT
            // funct 011 = BGE
            // --------------------------------------------------

            3'b100: begin

                reg_write = 1'b0;
                branch    = 1'b1;
                alu_src   = 1'b0;
                alu_op     = 2'b01;

                case (funct)

                    // BEQ
                    3'b000: begin
                        branch_type = 2'b00;
                    end

                    // BNE
                    3'b001: begin
                        branch_type = 2'b01;
                    end

                    // BLT
                    3'b100: begin
                        branch_type = 2'b10;
                    end

                    // BGE
                    3'b011: begin
                        branch_type = 2'b11;
                    end

                    default: begin
                        branch_type = 2'b00;
                    end

                endcase

            end

            // --------------------------------------------------
            // JAL
            // 101
            // --------------------------------------------------

            3'b101: begin

                reg_write = 1'b1;
                jump      = 1'b1;
                jalr      = 1'b0;

            end

            // --------------------------------------------------
            // FPU / CRYPTO
            // 110
            //
            // FPU:
            // funct 000 = FADD
            // funct 001 = FMUL
            //
            // CRYPTO:
            // funct 010 = ENC
            // funct 011 = DEC
            // --------------------------------------------------

            3'b110: begin

                case (funct)

                    // --------------------------------------------------
                    // FADD
                    // --------------------------------------------------

                    3'b000: begin

                        reg_write  = 1'b1;
                        fpu_enable = 1'b1;
                        fpu_opcode = 4'b0000;

                    end

                    // --------------------------------------------------
                    // FMUL
                    // --------------------------------------------------

                    3'b001: begin

                        reg_write  = 1'b1;
                        fpu_enable = 1'b1;
                        fpu_opcode = 4'b0001;

                    end

                    // --------------------------------------------------
                    // ENC
                    // --------------------------------------------------

                    3'b010: begin

                        reg_write     = 1'b1;
                        crypto_enable = 1'b1;
                        crypto_dec    = 1'b0;

                    end

                    // --------------------------------------------------
                    // DEC
                    // --------------------------------------------------

                    3'b011: begin

                        reg_write     = 1'b1;
                        crypto_enable = 1'b1;
                        crypto_dec    = 1'b1;

                    end

                    // --------------------------------------------------
                    // Invalid FPU / Crypto funct
                    // --------------------------------------------------

                    default: begin

                        reg_write     = 1'b0;
                        fpu_enable    = 1'b0;
                        fpu_opcode    = 4'b0000;

                        crypto_enable = 1'b0;
                        crypto_dec    = 1'b0;

                    end

                endcase

            end

            // --------------------------------------------------
            // JALR
            // 111
            // --------------------------------------------------

            3'b111: begin

                reg_write = 1'b1;
                jump      = 1'b1;
                jalr      = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b00;

            end

            // --------------------------------------------------
            // DEFAULT / NOP
            // --------------------------------------------------

            default: begin

                reg_write    = 1'b0;
                mem_read     = 1'b0;
                mem_write    = 1'b0;
                alu_src      = 1'b0;

                branch       = 1'b0;
                branch_type  = 2'b00;

                jump         = 1'b0;
                jalr         = 1'b0;

                alu_op       = 2'b00;

                fpu_enable   = 1'b0;
                fpu_opcode   = 4'b0000;

                crypto_enable = 1'b0;
                crypto_dec    = 1'b0;

            end

        endcase

    end

    // ==========================================================
    // ALU DECODER
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

            // --------------------------------------------------
            // ADD
            // --------------------------------------------------

            2'b00: begin

                alu_ctrl = 4'b0000;

            end

            // --------------------------------------------------
            // SUB
            // --------------------------------------------------

            2'b01: begin

                alu_ctrl = 4'b0001;

            end

            // --------------------------------------------------
            // FUNCT DECODE
            // --------------------------------------------------

            2'b10: begin

                case (funct)

                    // ADD
                    3'b000: begin
                        alu_ctrl = 4'b0000;
                    end

                    // SUB
                    3'b001: begin
                        alu_ctrl = 4'b0001;
                    end

                    // SLT
                    3'b010: begin
                        alu_ctrl = 4'b1000;
                    end

                    // SRL
                    3'b011: begin
                        alu_ctrl = 4'b0110;
                    end

                    // OR
                    3'b100: begin
                        alu_ctrl = 4'b0011;
                    end

                    // SLL
                    3'b101: begin
                        alu_ctrl = 4'b0101;
                    end

                    // AND
                    3'b110: begin
                        alu_ctrl = 4'b0010;
                    end

                    // SRA
                    3'b111: begin
                        alu_ctrl = 4'b0111;
                    end

                    default: begin
                        alu_ctrl = 4'b0000;
                    end

                endcase

            end

            default: begin

                alu_ctrl = 4'b0000;

            end

        endcase

    end

endmodule
