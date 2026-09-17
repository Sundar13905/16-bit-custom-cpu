`timescale 1ns / 1ps

module instr_mem_tb;
    reg [15:0] instr_addr;
    wire [15:0] instr;

    instr_mem DUT (
        .instr_addr(instr_addr),
        .instr(instr)
    );

    initial begin
        $dumpfile("instr_mem.vcd");
        $dumpvars(0, instr_mem_tb);

        instr_addr = 0;  #10;
        instr_addr = 1;  #10;
        instr_addr = 2;  #10;
        instr_addr = 3;  #10;
        instr_addr = 4;  #10;

        $finish;
    end
endmodule
