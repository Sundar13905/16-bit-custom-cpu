`timescale 1ns / 1ps

module instr_mem_test;

    reg [15:0] addr;
    wire [15:0] data;

    instr_mem DUT (
        .instr_addr(addr),
        .instr(data)
    );

    integer i;

    initial begin
        $display("=== Testing Instruction Memory ===");
        #5;

        for (i = 0; i < 16; i = i + 1) begin
            addr = i;
            #1;
            $display("ADDR=%0d DATA=%h", addr, data);
        end

        $display("=== Test Complete ===");
        $finish;
    end

endmodule
