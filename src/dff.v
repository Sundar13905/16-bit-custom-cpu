`timescale 1ns / 1ps

module dff #(parameter WIDTH = 16)(
    input clk,
    input reset,
    input [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);

    always @(posedge clk or posedge reset) begin
        if (reset)
            q <= {WIDTH{1'b0}};
        else
            q <= d;
    end

endmodule
