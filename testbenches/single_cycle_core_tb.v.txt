`timescale 1ns / 1ps
// ====================================================================
// Testbench for Single Cycle Core (Green CPU)
// Includes detailed runtime monitoring of datapath and control signals
// ====================================================================

module single_cycle_core_tb;

    reg clk;
    reg rst;

    // Instantiate the CPU core
    single_cycle_core DUT (
        .clk(clk),
        .rst(rst)
    );

    // ----------------------------------------------------------------
    // Clock generation (10ns period)
    // ----------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ----------------------------------------------------------------
    // Simulation control and monitoring
    // ----------------------------------------------------------------
    initial begin
        $dumpfile("single_cycle_core.vcd");
        $dumpvars(0, DUT);

        // Reset sequence
        rst = 1;
        #20;
        rst = 0;

        $display("============================================================");
        $display(" Green CPU - Single Cycle Core Simulation Trace ");
        $display("============================================================");
        $display("  Time(ns) |  PC   INSTR  | ALU_CTRL ALU_OUT | RD1  RD2  | REGW MEMR MEMW FPU | WDATA MDATA ");
        $display("------------------------------------------------------------");

        // Periodic status monitoring
        repeat (100) begin
            #10; // sample every 10ns
            $display("%8t | %h  %h | %b  %h | %h  %h |  %b    %b    %b    %b | %h  %h",
                $time,
                DUT.pc_out,
                DUT.instr,
                DUT.alu_ctrl,
                DUT.alu_out,
                DUT.rd_data1,
                DUT.rd_data2,
                DUT.reg_write,
                DUT.mem_read,
                DUT.mem_write,
                DUT.fpu_enable,
                DUT.write_data,
                DUT.mem_data
            );
        end

        $display("============================================================");
        $display(" Simulation Complete. View waveform in GTKWave. ");
        $display("============================================================");

        #50;
        $finish;
    end

endmodule
