// ============================================================================
// cpu_agent.svh : sequencer, driver, monitor, agent
// ============================================================================

typedef uvm_sequencer #(cpu_program_item) cpu_sequencer;

// ----------------------------------------------------------------------------
// Driver: for every program item
//   1. assert reset, backdoor-load IMEM / DMEM / register file
//   2. publish CTRL_START (program image) to the scoreboard / coverage
//   3. release reset and clock the core until it reaches the halt self-loop
//      (or the cycle budget runs out); optional mid-program reset pulse
//   4. publish CTRL_END with a backdoor snapshot of the final state
// ----------------------------------------------------------------------------
class cpu_driver extends uvm_driver #(cpu_program_item);
    `uvm_component_utils(cpu_driver)

    virtual cpu_ctrl_if  cvif;
    virtual cpu_probe_if pvif;
    cpu_backdoor         bd;
    uvm_analysis_port #(cpu_ctrl_txn) ap_ctrl;
    int unsigned n_programs, n_timeouts;
    longint unsigned total_cycles;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap_ctrl = new("ap_ctrl", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cpu_ctrl_if)::get(this, "", "ctrl_vif", cvif))
            `uvm_fatal("NOVIF", "ctrl_vif not set")
        if (!uvm_config_db#(virtual cpu_probe_if)::get(this, "", "probe_vif", pvif))
            `uvm_fatal("NOVIF", "probe_vif not set")
        if (!uvm_config_db#(cpu_backdoor)::get(this, "", "backdoor", bd))
            `uvm_fatal("NOVIF", "backdoor not set")
    endfunction

    function void snapshot(cpu_ctrl_txn t);
        foreach (t.regs[i]) t.regs[i] = bd.read_reg(i);
        foreach (t.dmem[i]) t.dmem[i] = bd.read_dmem(i);
    endfunction

    task run_phase(uvm_phase phase);
        cvif.rst = 1'b1;
        forever begin
            seq_item_port.get_next_item(req);
            drive_program(req);
            seq_item_port.item_done();
        end
    endtask

    task drive_program(cpu_program_item p);
        cpu_ctrl_txn t;
        bit halted = 0, reset_done = 0;
        longint unsigned cyc = 0;
        int unsigned drain = 0;

        // ---- 1. reset + backdoor load ---------------------------------
        @(posedge cvif.clk); #2;
        cvif.rst = 1'b1;
        repeat (2) @(posedge cvif.clk);
        #1;
        for (int i = 0; i < 256; i++) bd.write_imem(i, p.imem[i]);
        for (int i = 0; i < 256; i++) bd.write_dmem(i, p.dmem[i]);
        for (int i = 1; i < 8;   i++) bd.write_reg(i, p.regs[i]);

        // ---- 2. announce program ---------------------------------------
        t = cpu_ctrl_txn::type_id::create("start");
        t.kind = CTRL_START; t.prog = p;
        ap_ctrl.write(t);
        `uvm_info("DRV", $sformatf("start %s", p.tag), UVM_HIGH)
        `uvm_info("DRV", p.convert2string(), UVM_DEBUG)

        // ---- 3. run -------------------------------------------------------
        @(posedge cvif.clk); #2;
        cvif.rst = 1'b0;
        while (cyc < p.max_cycles) begin
            @(posedge cvif.clk); #1;
            cyc++;
            if (p.reset_at >= 0 && !reset_done && cyc >= longint'(p.reset_at) &&
                (p.reset_cond == 0 || cyc >= longint'(p.reset_at) + 40 ||
                 (p.reset_cond == 1 && pvif.mem_we) ||
                 (p.reset_cond == 2 && pvif.ex_ctrl_taken) ||
                 (p.reset_cond == 3 && pvif.hz_stall))) begin
                cpu_ctrl_txn r = cpu_ctrl_txn::type_id::create("resync");
                r.kind             = CTRL_RESYNC; r.prog = p;
                r.rst_store_in_mem = pvif.mem_we;
                r.rst_ctrl_in_ex   = pvif.ex_ctrl_taken;
                r.rst_stall        = pvif.hz_stall;
                #1 cvif.rst = 1'b1;
                repeat (p.reset_len) @(posedge cvif.clk);
                #1;
                snapshot(r);
                ap_ctrl.write(r);
                #1 cvif.rst = 1'b0;
                halted = 0;     // execution restarts at PC 0
                drain  = 0;
                reset_done = 1;
            end
            // halt = a taken jump whose target is its own PC
            if (!halted && pvif.ex_jump_taken && pvif.ex_jump_target == pvif.id_ex_pc)
                halted = 1;
            if (halted && ++drain == 3) break;
        end
        @(posedge cvif.clk); #1;
        // stop the core: nothing retires between programs
        cvif.rst = 1'b1;
        #1;

        // ---- 4. end of program -----------------------------------------
        t = cpu_ctrl_txn::type_id::create("end");
        t.kind = CTRL_END; t.prog = p; t.halted = halted; t.cycles = cyc;
        snapshot(t);
        ap_ctrl.write(t);
        n_programs++;
        total_cycles += cyc;
        if (!halted) n_timeouts++;
    endtask
endclass

// ----------------------------------------------------------------------------
// Monitor: rebuilds the in-order retirement stream from the white-box probe.
//
// The DUT does not carry a 'valid' bit or the instruction word past ID, so the
// monitor keeps a shadow copy of the pipeline (one record per stage) and
// advances it with the same stall / flush rules as the RTL. Every record
// collects what happened to its instruction in ID, EX, MEM and WB, and is
// published on ap_retire when it leaves WB.  Signals are sampled at the
// falling clock edge, when every combinational net of the cycle is settled.
// ----------------------------------------------------------------------------
class cpu_monitor extends uvm_monitor;
    `uvm_component_utils(cpu_monitor)

    virtual cpu_probe_if pvif;
    uvm_analysis_port #(cpu_retire_txn) ap_retire;

    cpu_retire_txn s_id, s_ex, s_mem, s_wb;   // null = bubble / invalid
    longint unsigned cyc, n_retired;
    int unsigned     n_shadow_err;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap_retire = new("ap_retire", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual cpu_probe_if)::get(this, "", "probe_vif", pvif))
            `uvm_fatal("NOVIF", "probe_vif not set")
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(negedge pvif.clk);
            cyc++;
            sample_cycle();
        end
    endtask

    function void sample_cycle();
        cpu_retire_txn nxt_id;
        if (pvif.rst) begin
            s_id = null; s_ex = null; s_mem = null; s_wb = null;
            return;
        end

        // ---------------- ID ----------------
        if (s_id != null) begin
            if (s_id.pc != pvif.if_id_pc || s_id.instr != pvif.if_id_instr) begin
                n_shadow_err++;
                `uvm_error("MON_SHADOW", $sformatf("shadow ID pc=%04h instr=%04h but DUT IF/ID pc=%04h instr=%04h",
                           s_id.pc, s_id.instr, pvif.if_id_pc, pvif.if_id_instr))
            end
            if (pvif.hz_stall) s_id.stall_cycles++;
            else if (!pvif.ex_ctrl_taken) begin
                // last ID cycle: register file is read now. A write to the same
                // register in WB this cycle lands only at the next edge.
                s_id.cyc_id = cyc;
                s_id.risk_a = pvif.wb_we && pvif.wb_rd != 0 && pvif.wb_rd == pvif.id_rs1;
                s_id.risk_b = pvif.wb_we && pvif.wb_rd != 0 && pvif.wb_rd == pvif.id_rs2;
            end
        end
        // ---------------- EX ----------------
        if (s_ex != null) begin
            if (s_ex.pc != pvif.id_ex_pc) begin
                n_shadow_err++;
                `uvm_error("MON_SHADOW", $sformatf("shadow EX pc=%04h but DUT ID/EX pc=%04h", s_ex.pc, pvif.id_ex_pc))
            end
            s_ex.fwd_a      = pvif.fwd_a;
            s_ex.fwd_b      = pvif.fwd_b;
            s_ex.op_a       = pvif.ex_op_a;
            s_ex.op_b       = pvif.ex_op_b;
            s_ex.ex_result  = pvif.ex_result;
            s_ex.ctrl_taken = pvif.ex_ctrl_taken;
            s_ex.next_pc    = pvif.ex_branch_taken ? pvif.ex_branch_target :
                              pvif.ex_jump_taken   ? pvif.ex_jump_target   : s_ex.pc + 16'd1;
            s_ex.stale_a    = s_ex.risk_a && pvif.fwd_a == 2'b00;
            s_ex.stale_b    = s_ex.risk_b && pvif.fwd_b == 2'b00;
        end
        // ---------------- MEM ---------------
        if (s_mem != null) begin
            s_mem.mem_we    = pvif.mem_we;
            s_mem.mem_re    = pvif.mem_re;
            s_mem.mem_addr  = pvif.mem_addr;
            s_mem.mem_wdata = pvif.mem_wdata;
            s_mem.mem_rdata = pvif.mem_rdata;
        end
        // ---------------- WB ----------------
        if (s_wb != null) begin
            s_wb.wb_we   = pvif.wb_we;
            s_wb.wb_rd   = pvif.wb_rd;
            s_wb.wb_data = pvif.wb_data;
            s_wb.cyc_wb  = cyc;
            s_wb.seq_no  = n_retired++;
            `uvm_info("MON", s_wb.convert2string(), UVM_HIGH)
            ap_retire.write(s_wb);
        end

        // ---------------- advance (mirrors RTL stall / flush) ----------
        if (pvif.ex_ctrl_taken)  nxt_id = null;                 // IF/ID flush
        else if (pvif.hz_stall)  nxt_id = s_id;                 // IF/ID hold
        else begin
            nxt_id       = cpu_retire_txn::type_id::create("rt");
            nxt_id.pc    = pvif.pc_out;
            nxt_id.instr = pvif.if_instr;
            nxt_id.dec   = cpu_decode(pvif.if_instr);
        end
        s_wb  = s_mem;
        s_mem = s_ex;
        s_ex  = (pvif.hz_flush || pvif.ex_ctrl_taken) ? null : s_id;   // ID/EX bubble
        s_id  = nxt_id;
    endfunction
endclass

// ----------------------------------------------------------------------------
class cpu_agent extends uvm_agent;
    `uvm_component_utils(cpu_agent)

    cpu_sequencer sqr;
    cpu_driver    drv;
    cpu_monitor   mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon = cpu_monitor::type_id::create("mon", this);
        if (get_is_active() == UVM_ACTIVE) begin
            sqr = cpu_sequencer::type_id::create("sqr", this);
            drv = cpu_driver::type_id::create("drv", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if (get_is_active() == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
