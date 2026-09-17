`timescale 1ns / 1ps

module decoder(
    input  wire [15:0] instr,       // full instruction
    output reg  [3:0]  alu_ctrl,    // ALU operation
    output reg         reg_write,   // register write enable
    output reg         mem_read,    // memory read enable
    output reg         mem_write,   // memory write enable
    output reg         branch,      // branch control
    output reg         jump,        // jump control
    output reg         alu_src      // 1 = immediate, 0 = register operand
);
    wire [3:0] opcode = instr[15:12];

    always @(*) begin
        // default (safe) values
        alu_ctrl  = 4'b0000;
        reg_write = 0;
        mem_read  = 0;
        mem_write = 0;
        branch    = 0;
        jump      = 0;
        alu_src   = 0;

        case (opcode)
            4'b0000: begin // ADD
                alu_ctrl  = 4'b0000;
                reg_write = 1;
            end
            4'b0001: begin // SUB
                alu_ctrl  = 4'b0001;
                reg_write = 1;
            end
            4'b0010: begin // AND
                alu_ctrl  = 4'b0010;
                reg_write = 1;
            end
            4'b0011: begin // OR
                alu_ctrl  = 4'b0011;
                reg_write = 1;
            end
            4'b0100: begin // XOR
                alu_ctrl  = 4'b0100;
                reg_write = 1;
            end
            4'b0101: begin // SLT
                alu_ctrl  = 4'b0101;
                reg_write = 1;
            end
            4'b0110: begin // ADDI (immediate)
                alu_ctrl  = 4'b0000;
                reg_write = 1;
                alu_src   = 1;
            end
            4'b1000: begin // LW
                alu_ctrl  = 4'b0000;
                reg_write = 1;
                mem_read  = 1;
                alu_src   = 1;
            end
            4'b1001: begin // SW
                alu_ctrl  = 4'b0000;
                mem_write = 1;
                alu_src   = 1;
            end
            4'b1010: begin // BEQ
                alu_ctrl  = 4'b0001; // subtraction for comparison
                branch    = 1;
            end
            4'b1011: begin // JUMP
                jump      = 1;
            end
            default: begin
                // no-op
            end
        endcase
    end
endmodule
