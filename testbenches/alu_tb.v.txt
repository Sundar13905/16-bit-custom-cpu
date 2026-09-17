`timescale 1ns / 1ps

module alu_tb;
    reg  [15:0] a, b;
    reg  [3:0]  alu_ctrl;       // updated: 4-bit control
    wire [15:0] alu_out;        // matches alu_out signal name
    wire        zero;

    // instantiate the new ALU
    alu #(.WIDTH(16)) DUT (
        .a(a),
        .b(b),
        .alu_ctrl(alu_ctrl),
        .alu_out(alu_out),
        .zero(zero)
    );

    initial begin
        $dumpfile("alu.vcd");
        $dumpvars(0, alu_tb);

        // ----- ALU Tests -----
        a = 16'h0001; b = 16'h0001; alu_ctrl = 4'b0000; #10; // ADD
        a = 16'h0002; b = 16'h0001; alu_ctrl = 4'b0001; #10; // SUB
        a = 16'hAAAA; b = 16'h5555; alu_ctrl = 4'b0010; #10; // AND
        a = 16'hAAAA; b = 16'h5555; alu_ctrl = 4'b0011; #10; // OR
        a = 16'hAAAA; b = 16'h5555; alu_ctrl = 4'b0100; #10; // XOR
        a = 16'h1234; b = 16'h0000; alu_ctrl = 4'b0110; #10; // PASS A
        a = 16'h0001; b = 16'h0002; alu_ctrl = 4'b0101; #10; // SLT test

        $finish;
    end
endmodule

