`timescale 1ns / 1ps

module pipelined_core_tb;

    reg clk;
    reg rst;

    integer pass_count;
    integer fail_count;

    // Set to 1 when you want cycle-by-cycle internal debug.
    localparam DEBUG = 0;

    // ============================================================
    // DUT
    // ============================================================

    pipelined_core DUT (
        .clk(clk),
        .rst(rst)
    );

    // ============================================================
    // CLOCK
    // ============================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // WAVEFORM
    // ============================================================

    initial begin
        $dumpfile("pipelined_core_full_regression.vcd");
        $dumpvars(0, pipelined_core_tb);
    end

    // ============================================================
    // ISA ENCODERS
    //
    // Instruction format used by the current pipelined core:
    //
    // R-type:
    // [15]    = 0
    // [14:12] = 000
    // [11:9]  = Rd
    // [8:6]   = Rs1
    // [5:3]   = Rs2
    // [2:0]   = funct
    //
    // I-type / LH / SH:
    // [15]    = imm[3]
    // [14:12] = opcode
    // [11:9]  = Rd / store data register
    // [8:6]   = Rs1
    // [5:3]   = imm[2:0]
    // [2:0]   = funct
    //
    // Branch:
    // [15]    = offset[3]
    // [14:12] = 100
    // [11:9]  = Rs1
    // [8:6]   = Rs2
    // [5:3]   = offset[2:0]
    // [2:0]   = funct
    //
    // JAL:
    // [15]    = offset[3]
    // [14:12] = 101
    // [11:9]  = Rd
    // [8:6]   = offset[2:0]
    // [5:3]   = 001
    //
    // JALR:
    // [15]    = imm[3]
    // [14:12] = 111
    // [11:9]  = Rd
    // [8:6]   = Rs1
    // [5:3]   = imm[2:0]
    // [2:0]   = 000
    //
    // FPU:
    // [15]    = 0
    // [14:12] = 110
    // [11:9]  = Rd
    // [8:6]   = Rs1
    // [5:3]   = Rs2
    // [2:0]   = funct
    //
    // funct:
    // 000 ADD / ADDI / FADD
    // 001 SUB / SUBI / FMUL
    // 010 SLT / SLTI
    // 011 SRL / SRLI / BGE
    // 100 OR  / ORI  / BLT
    // 101 SLL / SLLI
    // 110 AND / ANDI
    // 111 SRA / SRAI
    // ============================================================

    function [15:0] enc_r;
        input [2:0] rd;
        input [2:0] rs1;
        input [2:0] rs2;
        input [2:0] funct;
        begin
            enc_r = {1'b0, 3'b000, rd, rs1, rs2, funct};
        end
    endfunction

    function [15:0] enc_i;
        input [2:0] opcode;
        input [2:0] rd;
        input [2:0] rs1;
        input signed [3:0] imm;
        input [2:0] funct;
        begin
            enc_i = {
                imm[3],
                opcode,
                rd,
                rs1,
                imm[2:0],
                funct
            };
        end
    endfunction

    function [15:0] enc_b;
        input [2:0] rs1;
        input [2:0] rs2;
        input signed [3:0] offset;
        input [2:0] funct;
        begin
            enc_b = {
                offset[3],
                3'b100,
                rs1,
                rs2,
                offset[2:0],
                funct
            };
        end
    endfunction

    function [15:0] enc_jal;
    input [2:0] rd;
    input signed [3:0] offset;

    begin
        enc_jal = {
            offset[3],
            3'b101,
            rd,
            3'b000,
            offset[2:0],
            3'b001
        };
    end
endfunction

    function [15:0] enc_jalr;
        input [2:0] rd;
        input [2:0] rs1;
        input signed [3:0] imm;
        begin
            enc_jalr = {
                imm[3],
                3'b111,
                rd,
                rs1,
                imm[2:0],
                3'b000
            };
        end
    endfunction

    function [15:0] enc_fpu;
        input [2:0] rd;
        input [2:0] rs1;
        input [2:0] rs2;
        input [2:0] funct;
        begin
            enc_fpu = {1'b0, 3'b110, rd, rs1, rs2, funct};
        end
    endfunction

    // ============================================================
    // HELPER TASKS
    // ============================================================

    task clear_instruction_memory;
        integer i;
        begin
            for (i = 0; i < 256; i = i + 1)
                DUT.IMEM.instr_mem[i] = 16'h0000;
        end
    endtask

    task clear_data_memory;
        integer i;
        begin
            for (i = 0; i < 256; i = i + 1)
                DUT.DMEM.memory[i] = 16'h0000;
        end
    endtask

    task init_registers;
        begin
            DUT.RF.registers[0] = 16'h0000;
            DUT.RF.registers[1] = 16'h0000;
            DUT.RF.registers[2] = 16'h0000;
            DUT.RF.registers[3] = 16'h0000;
            DUT.RF.registers[4] = 16'h0000;
            DUT.RF.registers[5] = 16'h0000;
            DUT.RF.registers[6] = 16'h0000;
            DUT.RF.registers[7] = 16'h0000;
        end
    endtask

    task reset_cpu;
        begin
            rst = 1'b1;
            repeat (2) @(posedge clk);
            rst = 1'b0;
            #1;
        end
    endtask

    task run_cycles;
        input integer cycles;
        begin
            repeat (cycles) @(posedge clk);
            #1;
        end
    endtask

    task record_pass;
        begin
            pass_count = pass_count + 1;
        end
    endtask

    task record_fail;
        begin
            fail_count = fail_count + 1;
        end
    endtask

    task check_reg;
        input [2:0] reg_num;
        input [15:0] expected;
        begin
            if (DUT.RF.registers[reg_num] === expected) begin
                $display("PASS: R%0d = %h", reg_num, expected);
                record_pass;
            end
            else begin
                $display(
                    "FAIL: R%0d = %h, expected %h",
                    reg_num,
                    DUT.RF.registers[reg_num],
                    expected
                );
                record_fail;
            end
        end
    endtask

    task check_mem;
        input [7:0] addr;
        input [15:0] expected;
        begin
            if (DUT.DMEM.memory[addr] === expected) begin
                $display("PASS: MEM[%0d] = %h", addr, expected);
                record_pass;
            end
            else begin
                $display(
                    "FAIL: MEM[%0d] = %h, expected %h",
                    addr,
                    DUT.DMEM.memory[addr],
                    expected
                );
                record_fail;
            end
        end
    endtask

    // ============================================================
    // MAIN REGRESSION
    // ============================================================

    initial begin

        rst = 1'b1;
        pass_count = 0;
        fail_count = 0;

        // ========================================================
        // TEST 1: R-TYPE ARITHMETIC / LOGICAL
        // ========================================================
        //
        // ADD, SUB, SLT, OR, AND
        // Each result uses a different destination register so
        // there is no ambiguity about the expected final value.
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'd5;
        DUT.RF.registers[2] = 16'd10;

        DUT.IMEM.instr_mem[0] = enc_r(3, 1, 2, 3'b000); // ADD = 15
        DUT.IMEM.instr_mem[1] = enc_r(4, 2, 1, 3'b001); // SUB = 5
        DUT.IMEM.instr_mem[2] = enc_r(5, 1, 2, 3'b010); // SLT = 1
        DUT.IMEM.instr_mem[3] = enc_r(6, 1, 2, 3'b100); // OR  = 15
        DUT.IMEM.instr_mem[4] = enc_r(7, 1, 2, 3'b110); // AND = 0

        reset_cpu;
        run_cycles(12);

        $display("\n============================================================");
        $display("TEST 1: R-TYPE ARITHMETIC / LOGICAL");
        $display("============================================================");

        check_reg(3, 16'h000F);
        check_reg(4, 16'h0005);
        check_reg(5, 16'h0001);
        check_reg(6, 16'h000F);
        check_reg(7, 16'h0000);

        // ========================================================
        // TEST 2: R-TYPE SHIFT OPERATIONS
        // ========================================================
        //
        // SLL, SRL, SRA
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h8000;
        DUT.RF.registers[2] = 16'h0001;

        DUT.IMEM.instr_mem[0] = enc_r(3, 1, 2, 3'b101); // SLL = 0000
        DUT.IMEM.instr_mem[1] = enc_r(4, 1, 2, 3'b011); // SRL = 4000
        DUT.IMEM.instr_mem[2] = enc_r(5, 1, 2, 3'b111); // SRA = C000

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 2: R-TYPE SHIFT OPERATIONS");
        $display("============================================================");

        check_reg(3, 16'h0000);
        check_reg(4, 16'h4000);
        check_reg(5, 16'hC000);

        // ========================================================
        // TEST 3: SIGNED SLT / SLTI
        // ========================================================
        //
        // Explicit negative/positive comparisons.
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'hFFFF; // -1
        DUT.RF.registers[2] = 16'h0001; // +1
        DUT.RF.registers[3] = 16'h0001; // +1

        DUT.IMEM.instr_mem[0] = enc_r(4, 1, 2, 3'b010); // -1 < +1 = 1
        DUT.IMEM.instr_mem[1] = enc_i(3'b011, 5, 1, 4'sd1, 3'b010);
                                                     // -1 < +1 = 1
        DUT.IMEM.instr_mem[2] = enc_i(3'b011, 6, 3, -4'sd1, 3'b010);
                                                     // +1 < -1 = 0

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 3: SIGNED SLT / SLTI");
        $display("============================================================");

        check_reg(4, 16'h0001);
        check_reg(5, 16'h0001);
        check_reg(6, 16'h0000);

        // ========================================================
        // TEST 4: IMMEDIATE ARITHMETIC / LOGICAL
        // ========================================================
        //
        // ADDI, SUBI, ORI, ANDI
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h000A;
        DUT.RF.registers[2] = 16'h000A;

        DUT.IMEM.instr_mem[0] = enc_i(3'b011, 3, 1, 4'sd3,  3'b000); // ADDI = 13
        DUT.IMEM.instr_mem[1] = enc_i(3'b011, 4, 1, 4'sd3,  3'b001); // SUBI = 7
        DUT.IMEM.instr_mem[2] = enc_i(3'b011, 5, 1, 4'sd3,  3'b100); // ORI  = 11
        DUT.IMEM.instr_mem[3] = enc_i(3'b011, 6, 1, 4'sd3,  3'b110); // ANDI = 2
        DUT.IMEM.instr_mem[4] = enc_i(3'b011, 7, 1, -4'sd3, 3'b000); // ADDI = 7

        reset_cpu;
        run_cycles(12);

        $display("\n============================================================");
        $display("TEST 4: IMMEDIATE ARITHMETIC / LOGICAL");
        $display("============================================================");

        check_reg(3, 16'h000D);
        check_reg(4, 16'h0007);
        check_reg(5, 16'h000B);
        check_reg(6, 16'h0002);
        check_reg(7, 16'h0007);

        // ========================================================
        // TEST 5: IMMEDIATE SHIFT OPERATIONS
        // ========================================================
        //
        // SLLI, SRLI, SRAI
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h000A;
        DUT.RF.registers[2] = 16'h8000;

        DUT.IMEM.instr_mem[0] = enc_i(3'b011, 3, 1, 4'sd3, 3'b101); // SLLI = 50
        DUT.IMEM.instr_mem[1] = enc_i(3'b011, 4, 2, 4'sd3, 3'b011); // SRLI = 1000
        DUT.IMEM.instr_mem[2] = enc_i(3'b011, 5, 2, 4'sd3, 3'b111); // SRAI = F000

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 5: IMMEDIATE SHIFT OPERATIONS");
        $display("============================================================");

        check_reg(3, 16'h0050);
        check_reg(4, 16'h1000);
        check_reg(5, 16'hF000);

        // ========================================================
        // TEST 6: SH / LH + ADDRESS FORWARDING
        // ========================================================
        //
        // PC0: ADDI R2,R0,4
        // PC1: SH   R3,2(R2)  -> MEM[6]
        // PC2: LH   R4,2(R2)  -> R4 = 1234
        //
        // The store address depends on the immediately preceding
        // ADDI result, so this also exercises EX/MEM forwarding
        // into the memory-address calculation.
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[3] = 16'h1234;

        DUT.IMEM.instr_mem[0] = enc_i(3'b011, 2, 0, 4'sd4, 3'b000);
        DUT.IMEM.instr_mem[1] = enc_i(3'b010, 3, 2, 4'sd2, 3'b010);
        DUT.IMEM.instr_mem[2] = enc_i(3'b001, 4, 2, 4'sd2, 3'b010);

        reset_cpu;
        run_cycles(12);

        $display("\n============================================================");
        $display("TEST 6: SH / LH + ADDRESS FORWARDING");
        $display("============================================================");

        check_mem(8'd6, 16'h1234);
        check_reg(4, 16'h1234);

        // ========================================================
        // TEST 7: EX/MEM + MEM/WB ALU FORWARDING
        // ========================================================
        //
        // ADD R1,R2,R3
        // ADD R4,R5,R6
        // SUB R7,R4,R1
        //
        // The final SUB needs:
        //   A from EX/MEM (R4)
        //   B from MEM/WB (R1)
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[2] = 16'd10;
        DUT.RF.registers[3] = 16'd20;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] = enc_r(1, 2, 3, 3'b000); // R1 = 30
        DUT.IMEM.instr_mem[1] = enc_r(4, 5, 6, 3'b000); // R4 = 15
        DUT.IMEM.instr_mem[2] = enc_r(7, 4, 1, 3'b001); // R7 = -15

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 7: ALU FORWARDING");
        $display("============================================================");

        check_reg(1, 16'h001E);
        check_reg(4, 16'h000F);
        check_reg(7, 16'hFFF1);

        // ========================================================
        // TEST 8: LOAD-USE HAZARD
        // ========================================================
        //
        // LH R1,0(R2)
        // ADD R3,R1,R4
        //
        // Requires one-cycle stall, then forwarding.
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[2] = 16'd0;
        DUT.RF.registers[4] = 16'd5;
        DUT.DMEM.memory[0] = 16'd10;

        DUT.IMEM.instr_mem[0] = enc_i(3'b001, 1, 2, 4'sd0, 3'b010);
        DUT.IMEM.instr_mem[1] = enc_r(3, 1, 4, 3'b000);

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 8: LOAD-USE HAZARD");
        $display("============================================================");

        check_reg(1, 16'h000A);
        check_reg(3, 16'h000F);

        // ========================================================
        // TEST 9: LOAD-TO-BRANCH HAZARD
        // ========================================================
        //
        // LH R1,0(R2)
        // BEQ R1,R1,+2
        // wrong path
        // target
        //
        // Tests both the load-use stall and branch operand
        // forwarding.
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[2] = 16'd0;
        DUT.RF.registers[3] = 16'd20;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;
        DUT.DMEM.memory[0] = 16'd10;

        DUT.IMEM.instr_mem[0] = enc_i(3'b001, 1, 2, 4'sd0, 3'b010);
        DUT.IMEM.instr_mem[1] = enc_b(1, 1, 4'sd2, 3'b000); // taken
        DUT.IMEM.instr_mem[2] = enc_r(4, 5, 6, 3'b000);      // flushed
        DUT.IMEM.instr_mem[3] = enc_r(7, 1, 3, 3'b000);      // target = 30

        reset_cpu;
        run_cycles(12);

        $display("\n============================================================");
        $display("TEST 9: LOAD-TO-BRANCH HAZARD");
        $display("============================================================");

        check_reg(1, 16'h000A);
        check_reg(4, 16'h0000);
        check_reg(7, 16'h001E);

        // ========================================================
        // TEST 10: BEQ TAKEN
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'd10;
        DUT.RF.registers[2] = 16'd10;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] = enc_b(1, 2, 4'sd2, 3'b000);
        DUT.IMEM.instr_mem[1] = enc_r(4, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[2] = enc_r(7, 1, 2, 3'b000); // target = 20

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 10: BEQ TAKEN");
        $display("============================================================");

        check_reg(4, 16'h0000);
        check_reg(7, 16'h0014);

        // ========================================================
        // TEST 11: BEQ NOT TAKEN
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'd10;
        DUT.RF.registers[2] = 16'd11;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] = enc_b(1, 2, 4'sd2, 3'b000); // not taken
        DUT.IMEM.instr_mem[1] = enc_r(4, 5, 6, 3'b000);      // executes
        DUT.IMEM.instr_mem[2] = enc_r(7, 5, 6, 3'b000);      // executes

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 11: BEQ NOT TAKEN");
        $display("============================================================");

        check_reg(4, 16'h000F);
        check_reg(7, 16'h000F);

        // ========================================================
        // TEST 12: BNE TAKEN
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'd10;
        DUT.RF.registers[2] = 16'd11;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] = enc_b(1, 2, 4'sd2, 3'b001);
        DUT.IMEM.instr_mem[1] = enc_r(4, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[2] = enc_r(7, 5, 6, 3'b000); // target = 15

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 12: BNE TAKEN");
        $display("============================================================");

        check_reg(4, 16'h0000);
        check_reg(7, 16'h000F);

        // ========================================================
        // TEST 13: BLT TAKEN
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'd5;
        DUT.RF.registers[2] = 16'd10;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] = enc_b(1, 2, 4'sd2, 3'b100);
        DUT.IMEM.instr_mem[1] = enc_r(4, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[2] = enc_r(7, 5, 6, 3'b000); // target = 15

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 13: BLT TAKEN");
        $display("============================================================");

        check_reg(4, 16'h0000);
        check_reg(7, 16'h000F);

        // ========================================================
        // TEST 14: BGE TAKEN
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'd10;
        DUT.RF.registers[2] = 16'd5;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] = enc_b(1, 2, 4'sd2, 3'b011);
        DUT.IMEM.instr_mem[1] = enc_r(4, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[2] = enc_r(7, 5, 6, 3'b000); // target = 15

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 14: BGE TAKEN");
        $display("============================================================");

        check_reg(4, 16'h0000);
        check_reg(7, 16'h000F);

        // ========================================================
        // TEST 15: BRANCH FORWARDING FROM ALU RESULT
        // ========================================================
        //
        // ADD R1,R2,R3
        // BEQ R1,R4,+2
        //
        // R1 is produced immediately before the branch, so the
        // branch comparison must use the forwarded EX/MEM result.
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[2] = 16'd10;
        DUT.RF.registers[3] = 16'd20;
        DUT.RF.registers[4] = 16'd30;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] = enc_r(1, 2, 3, 3'b000); // R1 = 30
        DUT.IMEM.instr_mem[1] = enc_b(1, 4, 4'sd2, 3'b000); // taken
        DUT.IMEM.instr_mem[2] = enc_r(7, 5, 6, 3'b000);      // flushed
        DUT.IMEM.instr_mem[3] = enc_r(7, 5, 6, 3'b000);      // target

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 15: BRANCH FORWARDING FROM ALU RESULT");
        $display("============================================================");

        check_reg(7, 16'h000F);

        // ========================================================
        // TEST 16: JAL
        // ========================================================
        //
        // JAL R1,+4 at PC0:
        //   R1 = PC+1 = 1
        //   target  = PC4
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] = enc_jal(1, 4'sd4);
        DUT.IMEM.instr_mem[1] = enc_r(4, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[2] = enc_r(4, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[3] = enc_r(4, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[4] = enc_r(7, 5, 6, 3'b000); // target = 15

        reset_cpu;

$display("");
$display("============================================================");
$display("TEST 16: JAL DEBUG");
$display("============================================================");

repeat (10) begin
    @(posedge clk);
    #1;

    $display(
        "TIME=%0t | PC=%h | NEXT=%h | INSTR=%h | IF_ID_PC=%h | IF_ID_INSTR=%h",
        $time,
        DUT.pc_out,
        DUT.next_pc,
        DUT.instr,
        DUT.if_id_pc,
        DUT.if_id_instr
    );

    $display(
        "ID_EX: PC=%h IMM=%h RS1=%0d RS2=%0d RD=%0d JUMP=%b JALR=%b REGW=%b WBSEL=%b PC1=%h",
        DUT.id_ex_pc,
        DUT.id_ex_imm,
        DUT.id_ex_rs1,
        DUT.id_ex_rs2,
        DUT.id_ex_rd,
        DUT.id_ex_jump,
        DUT.id_ex_jalr,
        DUT.id_ex_reg_write,
        DUT.id_ex_wb_select,
        DUT.id_ex_pc_plus1
    );

    $display(
        "EX: A=%h B=%h JMP=%b TARGET=%h CONTROL=%b RESULT=%h",
        DUT.ex_forward_a,
        DUT.ex_forward_b,
        DUT.ex_jump_taken,
        DUT.ex_jump_target,
        DUT.ex_control_taken,
        DUT.ex_result
    );

    $display(
        "EX_MEM: RESULT=%h RD=%0d REGW=%b WBSEL=%b PC1=%h",
        DUT.ex_mem_execution_result,
        DUT.ex_mem_rd,
        DUT.ex_mem_reg_write,
        DUT.ex_mem_wb_select,
        DUT.ex_mem_pc_plus1
    );

    $display(
        "MEM_WB: RESULT=%h RD=%0d REGW=%b WBSEL=%b PC1=%h WB=%h",
        DUT.mem_wb_execution_result,
        DUT.mem_wb_rd,
        DUT.mem_wb_reg_write,
        DUT.mem_wb_wb_select,
        DUT.mem_wb_pc_plus1,
        DUT.wb_write_data
    );

    $display(
        "RF: R1=%h R4=%h R5=%h R6=%h R7=%h",
        DUT.RF.registers[1],
        DUT.RF.registers[4],
        DUT.RF.registers[5],
        DUT.RF.registers[6],
        DUT.RF.registers[7]
    );

    $display("------------------------------------------------------------");
end


        check_reg(1, 16'h0001);
        check_reg(4, 16'h0000);
        check_reg(7, 16'h000F);

        // ========================================================
        // TEST 17: JALR DIRECT TARGET
        // ========================================================
        //
        // R2 already contains 4.
        // JALR R1,R2,2 -> target = 6
        // Link = PC+1 = 2
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[2] = 16'd4;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] = enc_jalr(1, 2, 4'sd2);
        DUT.IMEM.instr_mem[1] = enc_r(7, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[2] = enc_r(7, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[3] = enc_r(7, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[4] = enc_r(7, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[5] = enc_r(7, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[6] = enc_r(7, 5, 6, 3'b000); // target = 15

        reset_cpu;
        run_cycles(14);

        $display("\n============================================================");
        $display("TEST 17: JALR DIRECT TARGET");
        $display("============================================================");

        check_reg(1, 16'h0001);
        check_reg(7, 16'h000F);

        // ========================================================
        // TEST 18: JALR + TARGET FORWARDING
        // ========================================================
        //
        // PC0: ADD R2,R3,R4 -> R2=4
        // PC1: JALR R1,R2,2 -> target=6
        //
        // This specifically verifies forwarding into the JALR
        // target-address calculation.
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[3] = 16'd2;
        DUT.RF.registers[4] = 16'd2;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] = enc_r(2, 3, 4, 3'b000); // R2=4
        DUT.IMEM.instr_mem[1] = enc_jalr(1, 2, 4'sd2);  // target=6
        DUT.IMEM.instr_mem[2] = enc_r(7, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[3] = enc_r(7, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[4] = enc_r(7, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[5] = enc_r(7, 5, 6, 3'b000); // flushed
        DUT.IMEM.instr_mem[6] = enc_r(7, 5, 6, 3'b000); // target = 15

        reset_cpu;
        run_cycles(16);

        $display("\n============================================================");
        $display("TEST 18: JALR + TARGET FORWARDING");
        $display("============================================================");

        check_reg(1, 16'h0002);
        check_reg(2, 16'h0004);
        check_reg(7, 16'h000F);

        // ========================================================
        // TEST 19: FPU PIPELINE + FORWARDING
        // ========================================================
        //
        // FADD R3,R1,R2 = 3.0
        // FADD R4,R3,R1 = 4.0
        // FMUL R5,R4,R2 = 8.0
        // FADD R6,R5,R1 = 9.0
        //
        // Tests FPU execution plus chained forwarding.
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h3C00; // 1.0
        DUT.RF.registers[2] = 16'h4000; // 2.0

        DUT.IMEM.instr_mem[0] = enc_fpu(3, 1, 2, 3'b000); // 3.0
        DUT.IMEM.instr_mem[1] = enc_fpu(4, 3, 1, 3'b000); // 4.0
        DUT.IMEM.instr_mem[2] = enc_fpu(5, 4, 2, 3'b001); // 8.0
        DUT.IMEM.instr_mem[3] = enc_fpu(6, 5, 1, 3'b000); // 9.0

        reset_cpu;
        run_cycles(14);

        $display("\n============================================================");
        $display("TEST 19: FPU PIPELINE + FORWARDING");
        $display("============================================================");

        check_reg(3, 16'h4200);
        check_reg(4, 16'h4400);
        check_reg(5, 16'h4800);
        check_reg(6, 16'h4880);

        // ========================================================
        // TEST 20: FPU ARITHMETIC CASES
        // ========================================================
        //
        // FADD 1 + (-1) = 0
        // FADD 1.5 + 1.5 = 3
        // FMUL 1 * 2 = 2
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h3C00; // 1.0
        DUT.RF.registers[2] = 16'hBC00; // -1.0
        DUT.RF.registers[3] = 16'h3E00; // 1.5
        DUT.RF.registers[4] = 16'h4000; // 2.0

        DUT.IMEM.instr_mem[0] = enc_fpu(5, 1, 2, 3'b000);
        DUT.IMEM.instr_mem[1] = enc_fpu(6, 3, 3, 3'b000);
        DUT.IMEM.instr_mem[2] = enc_fpu(7, 1, 4, 3'b001);

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 20: FPU ARITHMETIC CASES");
        $display("============================================================");

        check_reg(5, 16'h0000);
        check_reg(6, 16'h4200);
        check_reg(7, 16'h4000);

        // ========================================================
        // TEST 21: FPU NEGATIVE / ZERO CASES
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'hBC00; // -1.0
        DUT.RF.registers[2] = 16'h4000; // +2.0
        DUT.RF.registers[3] = 16'h0000; // +0.0

        DUT.IMEM.instr_mem[0] = enc_fpu(4, 1, 2, 3'b001); // -2.0
        DUT.IMEM.instr_mem[1] = enc_fpu(5, 3, 2, 3'b001); // +0.0
        DUT.IMEM.instr_mem[2] = enc_fpu(6, 1, 1, 3'b000); // -2.0

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 21: FPU NEGATIVE / ZERO");
        $display("============================================================");

        check_reg(4, 16'hC000);
        check_reg(5, 16'h0000);
        check_reg(6, 16'hC000);

        // ========================================================
        // FINAL SUMMARY
        // ========================================================

        $display("\n============================================================");
        $display("FULL 16-BIT PIPELINED CPU REGRESSION SUMMARY");
        $display("============================================================");
        $display("PASS COUNT = %0d", pass_count);
        $display("FAIL COUNT = %0d", fail_count);

        // ============================================================
// TEST 22: ALU RESULT -> SH STORE-DATA FORWARDING
//
// ADD R3,R1,R2   -> R3 = 10 + 20 = 30
// SH  R3,0(R4)   -> MEM[0] = 30
// LH  R5,0(R4)   -> R5 = 30
// ============================================================

    $display("\nTEST 22: ALU result -> SH store-data forwarding");

    // Initialize registers
    DUT.RF.registers[1] = 16'd10;
    DUT.RF.registers[2] = 16'd20;
    DUT.RF.registers[3] = 16'd0;
    DUT.RF.registers[4] = 16'd0;
    DUT.RF.registers[5] = 16'd0;

    // Clear memory location
    DUT.DMEM.memory[0] = 16'd0;

    // Program
    // PC0: ADD R3,R1,R2
    // PC1: SH  R3,0(R4)
    // PC2: LH  R5,0(R4)

    DUT.IMEM.instr_mem[0] = enc_r(3, 1, 2, 3'b000);
    DUT.IMEM.instr_mem[1] = enc_i(3'b010, 3, 4, 4'sd0, 3'b010);
    DUT.IMEM.instr_mem[2] = enc_i(3'b001, 5, 4, 4'sd0, 3'b010);

    // Reset
    rst = 1'b1;
    repeat (2) @(posedge clk);
    rst = 1'b0;

    // Allow pipeline to complete
    repeat (10) @(posedge clk);

    // Check ADD
    if (DUT.RF.registers[3] == 16'd30)
        $display("PASS: ADD produced R3 = 30");
    else begin
        $display("FAIL: R3 expected 30, got %0d",
                DUT.RF.registers[3]);
        fail_count = fail_count + 1;
    end

    // Check SH
    if (DUT.DMEM.memory[0] == 16'd30)
        $display("PASS: SH stored 30 into MEM[0]");
    else begin
        $display("FAIL: MEM[0] expected 30, got %0d",
                DUT.DMEM.memory[0]);
        fail_count = fail_count + 1;
    end

    // Check LH
    if (DUT.RF.registers[5] == 16'd30)
        $display("PASS: LH loaded R5 = 30");
    else begin
        $display("FAIL: R5 expected 30, got %0d",
                DUT.RF.registers[5]);
        fail_count = fail_count + 1;
    end

    if ((DUT.RF.registers[3] == 16'd30) &&
        (DUT.DMEM.memory[0] == 16'd30) &&
        (DUT.RF.registers[5] == 16'd30))
        $display("PASS: ALU -> SH store-data forwarding");

            if (fail_count == 0)
                $display("ALL PIPELINE REGRESSION TESTS PASSED");
            else
                $display("PIPELINE REGRESSION HAS FAILURES");

            $display("============================================================");

        #20;
        $finish;
    end

    

    // ============================================================
    // OPTIONAL CYCLE DEBUG
    // ============================================================

    always @(posedge clk) begin
        if (DEBUG && !rst) begin
            #1;
            $display(
                "TIME=%0t PC=%h INSTR=%h IDPC=%h EXPC=%h FWD_A=%b FWD_B=%b BR=%b TARGET=%h FPU_EN=%b FPU_OP=%b RESULT=%h",
                $time,
                DUT.pc_out,
                DUT.instr,
                DUT.if_id_pc,
                DUT.id_ex_pc,
                DUT.forward_a,
                DUT.forward_b,
                DUT.ex_branch_taken,
                DUT.ex_branch_target,
                DUT.id_ex_fpu_enable,
                DUT.id_ex_fpu_opcode,
                DUT.ex_result
            );
        end
    end

endmodule
