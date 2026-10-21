
`include "uvm_macros.svh"
`include "pipelined_core_if_intf.sv"

module pipelined_core_tb;
    timeunit      1ns;
    timeprecision 1ps;
    
    import uvm_pkg::*;
    import pipelined_core_if_pkg::*;
    import pipelined_core_pkg::*;

    // test harness
    pipelined_core_th th();
    
    // Config DB setup
    function void set_config_db();
        pipelined_core_if_config cfg_pipelined_core_if_0;
        cfg_pipelined_core_if_0 = pipelined_core_if_config::type_id::create("cfg_pipelined_core_if_0");
        cfg_pipelined_core_if_0.vif       = th.intf_pipelined_core_if_0;
        cfg_pipelined_core_if_0.is_active = UVM_ACTIVE;
        uvm_config_db#(pipelined_core_if_config)::set(null, "*.pipelined_core_if_agt_0*", "cfg", cfg_pipelined_core_if_0);
    endfunction
    
    // Config DB setup and test execution
    initial begin
        // Setup configuration
        set_config_db();
        
        // Run the test
        run_test("pipelined_core_test");
    end
    
endmodule
