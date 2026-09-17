`timescale 1ns / 1ps
//======================================================
// 16-bit Instruction Memory
//======================================================
module instr_mem (
    input  [15:0] instr_addr,
    output reg [15:0] instr
);
    reg [15:0] instr_mem [0:255];
    integer i;
    initial begin
        $display("=== Loading rv16i_test.txt into Instruction Memory ===");
        for (i = 0; i < 256; i = i + 1)
            instr_mem[i] = 16'h0000;
        $readmemh("rv16i_test.txt", instr_mem);
        $display("=== Instruction Memory Load Complete ===");
    end
    always @(*) begin
        instr = instr_mem[instr_addr[7:0]];
    end
endmodule
