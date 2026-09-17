`timescale 1ns / 1ps
// =============================================================
// fpu_tb.v
// Compact testbench for IEEE-754 half-precision FPU
// Tests FADD (opcode = 4'b0000) and FMUL (opcode = 4'b0010)
// Compatible with the fpu.v provided earlier.
// =============================================================

module fpu_tb;

    reg        enable;
    reg [3:0]  opcode;
    reg [15:0] a, b;
    wire [15:0] result;

    // Instantiate FPU
    fpu DUT (
        .enable(enable),
        .a(a),
        .b(b),
        .opcode(opcode),
        .result(result)
    );

    // Task: display half-precision in human-readable float
    task show_fp;
        input [15:0] val;
        real r;
        integer s;
        integer e;
        integer f;
        real mant;
        begin
            s = val[15];
            e = val[14:10];
            f = val[9:0];
            if (e == 0 && f == 0)
                $write("0.0");
            else if (e == 31)
                $write("%sINF", s ? "-" : "+");
            else begin
                mant = 1.0 + (f / 1024.0); // 10 fraction bits
                r = ((s ? -1.0 : 1.0) * mant * (2.0 ** (e - 15)));
                $write("%f", r);
            end
        end
    endtask

    // Display helper
    task show_case;
        input [15:0] a_in;
        input [15:0] b_in;
        input [15:0] res_in;
        input [3:0]  op;
        begin
            $write("Opcode %b (%s): ", op, (op==4'b0000)?"ADD":"MUL");
            show_fp(a_in);
            $write(" (0x%h) ", a_in);
            $write("%s ", (op==4'b0000)?"+":"*");
            show_fp(b_in);
            $write(" (0x%h) ", b_in);
            $write("= ");
            show_fp(res_in);
            $write(" (0x%h)\n", res_in);
        end
    endtask

    initial begin
$dumpfile("fpu_tb.vcd");
$dumpvars(0, fpu_tb);

        $display("======================================");
        $display(" FPU IEEE-754 HALF-PRECISION TESTBENCH");
        $display("======================================");

        enable = 1;
        opcode = 4'b0000; // ADD
        #5;

        // 1.0 (0x3C00) + 1.0 (0x3C00) = 2.0 (0x4000)
        a = 16'h3C00; b = 16'h3C00; #10;
        show_case(a, b, result, opcode);

        // 2.0 (0x4000) + 3.0 (0x4200) = 5.0 (0x4500)
        a = 16'h4000; b = 16'h4200; #10;
        show_case(a, b, result, opcode);

        // 1.5 (0x3E00) + -0.5 (0xBC00) = 1.0 (0x3C00)
        a = 16'h3E00; b = 16'hBC00; #10;
        show_case(a, b, result, opcode);

        // -2.0 (0xC000) + -2.0 (0xC000) = -4.0 (0xC400)
        a = 16'hC000; b = 16'hC000; #10;
        show_case(a, b, result, opcode);

        // switch to MUL
        opcode = 4'b0010;
        #5;

        // 1.0 * 2.0 = 2.0
        a = 16'h3C00; b = 16'h4000; #10;
        show_case(a, b, result, opcode);

        // 2.0 * 3.0 = 6.0 (≈ 0x4600)
        a = 16'h4000; b = 16'h4200; #10;
        show_case(a, b, result, opcode);

        // 0.5 * 0.5 = 0.25 (0x3400)
        a = 16'h3800; b = 16'h3800; #10;
        show_case(a, b, result, opcode);

        // -1.5 * 2.0 = -3.0 (≈ 0xC420)
        a = 16'hBE00; b = 16'h4000; #10;
        show_case(a, b, result, opcode);

        $display("--------------------------------------");
        $display(" Simulation complete.");
        $display("--------------------------------------");
        $finish;
    end

endmodule
