`timescale 1ns / 1ps

module immgen_tb;
    reg [15:0] instr;
    wire [15:0] imm_out;

    immgen DUT(.instr(instr), .imm_out(imm_out));

    initial begin
        $dumpfile("immgen.vcd");
        $dumpvars(0, immgen_tb);

        instr = 16'b1000_010_000_111_1111; #10; // LW with negative offset
        instr = 16'b0000_001_010_011_0101; #10; // ADD immediate +5
        instr = 16'b1010_000_000_000_0010; #10; // BEQ +2
        instr = 16'b1011_000_000_11111111; #10; // JUMP -1

        $finish;
    end
endmodule
