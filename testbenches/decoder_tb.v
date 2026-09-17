`timescale 1ns / 1ps
module decoder_tb;
    reg [15:0] instr;
    wire [3:0] alu_ctrl;
    wire reg_write, mem_read, mem_write, branch, jump, alu_src;

    decoder DUT (
        .instr(instr),
        .alu_ctrl(alu_ctrl),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .jump(jump),
        .alu_src(alu_src)
    );

    initial begin
        $dumpfile("decoder.vcd");
        $dumpvars(0, decoder_tb);

        instr = 16'b0000_0000_0000_0000; #10; // ADD
        instr = 16'b1000_0000_0000_0000; #10; // LW
        instr = 16'b1001_0000_0000_0000; #10; // SW
        instr = 16'b1010_0000_0000_0000; #10; // BEQ
        instr = 16'b1011_0000_0000_0000; #10; // JUMP

        $finish;
    end
endmodule
