`timescale 1ns / 1ps
// =============================================================
// pipelined_core_tb.v
// Self-terminating Testbench for Pipelined Core
// =============================================================

module pipelined_core_tb;

    reg clk;
    reg rst;

    // Instantiate the pipelined core
    pipelined_core DUT (
        .clk(clk),
        .reset(rst)
    );

    // Clock generation (10 ns period = 100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset sequence
    initial begin
        rst = 1;
        #30;
        rst = 0;
        $display("Reset deasserted at %0t ns", $time);
    end

    // Waveform dump
    initial begin
        $dumpfile("pipelined_core.vcd");
        $dumpvars(0, DUT);
    end

    // Termination control
    integer instr_limit = 32;   // Match your instr_mem size
    integer cycle_count = 0;

    always @(posedge clk) begin
        if (!rst) begin
            cycle_count = cycle_count + 1;

            // Check if PC has exceeded the instruction memory limit
            if (DUT.pc_if >= instr_limit) begin
                $display("====================================");
                $display(" Program execution complete. PC=%0d", DUT.pc_if);
                $display("====================================");
                $finish;
            end

            // Safety stop after a maximum number of cycles
            if (cycle_count > 10000) begin
                $display("====================================");
                $display(" TIMEOUT: Simulation exceeded cycle limit (%0d cycles)", cycle_count);
                $display("====================================");
                $finish;
            end
        end
    end

    // Simulation start message
    initial begin
        $display("====================================");
        $display(" Pipelined Core Simulation Started ");
        $display("====================================");
    end

endmodule
