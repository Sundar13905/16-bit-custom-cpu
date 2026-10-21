
module pipelined_core_th;

  timeunit      1ns;
  timeprecision 1ps;

  // ---- Timing controls (override at elaboration, e.g. -pvalue+pipelined_core_th.RESET_TIME=100) ----
  parameter int CLK_PERIOD  = 10;        // clock period in ns
  parameter int RESET_TIME  = 50;        // reset held asserted for this many ns
  parameter int WATCHDOG_NS = 2000000;   // 2 ms — hard stop far beyond any normal run

  logic clk = 0;
  logic rstn;

  always #(CLK_PERIOD/2) clk = ~clk;

  initial
  begin
    rstn = 0;
    #(RESET_TIME) rstn = 1;
  end


  // ---- Watchdog: guarantee the simulation always terminates. If the DUT stalls
  // (e.g. never asserts a ready/handshake the VIP is waiting on) the test would
  // otherwise hang forever with no $finish. Override with +WATCHDOG_NS=<n>.
  initial begin
    int wd;
    wd = WATCHDOG_NS;
    void'($value$plusargs("WATCHDOG_NS=%d", wd));
    #(wd);
    $display("\n*** SIMULATION WATCHDOG TIMEOUT at %0t ns: no $finish reached.", $time);
    $display("*** The DUT may be stalling -- e.g. never asserting a ready/handshake the VIP waits on.");
    $fatal(1, "watchdog timeout");
  end

        pipelined_core_if intf_pipelined_core_if_0();

        assign intf_pipelined_core_if_0.clk = clk;
        assign intf_pipelined_core_if_0.rstn = rstn;
  
pipelined_core dut(.clk(clk), .rst(rstn));

endmodule
