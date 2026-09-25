`timescale 1ns / 1ps

module alu (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [15:0] alu_out,
    output reg         zero
);

    always @(*) begin

        case (alu_ctrl)

            4'b0000: begin
                alu_out = a + b;                         // ADD
            end

            4'b0001: begin
                alu_out = a - b;                         // SUB
            end

            4'b0010: begin
                alu_out = a & b;                         // AND
            end

            4'b0011: begin
                alu_out = a | b;                         // OR
            end

            4'b0100: begin
                alu_out = a ^ b;                         // XOR
            end

            4'b0101: begin
                alu_out = a << b[3:0];                   // SLL
            end

            4'b0110: begin
                alu_out = a >> b[3:0];                   // SRL
            end

            4'b0111: begin
                alu_out = $signed(a) >>> b[3:0];         // SRA
            end

            4'b1000: begin
                alu_out = ($signed(a) < $signed(b))
                          ? 16'h0001 : 16'h0000;          // SLT
            end

            default: begin
                alu_out = 16'h0000;
            end

        endcase

        zero = (alu_out == 16'h0000);

    end

endmodule
