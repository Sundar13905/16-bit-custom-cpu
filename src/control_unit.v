`timescale 1ns / 1ps

module control_unit(
    input  [3:0] opcode,       // instr[15:12]
    input  [2:0] funct,        // instr[2:0] for R-type
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        alu_src,
    output reg        branch,
    output reg        jump,
    output [3:0]      alu_ctrl,
    output reg        fpu_enable,
    output reg  [3:0] fpu_opcode
);

    // Internal ALU op field (2 bits)
    reg [1:0] alu_op;

    // Main decode
    always @(*) begin
        // defaults
        reg_write = 0;
        mem_read  = 0;
        mem_write = 0;
        alu_src   = 0;
        branch    = 0;
        jump      = 0;
        alu_op    = 2'b00;
        fpu_enable = 0;
        fpu_opcode = 4'b0000;

        case (opcode)
            // R-type integer operations (use funct)
            4'b0000: begin
                // R-type arithmetic/logic/shift
                reg_write = 1;
                alu_src   = 0;
                alu_op    = 2'b10; // resolve via funct in alu_decoder
            end

            // R-type variant (alternative) (keep reserved)
            4'b0001: begin
                reg_write = 1;
                alu_src   = 0;
                alu_op    = 2'b10;
            end

            // Immediate arithmetic (ADDI)
            4'b0110: begin
                reg_write = 1;
                alu_src   = 1;
                alu_op    = 2'b00; // simple ADD
            end

            // SLTI (set less than immediate)
            4'b0111: begin
                reg_write = 1;
                alu_src   = 1;
                alu_op    = 2'b11; // use ALU decode to produce SLT immediate variant
            end

            // LOAD (LW)
            4'b1000: begin
                reg_write = 1;
                mem_read  = 1;
                alu_src   = 1;
                alu_op    = 2'b00; // ADD for address
            end

            // STORE (SW)
            4'b1001: begin
                mem_write = 1;
                alu_src   = 1;
                alu_op    = 2'b00; // ADD for address
            end

            // BEQ
            4'b1010: begin
                branch = 1;
                alu_op = 2'b01; // SUB for comparison
            end

            // JUMP
            4'b1011: begin
                jump = 1;
            end

            // FPU operations (custom opcode)
            4'b1110: begin
                fpu_enable = 1;
                reg_write  = 1;   // FPU result written back to register
                // maybe decode sub-opcode from funct or lower instr bits
                fpu_opcode = 4'b0000;
            end

            // default: NOP / unknown
            default: begin
                // keep zeros
            end
        endcase
    end

    // ALU decoder: maps alu_op + funct -> alu_ctrl
    alu_decoder alu_dec_inst (
        .alu_op(alu_op),
        .funct(funct),
        .alu_ctrl(alu_ctrl)
    );

endmodule


// ALU decoder module used above
module alu_decoder(
    input  [1:0] alu_op,
    input  [2:0] funct,
    output reg [3:0] alu_ctrl
);

    always @(*) begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0000; // ADD (for immediate, lw/sw)
            2'b01: alu_ctrl = 4'b0001; // SUB (for BEQ)
            2'b11: alu_ctrl = 4'b1000; // SLT for SLTI (immediate)
            2'b10: begin
                // R-type: use funct to select operation
                case (funct)
                    3'b000: alu_ctrl = 4'b0000; // ADD
                    3'b001: alu_ctrl = 4'b0001; // SUB
                    3'b010: alu_ctrl = 4'b0010; // AND
                    3'b011: alu_ctrl = 4'b0011; // OR
                    3'b100: alu_ctrl = 4'b0100; // XOR
                    3'b101: alu_ctrl = 4'b0101; // SLL
                    3'b110: alu_ctrl = 4'b0110; // SRL
                    3'b111: alu_ctrl = 4'b0111; // SRA
                    default: alu_ctrl = 4'b0000;
                endcase
            end
            default: alu_ctrl = 4'b0000;
        endcase
    end

endmodule
