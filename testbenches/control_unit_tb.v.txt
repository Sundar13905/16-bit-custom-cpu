`timescale 1ns / 1ps

module control_unit_tb;

    reg  [3:0] opcode;
    reg  [2:0] funct;
    wire reg_write, mem_read, mem_write, alu_src, branch, jump, fpu_enable;
    wire [3:0] alu_ctrl, fpu_opcode;

    control_unit DUT (
        .opcode(opcode),
        .funct(funct),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .branch(branch),
        .jump(jump),
        .alu_ctrl(alu_ctrl),
        .fpu_enable(fpu_enable),
        .fpu_opcode(fpu_opcode)
    );

    initial begin
        $dumpfile("control_unit.vcd");
        $dumpvars(0, control_unit_tb);

        // --- Test 1: R-type ADD ---
        opcode = 4'b0000; funct = 3'b000; #10;

        // --- Test 2: R-type SUB ---
        opcode = 4'b0000; funct = 3'b001; #10;

        // --- Test 3: Immediate ADDI ---
        opcode = 4'b0110; funct = 3'b000; #10;

        // --- Test 4: SLTI ---
        opcode = 4'b0111; funct = 3'b000; #10;

        // --- Test 5: LOAD ---
        opcode = 4'b1000; funct = 3'b000; #10;

        // --- Test 6: STORE ---
        opcode = 4'b1001; funct = 3'b000; #10;

        // --- Test 7: BEQ ---
        opcode = 4'b1010; funct = 3'b000; #10;

        // --- Test 8: FPU ---
        opcode = 4'b1110; funct = 3'b000; #10;

        $finish;
    end
endmodule
