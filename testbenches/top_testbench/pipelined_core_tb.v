`timescale 1ns / 1ps

module pipelined_core_tb;

    reg clk;
    reg rst;

    integer pass_count;
    integer fail_count;

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
    // ===========================================================

    // ============================================================
    // ISA ENCODERS
    // ============================================================

    // ------------------------------------------------------------
    // R-TYPE
    //
    // [15]    = 0
    // [14:12] = 000
    // [11:9]  = Rd
    // [8:6]   = Rs1
    // [5:3]   = Rs2
    // [2:0]   = funct
    // ------------------------------------------------------------

    function [15:0] enc_r;
        input [2:0] rd;
        input [2:0] rs1;
        input [2:0] rs2;
        input [2:0] funct;
        begin
            enc_r = {
                1'b0,
                3'b000,
                rd,
                rs1,
                rs2,
                funct
            };
        end
    endfunction

    // ------------------------------------------------------------
    // I-TYPE / LH / SH
    //
    // [15]    = imm[3]
    // [14:12] = opcode
    // [11:9]  = Rd / store data register
    // [8:6]   = Rs1
    // [5:3]   = imm[2:0]
    // [2:0]   = funct
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // BRANCH
    //
    // [15]    = offset[3]
    // [14:12] = 100
    // [11:9]  = Rs1
    // [8:6]   = Rs2
    // [5:3]   = offset[2:0]
    // [2:0]   = funct
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // JAL
    //
    // [15]    = offset[3]
    // [14:12] = 101
    // [11:9]  = Rd
    // [8:6]   = 000
    // [5:3]   = offset[2:0]
    // [2:0]   = 001
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // JALR
    //
    // [15]    = imm[3]
    // [14:12] = 111
    // [11:9]  = Rd
    // [8:6]   = Rs1
    // [5:3]   = imm[2:0]
    // [2:0]   = 000
    // ------------------------------------------------------------

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

    // ------------------------------------------------------------
    // FPU
    //
    // opcode = 110
    //
    // funct 000 = FADD
    // funct 001 = FMUL
    // ------------------------------------------------------------

    function [15:0] enc_fpu;
        input [2:0] rd;
        input [2:0] rs1;
        input [2:0] rs2;
        input [2:0] funct;
        begin
            enc_fpu = {
                1'b0,
                3'b110,
                rd,
                rs1,
                rs2,
                funct
            };
        end
    endfunction

    // ------------------------------------------------------------
    // CRYPTO
    //
    // opcode = 110
    //
    // funct 010 = ENC
    // funct 011 = DEC
    //
    // [15]    = 0
    // [14:12] = 110
    // [11:9]  = Rd
    // [8:6]   = Rs1
    // [5:3]   = 000
    // [2:0]   = funct
    // ------------------------------------------------------------

    function [15:0] enc_crypto;
        input [2:0] rd;
        input [2:0] rs1;
        input decrypt;

        begin
            enc_crypto = {
                1'b0,
                3'b110,
                rd,
                rs1,
                3'b000,
                decrypt ? 3'b011 : 3'b010
            };
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
                $display(
                    "PASS: R%0d = %h",
                    reg_num,
                    expected
                );
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
                $display(
                    "PASS: MEM[%0d] = %h",
                    addr,
                    expected
                );
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

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'd5;
        DUT.RF.registers[2] = 16'd10;

        DUT.IMEM.instr_mem[0] = enc_r(3, 1, 2, 3'b000);
        DUT.IMEM.instr_mem[1] = enc_r(4, 2, 1, 3'b001);
        DUT.IMEM.instr_mem[2] = enc_r(5, 1, 2, 3'b010);
        DUT.IMEM.instr_mem[3] = enc_r(6, 1, 2, 3'b100);
        DUT.IMEM.instr_mem[4] = enc_r(7, 1, 2, 3'b110);

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

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h8000;
        DUT.RF.registers[2] = 16'h0001;

        DUT.IMEM.instr_mem[0] = enc_r(3, 1, 2, 3'b101);
        DUT.IMEM.instr_mem[1] = enc_r(4, 1, 2, 3'b011);
        DUT.IMEM.instr_mem[2] = enc_r(5, 1, 2, 3'b111);

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

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'hFFFF;
        DUT.RF.registers[2] = 16'h0001;
        DUT.RF.registers[3] = 16'h0001;

        DUT.IMEM.instr_mem[0] =
            enc_r(4, 1, 2, 3'b010);

        DUT.IMEM.instr_mem[1] =
            enc_i(3'b011, 5, 1, 4'sd1, 3'b010);

        DUT.IMEM.instr_mem[2] =
            enc_i(3'b011, 6, 3, -4'sd1, 3'b010);

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

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h000A;

        DUT.IMEM.instr_mem[0] =
            enc_i(3'b011, 3, 1, 4'sd3, 3'b000);

        DUT.IMEM.instr_mem[1] =
            enc_i(3'b011, 4, 1, 4'sd3, 3'b001);

        DUT.IMEM.instr_mem[2] =
            enc_i(3'b011, 5, 1, 4'sd3, 3'b100);

        DUT.IMEM.instr_mem[3] =
            enc_i(3'b011, 6, 1, 4'sd3, 3'b110);

        DUT.IMEM.instr_mem[4] =
            enc_i(3'b011, 7, 1, -4'sd3, 3'b000);

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

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h000A;
        DUT.RF.registers[2] = 16'h8000;

        DUT.IMEM.instr_mem[0] =
            enc_i(3'b011, 3, 1, 4'sd3, 3'b101);

        DUT.IMEM.instr_mem[1] =
            enc_i(3'b011, 4, 2, 4'sd3, 3'b011);

        DUT.IMEM.instr_mem[2] =
            enc_i(3'b011, 5, 2, 4'sd3, 3'b111);

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

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[3] = 16'h1234;

        DUT.IMEM.instr_mem[0] =
            enc_i(3'b011, 2, 0, 4'sd4, 3'b000);

        DUT.IMEM.instr_mem[1] =
            enc_i(3'b010, 3, 2, 4'sd2, 3'b010);

        DUT.IMEM.instr_mem[2] =
            enc_i(3'b001, 4, 2, 4'sd2, 3'b010);

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

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[2] = 16'd10;
        DUT.RF.registers[3] = 16'd20;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] =
            enc_r(1, 2, 3, 3'b000);

        DUT.IMEM.instr_mem[1] =
            enc_r(4, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[2] =
            enc_r(7, 4, 1, 3'b001);

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

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[2] = 16'd0;
        DUT.RF.registers[4] = 16'd5;

        DUT.DMEM.memory[0] = 16'd10;

        DUT.IMEM.instr_mem[0] =
            enc_i(3'b001, 1, 2, 4'sd0, 3'b010);

        DUT.IMEM.instr_mem[1] =
            enc_r(3, 1, 4, 3'b000);

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

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[2] = 16'd0;
        DUT.RF.registers[3] = 16'd20;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.DMEM.memory[0] = 16'd10;

        DUT.IMEM.instr_mem[0] =
            enc_i(3'b001, 1, 2, 4'sd0, 3'b010);

        DUT.IMEM.instr_mem[1] =
            enc_b(1, 1, 4'sd2, 3'b000);

        DUT.IMEM.instr_mem[2] =
            enc_r(4, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[3] =
            enc_r(7, 1, 3, 3'b000);

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

        DUT.IMEM.instr_mem[0] =
            enc_b(1, 2, 4'sd2, 3'b000);

        DUT.IMEM.instr_mem[1] =
            enc_r(4, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[2] =
            enc_r(7, 1, 2, 3'b000);

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

        DUT.IMEM.instr_mem[0] =
            enc_b(1, 2, 4'sd2, 3'b000);

        DUT.IMEM.instr_mem[1] =
            enc_r(4, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[2] =
            enc_r(7, 5, 6, 3'b000);

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

        DUT.IMEM.instr_mem[0] =
            enc_b(1, 2, 4'sd2, 3'b001);

        DUT.IMEM.instr_mem[1] =
            enc_r(4, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[2] =
            enc_r(7, 5, 6, 3'b000);

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

        DUT.IMEM.instr_mem[0] =
            enc_b(1, 2, 4'sd2, 3'b100);

        DUT.IMEM.instr_mem[1] =
            enc_r(4, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[2] =
            enc_r(7, 5, 6, 3'b000);

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

        DUT.IMEM.instr_mem[0] =
            enc_b(1, 2, 4'sd2, 3'b011);

        DUT.IMEM.instr_mem[1] =
            enc_r(4, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[2] =
            enc_r(7, 5, 6, 3'b000);

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

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[2] = 16'd10;
        DUT.RF.registers[3] = 16'd20;
        DUT.RF.registers[4] = 16'd30;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] =
            enc_r(1, 2, 3, 3'b000);

        DUT.IMEM.instr_mem[1] =
            enc_b(1, 4, 4'sd2, 3'b000);

        DUT.IMEM.instr_mem[2] =
            enc_r(7, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[3] =
            enc_r(7, 5, 6, 3'b000);

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 15: BRANCH FORWARDING FROM ALU RESULT");
        $display("============================================================");

        check_reg(7, 16'h000F);

        // ========================================================
        // TEST 16: JAL
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] =
            enc_jal(1, 4'sd4);

        DUT.IMEM.instr_mem[1] =
            enc_r(4, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[2] =
            enc_r(4, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[3] =
            enc_r(4, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[4] =
            enc_r(7, 5, 6, 3'b000);

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 16: JAL");
        $display("============================================================");

        check_reg(1, 16'h0001);
        check_reg(4, 16'h0000);
        check_reg(7, 16'h000F);

        // ========================================================
        // TEST 17: JALR DIRECT TARGET
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[2] = 16'd4;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] =
            enc_jalr(1, 2, 4'sd2);

        DUT.IMEM.instr_mem[1] =
            enc_r(7, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[2] =
            enc_r(7, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[3] =
            enc_r(7, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[4] =
            enc_r(7, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[5] =
            enc_r(7, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[6] =
            enc_r(7, 5, 6, 3'b000);

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

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[3] = 16'd2;
        DUT.RF.registers[4] = 16'd2;
        DUT.RF.registers[5] = 16'd7;
        DUT.RF.registers[6] = 16'd8;

        DUT.IMEM.instr_mem[0] =
            enc_r(2, 3, 4, 3'b000);

        DUT.IMEM.instr_mem[1] =
            enc_jalr(1, 2, 4'sd2);

        DUT.IMEM.instr_mem[2] =
            enc_r(7, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[3] =
            enc_r(7, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[4] =
            enc_r(7, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[5] =
            enc_r(7, 5, 6, 3'b000);

        DUT.IMEM.instr_mem[6] =
            enc_r(7, 5, 6, 3'b000);

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

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h3C00;
        DUT.RF.registers[2] = 16'h4000;

        DUT.IMEM.instr_mem[0] =
            enc_fpu(3, 1, 2, 3'b000);

        DUT.IMEM.instr_mem[1] =
            enc_fpu(4, 3, 1, 3'b000);

        DUT.IMEM.instr_mem[2] =
            enc_fpu(5, 4, 2, 3'b001);

        DUT.IMEM.instr_mem[3] =
            enc_fpu(6, 5, 1, 3'b000);

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

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h3C00;
        DUT.RF.registers[2] = 16'hBC00;
        DUT.RF.registers[3] = 16'h3E00;
        DUT.RF.registers[4] = 16'h4000;

        DUT.IMEM.instr_mem[0] =
            enc_fpu(5, 1, 2, 3'b000);

        DUT.IMEM.instr_mem[1] =
            enc_fpu(6, 3, 3, 3'b000);

        DUT.IMEM.instr_mem[2] =
            enc_fpu(7, 1, 4, 3'b001);

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

        DUT.RF.registers[1] = 16'hBC00;
        DUT.RF.registers[2] = 16'h4000;
        DUT.RF.registers[3] = 16'h0000;

        DUT.IMEM.instr_mem[0] =
            enc_fpu(4, 1, 2, 3'b001);

        DUT.IMEM.instr_mem[1] =
            enc_fpu(5, 3, 2, 3'b001);

        DUT.IMEM.instr_mem[2] =
            enc_fpu(6, 1, 1, 3'b000);

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 21: FPU NEGATIVE / ZERO");
        $display("============================================================");

        check_reg(4, 16'hC000);
        check_reg(5, 16'h0000);
        check_reg(6, 16'hC000);

        // ========================================================
        // TEST 22: ALU RESULT -> SH STORE-DATA FORWARDING
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'd10;
        DUT.RF.registers[2] = 16'd20;

        DUT.IMEM.instr_mem[0] =
            enc_r(3, 1, 2, 3'b000);

        DUT.IMEM.instr_mem[1] =
            enc_i(3'b010, 3, 4, 4'sd0, 3'b010);

        DUT.IMEM.instr_mem[2] =
            enc_i(3'b001, 5, 4, 4'sd0, 3'b010);

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 22: ALU -> SH STORE-DATA FORWARDING");
        $display("============================================================");

        check_reg(3, 16'h001E);
        check_mem(8'd0, 16'h001E);
        check_reg(5, 16'h001E);

        // ========================================================
        // TEST 23: CRYPTO ENC KNOWN VECTORS
        //
        // 0000 -> 06FB
        // 0001 -> C371
        // 1234 -> 6479
        // ABCD -> D864
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h0000;
        DUT.RF.registers[2] = 16'h0001;
        DUT.RF.registers[3] = 16'h1234;
        DUT.RF.registers[4] = 16'hABCD;

        DUT.IMEM.instr_mem[0] =
            enc_crypto(5, 1, 1'b0);

        DUT.IMEM.instr_mem[1] =
            enc_crypto(6, 2, 1'b0);

        DUT.IMEM.instr_mem[2] =
            enc_crypto(7, 3, 1'b0);

        DUT.IMEM.instr_mem[3] =
            enc_crypto(0, 4, 1'b0);

        reset_cpu;
        run_cycles(12);

        $display("\n============================================================");
        $display("TEST 23: CRYPTO ENC KNOWN VECTORS");
        $display("============================================================");

        check_reg(5, 16'h06FB);
        check_reg(6, 16'hC371);
        check_reg(7, 16'h6479);
        check_reg(0, 16'h0000);

        // ========================================================
        // TEST 24: CRYPTO DEC KNOWN VECTORS
        //
        // 06FB -> 0000
        // C371 -> 0001
        // 6479 -> 1234
        // D864 -> ABCD
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h06FB;
        DUT.RF.registers[2] = 16'hC371;
        DUT.RF.registers[3] = 16'h6479;
        DUT.RF.registers[4] = 16'hD864;

        DUT.IMEM.instr_mem[0] =
            enc_crypto(5, 1, 1'b1);

        DUT.IMEM.instr_mem[1] =
            enc_crypto(6, 2, 1'b1);

        DUT.IMEM.instr_mem[2] =
            enc_crypto(7, 3, 1'b1);

        DUT.IMEM.instr_mem[3] =
            enc_crypto(0, 4, 1'b1);

        reset_cpu;
        run_cycles(12);

        $display("\n============================================================");
        $display("TEST 24: CRYPTO DEC KNOWN VECTORS");
        $display("============================================================");

        check_reg(5, 16'h0000);
        check_reg(6, 16'h0001);
        check_reg(7, 16'h1234);
        check_reg(0, 16'h0000);

        // ========================================================
        // TEST 25: ENC -> DEC FORWARDING
        //
        // R3 = ENC(1234) = 6479
        // R4 = DEC(R3)  = 1234
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h1234;

        DUT.IMEM.instr_mem[0] =
            enc_crypto(3, 1, 1'b0);

        DUT.IMEM.instr_mem[1] =
            enc_crypto(4, 3, 1'b1);

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 25: ENC -> DEC FORWARDING");
        $display("============================================================");

        check_reg(3, 16'h6479);
        check_reg(4, 16'h1234);

        // ========================================================
        // TEST 26: ALU -> ENC FORWARDING
        //
        // R3 = 1000 + 0234 = 1234
        // R4 = ENC(1234) = 6479
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h1000;
        DUT.RF.registers[2] = 16'h0234;

        DUT.IMEM.instr_mem[0] =
            enc_r(3, 1, 2, 3'b000);

        DUT.IMEM.instr_mem[1] =
            enc_crypto(4, 3, 1'b0);

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 26: ALU -> ENC FORWARDING");
        $display("============================================================");

        check_reg(3, 16'h1234);
        check_reg(4, 16'h6479);

        // ========================================================
        // TEST 27: ENC -> ALU FORWARDING
        //
        // R3 = ENC(1234) = 6479
        // R4 = R3 + 1 = 647A
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h1234;
        DUT.RF.registers[2] = 16'h0001;

        DUT.IMEM.instr_mem[0] =
            enc_crypto(3, 1, 1'b0);

        DUT.IMEM.instr_mem[1] =
            enc_r(4, 3, 2, 3'b000);

        reset_cpu;
        run_cycles(10);

        $display("\n============================================================");
        $display("TEST 27: ENC -> ALU FORWARDING");
        $display("============================================================");

        check_reg(3, 16'h6479);
        check_reg(4, 16'h647A);

        // ========================================================
        // TEST 28: ENC -> SH STORE-DATA FORWARDING
        //
        // R3 = ENC(1234)
        // SH R3,0(R2)
        // LH R4,0(R2)
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h1234;
        DUT.RF.registers[2] = 16'h0000;

        DUT.IMEM.instr_mem[0] =
            enc_crypto(3, 1, 1'b0);

        DUT.IMEM.instr_mem[1] =
            enc_i(3'b010, 3, 2, 4'sd0, 3'b010);

        DUT.IMEM.instr_mem[2] =
            enc_i(3'b001, 4, 2, 4'sd0, 3'b010);

        reset_cpu;
        run_cycles(12);

        $display("\n============================================================");
        $display("TEST 28: ENC -> SH STORE-DATA FORWARDING");
        $display("============================================================");

        check_reg(3, 16'h6479);
        check_mem(8'd0, 16'h6479);
        check_reg(4, 16'h6479);

        // ========================================================
        // TEST 29: DEC -> SH STORE-DATA FORWARDING
        //
        // R3 = DEC(6479) = 1234
        // SH R3,0(R2)
        // LH R4,0(R2)
        // ========================================================

        clear_instruction_memory;
        clear_data_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h6479;
        DUT.RF.registers[2] = 16'h0000;

        DUT.IMEM.instr_mem[0] =
            enc_crypto(3, 1, 1'b1);

        DUT.IMEM.instr_mem[1] =
            enc_i(3'b010, 3, 2, 4'sd0, 3'b010);

        DUT.IMEM.instr_mem[2] =
            enc_i(3'b001, 4, 2, 4'sd0, 3'b010);

        reset_cpu;
        run_cycles(12);

        $display("\n============================================================");
        $display("TEST 29: DEC -> SH STORE-DATA FORWARDING");
        $display("============================================================");

        check_reg(3, 16'h1234);
        check_mem(8'd0, 16'h1234);
        check_reg(4, 16'h1234);

        // ========================================================
        // FINAL SUMMARY
        // ========================================================

        $display("\n============================================================");
        $display("FULL 16-BIT PIPELINED CPU REGRESSION SUMMARY");
        $display("============================================================");

        $display("PASS COUNT = %0d", pass_count);
        $display("FAIL COUNT = %0d", fail_count);

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
                "TIME=%0t PC=%h INSTR=%h IDPC=%h EXPC=%h FWD_A=%b FWD_B=%b BR=%b TARGET=%h FPU_EN=%b FPU_OP=%b CRYPTO_EN=%b CRYPTO_DEC=%b RESULT=%h",
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
                DUT.id_ex_crypto_enable,
                DUT.id_ex_crypto_dec,
                DUT.ex_result
            );

        end

    end

endmodule
