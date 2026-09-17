`timescale 1ns / 1ps

module mux2 #(parameter WIDTH = 16)(
    input [WIDTH-1:0] d1, d2,
    input sel,
    output [WIDTH-1:0] y
);

    assign y = sel ? d2 : d1;

endmodule
