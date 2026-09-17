`timescale 1ns / 1ps
//======================================================
// Program Counter (PC) for 16-bit CPU
//======================================================
module pc (
    input clk,
    input reset,
    input branch,
    input jump,
    input [15:0] branch_addr,
    output reg [15:0] pc
);
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc <= 16'h0000;
        else if (branch)
            pc <= branch_addr;
        else if (jump)
            pc <= branch_addr;
        else
            pc <= pc + 16'd1;
    end
endmodule
