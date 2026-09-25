`timescale 1ns / 1ps

module instr_mem (

    input  wire [15:0] instr_addr,
    output reg  [15:0] instr

);

    reg [15:0] instr_mem [0:255];

    integer i;

    initial begin

        for (i = 0; i < 256; i = i + 1)
            instr_mem[i] = 16'h0000;

    end


    always @(*) begin

        instr = instr_mem[instr_addr[7:0]];

    end

endmodule
