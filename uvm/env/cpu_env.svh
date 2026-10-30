// ============================================================================
// cpu_env.svh : environment + known-bug waiver catcher
// ============================================================================

// Demotes triaged known-bug scoreboard errors to warnings:
//   +WAIVE_KNOWN_BUG     KNOWN_BUG_WB_ID          (seeded WB->ID bypass bug)
//   +WAIVE_FMUL_SUBNORM  KNOWN_BUG_FMUL_SUBNORM   (FMUL subnormal operands)
// Every other error stays an error.
class cpu_known_bug_catcher extends uvm_report_catcher;
    string       ids [$];
    int unsigned n_waived;

    function new(string name = "cpu_known_bug_catcher");
        super.new(name);
    endfunction

    function action_e catch();
        if (get_severity() == UVM_ERROR && get_id() inside {ids}) begin
            set_severity(UVM_WARNING);
            n_waived++;
        end
        return THROW;
    endfunction
endclass

class cpu_env extends uvm_env;
    `uvm_component_utils(cpu_env)

    cpu_agent      agt;
    cpu_scoreboard sb;
    cpu_coverage   cov;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agt = cpu_agent::type_id::create("agt", this);
        sb  = cpu_scoreboard::type_id::create("sb", this);
        cov = cpu_coverage::type_id::create("cov", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agt.mon.ap_retire.connect(sb.retire_imp);
        agt.mon.ap_retire.connect(cov.retire_imp);
        agt.drv.ap_ctrl.connect(sb.ctrl_imp);
        agt.drv.ap_ctrl.connect(cov.ctrl_imp);
    endfunction
endclass
