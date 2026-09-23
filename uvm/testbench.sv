
`include "uvm_macros.svh"
`include "single_cycle_core_if_intf.sv"

module single_cycle_core_tb;
    timeunit      1ns;
    timeprecision 1ps;
    
    import uvm_pkg::*;
    import single_cycle_core_if_pkg::*;
    import single_cycle_core_pkg::*;

    // test harness
    single_cycle_core_th th();
    
    // Config DB setup
    function void set_config_db();
        single_cycle_core_if_config cfg_single_cycle_core_if_0;
        cfg_single_cycle_core_if_0 = single_cycle_core_if_config::type_id::create("cfg_single_cycle_core_if_0");
        cfg_single_cycle_core_if_0.vif       = th.intf_single_cycle_core_if_0;
        cfg_single_cycle_core_if_0.is_active = UVM_ACTIVE;
        uvm_config_db#(single_cycle_core_if_config)::set(null, "*.single_cycle_core_if_agt_0*", "cfg", cfg_single_cycle_core_if_0);
    endfunction
    
    // Config DB setup and test execution
    initial begin
        // Setup configuration
        set_config_db();
        
        // Run the test
        run_test("single_cycle_core_test");
    end
    
endmodule
