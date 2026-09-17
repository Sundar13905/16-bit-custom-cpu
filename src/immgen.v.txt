`timescale 1ns / 1ps
//======================================================
// Immediate Generator for 16-bit Instructions
//======================================================
module immgen (
    input  [15:0] instr,
    output reg [15:0] imm_out
);
    always @(*) begin
        case (instr[15:12])
            4'b0110, 4'b0111: imm_out = {{8{instr[7]}}, instr[7:0]}; // I-type
            4'b1001:          imm_out = {{8{instr[7]}}, instr[7:0]}; // S-type
            4'b1010:          imm_out = {{8{instr[7]}}, instr[7:0]}; // B-type
            default:          imm_out = 16'h0000;
        endcase
    end
endmodule
