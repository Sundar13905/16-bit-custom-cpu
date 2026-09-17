`timescale 1ns / 1ps

module register_file_tb;

    reg clk, wr_en;
    reg [2:0] rd_addr1, rd_addr2, wr_addr;
    reg [15:0] wr_data;
    wire [15:0] rd_data1, rd_data2;

    register_file RF (
        .clk(clk), .wr_en(wr_en),
        .rd_addr1(rd_addr1), .rd_addr2(rd_addr2),
        .wr_addr(wr_addr),
        .wr_data(wr_data),
        .rd_data1(rd_data1), .rd_data2(rd_data2)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("register_file.vcd");
        $dumpvars(0, register_file_tb);

        clk = 0; wr_en = 0; wr_addr = 0; wr_data = 0;
        rd_addr1 = 0; rd_addr2 = 0;

        #10;
        wr_en = 1; wr_addr = 3'b001; wr_data = 16'hAAAA; #10;
        wr_en = 1; wr_addr = 3'b010; wr_data = 16'h5555; #10;
        wr_en = 0; rd_addr1 = 3'b001; rd_addr2 = 3'b010; #10;

        $display("R1=%h, R2=%h", rd_data1, rd_data2);
        $finish;
    end

endmodule
