`timescale 1ns / 1ps
//======================================================
// 16-bit Arithmetic Logic Unit (ALU)
//======================================================
module alu (
    input  [15:0] a,
    input  [15:0] b,
    input  [3:0]  alu_ctrl,
    output reg [15:0] alu_out,
    output reg       zero
);

    initial begin
        $display("=== ALU Module Initialized ===");
    end

    always @(*) begin
        alu_out = 16'h0000;
        case (alu_ctrl)
            4'b0000: alu_out = a + b;
            4'b0001: alu_out = a - b;
            4'b0010: alu_out = a & b;
            4'b0011: alu_out = a | b;
            4'b0100: alu_out = a ^ b;
            4'b0101: alu_out = a << b[3:0];
            4'b0110: alu_out = a >> b[3:0];
            4'b0111: alu_out = $signed(a) >>> b[3:0];
            4'b1000: alu_out = ($signed(a) < $signed(b)) ? 16'd1 : 16'd0;
            4'b1001: alu_out = (a < b) ? 16'd1 : 16'd0;
            default: alu_out = 16'h0000;
        endcase
        zero = (alu_out == 16'h0000);
    end
endmodule
