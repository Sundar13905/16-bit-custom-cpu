interface pipelined_core_if;
  // ---- clock/reset (driven by the test harness) ----
  logic clk;
  logic rstn;

  // ---- signals ----
  

  // Driver clocking block - drive synchronous signals via vif.drv_cb
  clocking drv_cb @(posedge clk);
    // default input #1step output #1step;
    // TODO: add driver signals
  endclocking

  // Monitor clocking block - sample synchronous signals via vif.mon_cb
  clocking mon_cb @(posedge clk);
    // default input #1step;
    // TODO: add monitor signals
  endclocking
endinterface
