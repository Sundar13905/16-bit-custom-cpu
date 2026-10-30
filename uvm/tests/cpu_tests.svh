// ============================================================================
// cpu_tests.svh : test library
//
//   cpu_smoke_test     directed programs
//   cpu_rand_test      constrained-random programs   (+N_PROG=<n>)
//   cpu_hazard_test    producer x consumer x distance {1,2,3,4} matrix
//   cpu_wbid_bug_test  distance-3 matrix: PASSES only if the seeded WB->ID
//                      bypass bug is detected and nothing else fails
//   cpu_ctrl_test      branch / jump scenarios
//   cpu_mem_test       load / store scenarios
//   cpu_fpu_test       binary16 corner values
//   cpu_crypto_test    ENC / DEC chains
//   cpu_reset_test     mid-program reset
//   cpu_full_test      all of the above in one run (regression / coverage)
//
// Plusargs: +WAIVE_KNOWN_BUG     demote KNOWN_BUG_WB_ID errors to warnings
//           +WAIVE_FMUL_SUBNORM  demote KNOWN_BUG_FMUL_SUBNORM errors to warnings
//           +N_PROG=<n>          scale the number of programs
// ============================================================================
class cpu_base_test extends uvm_test;
    `uvm_component_utils(cpu_base_test)

    cpu_env               env;
    cpu_known_bug_catcher catcher;
    int unsigned          n_prog = 20;
    bit                   expect_known_bug = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = cpu_env::type_id::create("env", this);
        void'($value$plusargs("N_PROG=%d", n_prog));
        catcher = new("known_bug_catcher");
        if ($test$plusargs("WAIVE_KNOWN_BUG") || expect_known_bug) catcher.ids.push_back("KNOWN_BUG_WB_ID");
        if ($test$plusargs("WAIVE_FMUL_SUBNORM"))                  catcher.ids.push_back("KNOWN_BUG_FMUL_SUBNORM");
        uvm_report_cb::add(null, catcher);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
        if (uvm_report_enabled(UVM_HIGH)) uvm_root::get().print_topology();
    endfunction

    virtual task run_seqs();
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        run_seqs();
        phase.drop_objection(this);
    endtask

    task start_seq(cpu_base_seq s, int unsigned n);
        s.n_programs = n;
        s.start(env.agt.sqr);
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server srv = uvm_report_server::get_server();
        int n_err   = srv.get_severity_count(UVM_ERROR) + srv.get_severity_count(UVM_FATAL);
        bit pass    = (n_err == 0);
        string why  = "";
        if (expect_known_bug && env.sb.n_known_bug == 0) begin
            pass = 0;
            why  = " (seeded WB->ID bypass bug was NOT detected)";
        end
        `uvm_info("TEST", $sformatf("known-bug hits: WB->ID=%0d FMUL-subnormal=%0d (waived=%0d)  errors=%0d  driver: %0d programs, %0d cycles, %0d timeouts",
                                    env.sb.n_known_bug, env.sb.n_fmul_bug, catcher.n_waived, n_err,
                                    env.agt.drv.n_programs, env.agt.drv.total_cycles, env.agt.drv.n_timeouts), UVM_NONE)
        if (pass) `uvm_info("TEST", {"*** TEST PASSED *** ", get_type_name()}, UVM_NONE)
        else      `uvm_info("TEST", {"*** TEST FAILED *** ", get_type_name(), why}, UVM_NONE)
    endfunction
endclass

class cpu_smoke_test extends cpu_base_test;
    `uvm_component_utils(cpu_smoke_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_seqs();
        cpu_directed_seq s = cpu_directed_seq::type_id::create("dir");
        start_seq(s, 4);
    endtask
endclass

class cpu_rand_test extends cpu_base_test;
    `uvm_component_utils(cpu_rand_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_seqs();
        cpu_rand_seq s = cpu_rand_seq::type_id::create("rand");
        start_seq(s, n_prog);
    endtask
endclass

class cpu_hazard_test extends cpu_base_test;
    `uvm_component_utils(cpu_hazard_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_seqs();
        cpu_hazard_seq s = cpu_hazard_seq::type_id::create("hazard");
        s.n_passes = 2;
        start_seq(s, 0);
    endtask
endclass

class cpu_wbid_bug_test extends cpu_base_test;
    `uvm_component_utils(cpu_wbid_bug_test)
    function new(string name, uvm_component parent);
        super.new(name, parent);
        expect_known_bug = 1;
    endfunction
    task run_seqs();
        cpu_hazard_seq s = cpu_hazard_seq::type_id::create("wbid");
        s.dists = '{3};
        start_seq(s, 0);
    endtask
endclass

class cpu_ctrl_test extends cpu_base_test;
    `uvm_component_utils(cpu_ctrl_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_seqs();
        cpu_ctrl_seq s = cpu_ctrl_seq::type_id::create("ctrl");
        start_seq(s, n_prog / 2);
    endtask
endclass

class cpu_mem_test extends cpu_base_test;
    `uvm_component_utils(cpu_mem_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_seqs();
        cpu_mem_seq s = cpu_mem_seq::type_id::create("mem");
        start_seq(s, n_prog / 2);
    endtask
endclass

class cpu_fpu_test extends cpu_base_test;
    `uvm_component_utils(cpu_fpu_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_seqs();
        cpu_fpu_seq s = cpu_fpu_seq::type_id::create("fpu");
        start_seq(s, n_prog);
    endtask
endclass

class cpu_crypto_test extends cpu_base_test;
    `uvm_component_utils(cpu_crypto_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_seqs();
        cpu_crypto_seq s = cpu_crypto_seq::type_id::create("crypto");
        start_seq(s, n_prog / 2);
    endtask
endclass

class cpu_reset_test extends cpu_base_test;
    `uvm_component_utils(cpu_reset_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_seqs();
        cpu_reset_seq s = cpu_reset_seq::type_id::create("reset");
        start_seq(s, n_prog);
    endtask
endclass

class cpu_full_test extends cpu_base_test;
    `uvm_component_utils(cpu_full_test)
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    task run_seqs();
        cpu_directed_seq dir = cpu_directed_seq::type_id::create("dir");
        cpu_hazard_seq   hz  = cpu_hazard_seq::type_id::create("hazard");
        cpu_ctrl_seq     ct  = cpu_ctrl_seq::type_id::create("ctrl");
        cpu_mem_seq      mm  = cpu_mem_seq::type_id::create("mem");
        cpu_fpu_seq      fp  = cpu_fpu_seq::type_id::create("fpu");
        cpu_crypto_seq   cr  = cpu_crypto_seq::type_id::create("crypto");
        cpu_reset_seq    rs  = cpu_reset_seq::type_id::create("reset");
        cpu_rand_seq     rn  = cpu_rand_seq::type_id::create("rand");
        start_seq(dir, 4);
        hz.n_passes = 2;
        start_seq(hz, 0);
        start_seq(ct, n_prog / 2);
        start_seq(mm, n_prog / 2);
        start_seq(fp, n_prog);
        start_seq(cr, n_prog / 2);
        start_seq(rs, n_prog / 2);
        start_seq(rn, n_prog * 2);
    endtask
endclass
