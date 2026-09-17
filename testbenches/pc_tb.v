`timescale 1ns / 1ps

module pc_tb;
    reg clk, reset, branch, jump;
    reg [15:0] branch_addr;
    wire [15:0] pc_out;

    pc DUT (
        .clk(clk),
        .reset(reset),
        .branch(branch),
        .jump(jump),
        .branch_addr(branch_addr),
        .pc_out(pc_out)
    );

    always #5 clk = ~clk; // Clock toggle every 5 ns

    initial begin
        $dumpfile("pc.vcd");
        $dumpvars(0, pc_tb);

        clk = 0; reset = 1; branch = 0; jump = 0; branch_addr = 0;
        #10 reset = 0;     // Release reset

        #20 branch = 0; jump = 0;          // Normal increment
        #20 branch = 1; branch_addr = 16'h000A; // Branch to 0x000A
        #10 branch = 0;
        #20 jump = 1; branch_addr = 16'h0010;   // Jump to 0x0010
        #10 jump = 0;

        #40 $finish;
    end
endmodule
