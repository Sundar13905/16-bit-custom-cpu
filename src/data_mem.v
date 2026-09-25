`timescale 1ns / 1ps

module data_mem (

    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,

    input  wire [15:0] address,
    input  wire [15:0] write_data,

    output reg  [15:0] read_data

);

    reg [15:0] memory [0:255];

    integer i;

    initial begin

        for (i = 0; i < 256; i = i + 1)
            memory[i] = 16'h0000;

    end


    // ==========================================================
    // Store
    // ==========================================================

    always @(posedge clk) begin

        if (mem_write)
            memory[address[7:0]] <= write_data;

    end


    // ==========================================================
    // Load
    // ==========================================================

    always @(*) begin

        if (mem_read)
            read_data = memory[address[7:0]];

        else
            read_data = 16'h0000;

    end

endmodule
