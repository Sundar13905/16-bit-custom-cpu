`timescale 1ns / 1ps

module pc (

    input  wire        clk,
    input  wire        rst,

    input  wire [15:0] pc_in,

    output reg  [15:0] pc_out

);

    always @(posedge clk or posedge rst) begin

        if (rst)
            pc_out <= 16'h0000;

        else
            pc_out <= pc_in;

    end

endmodule
