`timescale 1ns / 1ps

module single_cycle_core_tb;

    reg clk;
    reg rst;

    // ==========================================================
    // DUT
    // ==========================================================

    single_cycle_core DUT (
        .clk(clk),
        .rst(rst)
    );

    // ==========================================================
    // Standalone FPU for TEST 11
    // ==========================================================

    reg         fpu_test_enable;
    reg [3:0]   fpu_test_opcode;
    reg [15:0]  fpu_test_a;
    reg [15:0]  fpu_test_b;
    wire [15:0] fpu_test_result;

    fpu FPU_TEST (
        .enable  (fpu_test_enable),
        .a       (fpu_test_a),
        .b       (fpu_test_b),
        .opcode  (fpu_test_opcode),
        .result  (fpu_test_result)
    );

    // ==========================================================
    // Clock
    // ==========================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ==========================================================
    // Register initialization
    // ==========================================================

    task init_registers;
        begin
            DUT.RF.registers[0] = 16'h0000;
            DUT.RF.registers[1] = 16'h0008;
            DUT.RF.registers[2] = 16'h0002;
            DUT.RF.registers[3] = 16'h0000;
            DUT.RF.registers[4] = 16'h0000;
            DUT.RF.registers[5] = 16'h0000;
            DUT.RF.registers[6] = 16'h0009;
            DUT.RF.registers[7] = 16'h0003;
        end
    endtask

    // ==========================================================
    // Clear instruction memory
    // ==========================================================

    integer i;

    task clear_instruction_memory;
        begin
            for (i = 0; i < 256; i = i + 1)
                DUT.IMEM.instr_mem[i] = 16'h0000;
        end
    endtask

    // ==========================================================
    // Reset CPU
    // ==========================================================

    task reset_cpu;
        begin
            rst = 1'b1;

            repeat (2) begin
                @(posedge clk);
                #1;
            end

            rst = 1'b0;
            #1;
        end
    endtask

    // ==========================================================
    // Main tests
    // ==========================================================

    initial begin

        rst = 1'b1;

        // ======================================================
        // TEST 1: R-TYPE
        // ======================================================

        clear_instruction_memory;
        init_registers;

        // ADD R1,R2,R3
        DUT.IMEM.instr_mem[0] = 16'h0298;

        // SUB R2,R3,R1
        DUT.IMEM.instr_mem[1] = 16'h04C9;

        // SLT R3,R4,R5
        DUT.IMEM.instr_mem[2] = 16'h072A;

        // OR R1,R2,R3
        DUT.IMEM.instr_mem[3] = 16'h029C;

        // AND R1,R2,R3
        DUT.IMEM.instr_mem[4] = 16'h029E;

        // SRL R1,R2,R3
        DUT.IMEM.instr_mem[5] = 16'h029B;

        // SLL R1,R2,R3
        DUT.IMEM.instr_mem[6] = 16'h029D;

        // SRA R1,R2,R3
        DUT.IMEM.instr_mem[7] = 16'h029F;

        reset_cpu;

        $display("");
        $display("==============================================");
        $display("TEST 1: R-TYPE");
        $display("==============================================");

        repeat (8) begin
            @(posedge clk);
            #1;

            $display(
                "PC=%h INSTR=%h RD1=%h RD2=%h ALUCTRL=%h ALUOUT=%h",
                DUT.pc_out,
                DUT.instr,
                DUT.rd_data1,
                DUT.rd_data2,
                DUT.alu_ctrl,
                DUT.alu_out
            );
        end

        // ======================================================
        // TEST 2: IMMEDIATE
        // ======================================================

        clear_instruction_memory;
        init_registers;

        // ADDI R1,R2,3
        DUT.IMEM.instr_mem[0] = 16'h3298;

        // SUBI R2,R3,1
        DUT.IMEM.instr_mem[1] = 16'h34C9;

        // SLTI R3,R4,5
        DUT.IMEM.instr_mem[2] = 16'h372A;

        // ORI R1,R2,3
        DUT.IMEM.instr_mem[3] = 16'h329C;

        // ANDI R1,R2,3
        DUT.IMEM.instr_mem[4] = 16'h329E;

        // SRLI R1,R2,3
        DUT.IMEM.instr_mem[5] = 16'h329B;

        // SLLI R1,R2,3
        DUT.IMEM.instr_mem[6] = 16'h329D;

        // SRAI R1,R2,3
        DUT.IMEM.instr_mem[7] = 16'h329F;

        reset_cpu;

        $display("");
        $display("==============================================");
        $display("TEST 2: IMMEDIATE");
        $display("==============================================");

        repeat (8) begin
            @(posedge clk);
            #1;

            $display(
                "PC=%h INSTR=%h RD1=%h IMM=%h ALUCTRL=%h ALUB=%h ALUOUT=%h",
                DUT.pc_out,
                DUT.instr,
                DUT.rd_data1,
                DUT.imm_out,
                DUT.alu_ctrl,
                DUT.alu_b_input,
                DUT.alu_out
            );
        end

        // ======================================================
        // TEST 3: LOAD / STORE
        // ======================================================

        clear_instruction_memory;
        init_registers;

        // SH R1,3(R2)
        DUT.IMEM.instr_mem[0] = 16'h229A;

        // LH R1,3(R2)
        DUT.IMEM.instr_mem[1] = 16'h129A;

        reset_cpu;

        $display("");
        $display("==============================================");
        $display("TEST 3: LOAD / STORE");
        $display("==============================================");

        repeat (2) begin
            @(posedge clk);
            #1;

            $display(
                "PC=%h INSTR=%h RD1=%h RD2=%h IMM=%h ADDR=%h MEMR=%b MEMW=%b MEMDATA=%h",
                DUT.pc_out,
                DUT.instr,
                DUT.rd_data1,
                DUT.rd_data2,
                DUT.imm_out,
                DUT.alu_out,
                DUT.mem_read,
                DUT.mem_write,
                DUT.mem_data
            );
        end

        // ======================================================
        // TEST 4: BEQ
        // ======================================================

        clear_instruction_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h0002;
        DUT.RF.registers[2] = 16'h0002;

        // BEQ R1,R2,3
        DUT.IMEM.instr_mem[0] = 16'h4298;

        // Instructions that should be skipped
        DUT.IMEM.instr_mem[1] = 16'h3298;
        DUT.IMEM.instr_mem[2] = 16'h3298;

        // Branch target
        DUT.IMEM.instr_mem[3] = 16'h3228;

        reset_cpu;

        $display("");
        $display("==============================================");
        $display("TEST 4: BEQ");
        $display("==============================================");

        repeat (4) begin
            @(posedge clk);
            #1;

            $display(
                "PC=%h INSTR=%h RS1=%h RS2=%h IMM=%h BR=%b NEXT_PC=%h",
                DUT.pc_out,
                DUT.instr,
                DUT.rd_data1,
                DUT.rd_data2,
                DUT.imm_out,
                DUT.branch,
                DUT.next_pc
            );
        end

        // ======================================================
        // TEST 5: BNE
        // ======================================================

        clear_instruction_memory;
        init_registers;

        DUT.RF.registers[1] = 16'h0009;
        DUT.RF.registers[2] = 16'h0003;

        // BNE R5,R6,4
        DUT.IMEM.instr_mem[0] = 16'h4BA1;

        DUT.IMEM.instr_mem[1] = 16'h3208;
        DUT.IMEM.instr_mem[2] = 16'h3410;
        DUT.IMEM.instr_mem[3] = 16'h0650;
        DUT.IMEM.instr_mem[4] = 16'h0F76;

        reset_cpu;

        $display("");
        $display("==============================================");
        $display("TEST 5: BNE");
        $display("==============================================");

        repeat (5) begin
            @(posedge clk);
            #1;

            $display(
                "PC=%h INSTR=%h RS1=%h RS2=%h IMM=%h NEXT_PC=%h",
                DUT.pc_out,
                DUT.instr,
                DUT.rd_data1,
                DUT.rd_data2,
                DUT.imm_out,
                DUT.next_pc
            );
        end

        // ======================================================
        // TEST 6: BLT
        // ======================================================

        clear_instruction_memory;
        init_registers;

        // ADDI R1,R0,2
        DUT.IMEM.instr_mem[0] = 16'h3210;

        // ADDI R2,R0,5
        DUT.IMEM.instr_mem[1] = 16'h3428;

        // BLT R1,R2,3
        DUT.IMEM.instr_mem[2] = 16'h429C;

        DUT.IMEM.instr_mem[3] = 16'h0650;
        DUT.IMEM.instr_mem[4] = 16'h0889;
        DUT.IMEM.instr_mem[5] = 16'h3A08;

        reset_cpu;

        $display("");
        $display("==============================================");
        $display("TEST 6: BLT");
        $display("==============================================");

        repeat (6) begin
            @(posedge clk);
            #1;

            $display(
                "PC=%h INSTR=%h RS1=%h RS2=%h IMM=%h NEXT_PC=%h",
                DUT.pc_out,
                DUT.instr,
                DUT.rd_data1,
                DUT.rd_data2,
                DUT.imm_out,
                DUT.next_pc
            );
        end

        // ======================================================
        // TEST 7: BGE
        // ======================================================

        clear_instruction_memory;
        init_registers;

        // ADDI R1,R0,5
        DUT.IMEM.instr_mem[0] = 16'h3228;

        // ADDI R2,R0,2
        DUT.IMEM.instr_mem[1] = 16'h3410;

        // BGE R1,R2,3
        DUT.IMEM.instr_mem[2] = 16'h429B;

        DUT.IMEM.instr_mem[3] = 16'h0651;
        DUT.IMEM.instr_mem[4] = 16'h0856;
        DUT.IMEM.instr_mem[5] = 16'hB608;

        reset_cpu;

        $display("");
        $display("==============================================");
        $display("TEST 7: BGE");
        $display("==============================================");

        repeat (6) begin
            @(posedge clk);
            #1;

            $display(
                "PC=%h INSTR=%h RS1=%h RS2=%h IMM=%h NEXT_PC=%h",
                DUT.pc_out,
                DUT.instr,
                DUT.rd_data1,
                DUT.rd_data2,
                DUT.imm_out,
                DUT.next_pc
            );
        end

        // ======================================================
        // TEST 8: JAL
        // ======================================================

        clear_instruction_memory;
        init_registers;

        // JAL R2,4
        DUT.IMEM.instr_mem[0] = 16'h5421;

        // Skipped
        DUT.IMEM.instr_mem[1] = 16'h3298;
        DUT.IMEM.instr_mem[2] = 16'h3298;
        DUT.IMEM.instr_mem[3] = 16'h3298;

        // Target
        DUT.IMEM.instr_mem[4] = 16'h3228;

        reset_cpu;

        $display("");
        $display("==============================================");
        $display("TEST 8: JAL");
        $display("==============================================");

        repeat (5) begin
            @(posedge clk);
            #1;

            $display(
                "PC=%h INSTR=%h IMM=%h JUMP=%b NEXT_PC=%h R2=%h",
                DUT.pc_out,
                DUT.instr,
                DUT.imm_out,
                DUT.jump,
                DUT.next_pc,
                DUT.RF.registers[2]
            );
        end

        // ======================================================
        // TEST 9: JALR
        // ======================================================

        clear_instruction_memory;
        init_registers;

        // R1 = 2
        DUT.RF.registers[1] = 16'h0002;

        // JALR R3,R1,2
        // Target = R1 + 2 = 4
        DUT.IMEM.instr_mem[0] = 16'h7650;

        DUT.IMEM.instr_mem[1] = 16'h3298;
        DUT.IMEM.instr_mem[2] = 16'h3298;
        DUT.IMEM.instr_mem[3] = 16'h3298;

        // Target
        DUT.IMEM.instr_mem[4] = 16'h3228;

        reset_cpu;

        $display("");
        $display("==============================================");
        $display("TEST 9: JALR");
        $display("==============================================");

        repeat (5) begin
            @(posedge clk);
            #1;

            $display(
                "PC=%h INSTR=%h RS1=%h IMM=%h JALR=%b NEXT_PC=%h R3=%h",
                DUT.pc_out,
                DUT.instr,
                DUT.rd_data1,
                DUT.imm_out,
                DUT.jalr,
                DUT.next_pc,
                DUT.RF.registers[3]
            );
        end

        // ======================================================
        // TEST 10: FPU CPU INTEGRATION
        // ======================================================

        $display("");
        $display("==============================================");
        $display("TEST 10: FPU CPU INTEGRATION");
        $display("==============================================");

        clear_instruction_memory;
        init_registers;

        // FADD R3,R1,R2
        DUT.IMEM.instr_mem[0] = 16'h6650;

        // FMUL R4,R1,R2
        DUT.IMEM.instr_mem[1] = 16'h6851;

        reset_cpu;

        // R1 = 1.0
        DUT.RF.registers[1] = 16'h3C00;

        // R2 = 2.0
        DUT.RF.registers[2] = 16'h4000;

        // ------------------------------------------------------
        // FADD: 1.0 + 2.0 = 3.0
        // ------------------------------------------------------

        @(posedge clk);
        #1;

        if (DUT.RF.registers[3] === 16'h4200)
            $display("PASS: FADD 1.0 + 2.0 = 3.0");
        else
            $display(
                "FAIL: FADD expected 4200, got %h",
                DUT.RF.registers[3]
            );

        // ------------------------------------------------------
        // FMUL: 1.0 * 2.0 = 2.0
        // ------------------------------------------------------

        @(posedge clk);
        #1;

        if (DUT.RF.registers[4] === 16'h4000)
            $display("PASS: FMUL 1.0 * 2.0 = 2.0");
        else
            $display(
                "FAIL: FMUL expected 4000, got %h",
                DUT.RF.registers[4]
            );

        // ======================================================
        // TEST 11: STANDALONE FPU ARITHMETIC
        // ======================================================

        $display("");
        $display("==============================================");
        $display("TEST 11: STANDALONE FPU ARITHMETIC");
        $display("==============================================");

        fpu_test_enable = 1'b1;

        // ------------------------------------------------------
        // 1.0 + (-1.0) = 0.0
        // ------------------------------------------------------

        fpu_test_opcode = 4'b0000;
        fpu_test_a = 16'h3C00;
        fpu_test_b = 16'hBC00;

        #1;

        if (fpu_test_result === 16'h0000)
            $display("PASS: 1.0 + (-1.0) = 0.0");
        else
            $display(
                "FAIL: 1.0 + (-1.0), got %h",
                fpu_test_result
            );

        // ------------------------------------------------------
        // 1.5 + 1.5 = 3.0
        // ------------------------------------------------------

        fpu_test_a = 16'h3E00;
        fpu_test_b = 16'h3E00;

        #1;

        if (fpu_test_result === 16'h4200)
            $display("PASS: 1.5 + 1.5 = 3.0");
        else
            $display(
                "FAIL: 1.5 + 1.5, got %h",
                fpu_test_result
            );

        // ------------------------------------------------------
        // 1.0 * 2.0 = 2.0
        // ------------------------------------------------------

        fpu_test_opcode = 4'b0001;
        fpu_test_a = 16'h3C00;
        fpu_test_b = 16'h4000;

        #1;

        if (fpu_test_result === 16'h4000)
            $display("PASS: 1.0 * 2.0 = 2.0");
        else
            $display(
                "FAIL: 1.0 * 2.0, got %h",
                fpu_test_result
            );

        // ------------------------------------------------------
        // 1.5 * 2.0 = 3.0
        // ------------------------------------------------------

        fpu_test_a = 16'h3E00;
        fpu_test_b = 16'h4000;

        #1;

        if (fpu_test_result === 16'h4200)
            $display("PASS: 1.5 * 2.0 = 3.0");
        else
            $display(
                "FAIL: 1.5 * 2.0, got %h",
                fpu_test_result
            );

        // ------------------------------------------------------
        // -1.0 * 2.0 = -2.0
        // ------------------------------------------------------

        fpu_test_a = 16'hBC00;
        fpu_test_b = 16'h4000;

        #1;

        if (fpu_test_result === 16'hC000)
            $display("PASS: -1.0 * 2.0 = -2.0");
        else
            $display(
                "FAIL: -1.0 * 2.0, got %h",
                fpu_test_result
            );

        // ------------------------------------------------------
        // 0.0 * 2.0 = 0.0
        // ------------------------------------------------------

        fpu_test_a = 16'h0000;
        fpu_test_b = 16'h4000;

        #1;

        if (fpu_test_result === 16'h0000)
            $display("PASS: 0.0 * 2.0 = 0.0");
        else
            $display(
                "FAIL: 0.0 * 2.0, got %h",
                fpu_test_result
            );

        fpu_test_enable = 1'b0;

        // ======================================================
        // FINISH
        // ======================================================

        $display("");
        $display("==============================================");
        $display("ALL TESTS COMPLETE");
        $display("==============================================");

        #10;
        $finish;


    end

endmodule
