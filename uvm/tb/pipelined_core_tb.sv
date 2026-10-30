// ============================================================================
// pipelined_core_tb : UVM top. Clock, DUT instance, probe bind, UVM kick-off.
// (cpu_backdoor_impl below reaches the DUT memories through dut.*, so
//  keep the instance names dut, IMEM, DMEM, RF if you rename things.)
// ============================================================================
`timescale 1ns/1ps

module pipelined_core_tb;
    import uvm_pkg::*;
    import cpu_uvm_pkg::*;

    logic clk = 1'b0;
    always #5 clk = ~clk;                      // 100 MHz

    cpu_ctrl_if ctrl_if (.clk(clk));
    initial ctrl_if.rst = 1'b1;

    pipelined_core dut (.clk(clk), .rst(ctrl_if.rst));

    // White-box probe: bound inside the DUT so it can see internal nets.
    bind pipelined_core cpu_probe_if probe (
        .clk              (clk),
        .rst              (rst),
        .pc_out           (pc_out),
        .if_instr         (instr),
        .if_id_pc         (if_id_pc),
        .if_id_instr      (if_id_instr),
        .id_rs1           (id_rf_read_addr1),
        .id_rs2           (id_rf_read_addr2),
        .hz_stall         (hazard_pc_stall),
        .hz_flush         (hazard_id_ex_flush),
        .id_ex_pc         (id_ex_pc),
        .fwd_a            (forward_a),
        .fwd_b            (forward_b),
        .ex_op_a          (ex_forward_a),
        .ex_op_b          (ex_forward_b),
        .ex_result        (ex_result),
        .ex_branch_taken  (ex_branch_taken),
        .ex_branch_target (ex_branch_target),
        .ex_jump_taken    (ex_jump_taken),
        .ex_jump_target   (ex_jump_target),
        .ex_ctrl_taken    (ex_control_taken),
        .mem_we           (ex_mem_mem_write),
        .mem_re           (ex_mem_mem_read),
        .mem_addr         (ex_mem_execution_result),
        .mem_wdata        (ex_mem_store_data),
        .mem_rdata        (mem_read_data),
        .wb_we            (wb_reg_write),
        .wb_rd            (mem_wb_rd),
        .wb_data          (wb_write_data)
    );

    // Backdoor to the DUT memories (hierarchical paths are legal here, in the
    // module, but not inside an interface used as a virtual interface).
    class cpu_backdoor_impl extends cpu_backdoor;
        virtual function void write_imem(int unsigned a, logic [15:0] d);
            dut.IMEM.instr_mem[a[7:0]] = d;
        endfunction
        virtual function void write_dmem(int unsigned a, logic [15:0] d);
            dut.DMEM.memory[a[7:0]] = d;
        endfunction
        virtual function void write_reg(int unsigned r, logic [15:0] d);
            dut.RF.registers[r[2:0]] = d;
        endfunction
        virtual function logic [15:0] read_dmem(int unsigned a);
            return dut.DMEM.memory[a[7:0]];
        endfunction
        virtual function logic [15:0] read_reg(int unsigned r);
            return dut.RF.registers[r[2:0]];
        endfunction
    endclass

    initial begin
        cpu_backdoor_impl bd;
        bd = new();
        uvm_config_db#(cpu_backdoor)::set(null, "*", "backdoor", bd);
        uvm_config_db#(virtual cpu_ctrl_if )::set(null, "*", "ctrl_vif",  ctrl_if);
        uvm_config_db#(virtual cpu_probe_if)::set(null, "*", "probe_vif", dut.probe);
        run_test();
    end
endmodule
