`timescale 1ns / 1ps
//======================================================
// 16-bit Floating Point Unit (FPU)
//======================================================
module fpu (
    input        enable,
    input [15:0] a,
    input [15:0] b,
    input [3:0]  opcode,
    output reg [15:0] result
);
    always @(*) begin
        if (enable) begin
            case (opcode)
                4'b0000: result = a + b;                    // ADD
                4'b0001: result = a - b;                    // SUB
                4'b0010: result = (a * b) >> 4;             // MUL
                4'b0011: result = (b != 0) ? (a / b) : 16'hFFFF; // DIV
                4'b0100: result = {~a[15], a[14:0]};        // NEG
                4'b0101: result = {1'b0, a[14:0]};          // ABS
                4'b0110: result = (a > b) ? 16'h0001 : 16'h0000; // GT
                4'b0111: result = (a == b) ? 16'h0001 : 16'h0000; // EQ
                default: result = 16'h0000;
            endcase
        end else begin
            result = 16'h0000;
        end
    end
endmodule
