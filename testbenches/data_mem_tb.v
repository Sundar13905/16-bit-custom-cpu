`timescale 1ns / 1ps

module data_mem_tb;
    reg clk, mem_read, mem_write;
    reg [15:0] address, write_data;
    wire [15:0] read_data;

    data_mem DUT (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .address(address),
        .write_data(write_data),
        .read_data(read_data)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("data_mem.vcd");
        $dumpvars(0, data_mem_tb);

        clk = 0;
        // Write two memory words
        mem_write = 1; mem_read = 0;
        address = 16'h0001; write_data = 16'hAAAA; #10;
        address = 16'h0002; write_data = 16'hBBBB; #10;

        // Read them back
        mem_write = 0; mem_read = 1;
        address = 16'h0001; #10;
        address = 16'h0002; #10;

        $finish;
    end
endmodule
