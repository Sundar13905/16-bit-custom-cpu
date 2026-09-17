`timescale 1ns / 1ps
module regfile_tb;
    reg clk, reg_write;
    reg [2:0] read_reg1, read_reg2, write_reg;
    reg [15:0] write_data;
    wire [15:0] read_data1, read_data2;

    regfile DUT (.clk(clk), .reg_write(reg_write),
                 .read_reg1(read_reg1), .read_reg2(read_reg2),
                 .write_reg(write_reg), .write_data(write_data),
                 .read_data1(read_data1), .read_data2(read_data2));

    always #5 clk = ~clk; // 10ns clock

    initial begin
        $dumpfile("regfile.vcd");
        $dumpvars(0, regfile_tb);
        clk = 0;
        reg_write = 1; write_reg = 3'b001; write_data = 16'h00AA; #10;
        reg_write = 1; write_reg = 3'b010; write_data = 16'h00BB; #10;
        reg_write = 0; read_reg1 = 3'b001; read_reg2 = 3'b010; #10;
        $finish;
    end
endmodule
