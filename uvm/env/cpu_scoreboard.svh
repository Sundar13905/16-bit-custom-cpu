// ============================================================================
// cpu_scoreboard.svh : in-order lock-step checker against cpu_ref_model.
//
// For every retired instruction the scoreboard checks, in this order:
//   1. PC            - the DUT retired the instruction the ISA says comes next
//   2. operands      - the values the DUT used in EX equal the architectural
//                      register values (catches forwarding / bypass bugs)
//   3. result        - write enable, destination, write data, store
//                      address/data and next PC, recomputed from the operands
//                      the DUT actually used (isolates execution-unit bugs
//                      from operand-delivery bugs)
// At the end of every program the whole register file and data memory are
// compared through the backdoor.
//
// Mismatch IDs
//   KNOWN_BUG_WB_ID  operand mismatch while the monitor saw the register being
//                    written in WB during the consumer's ID cycle with no EX
//                    forwarding (the seeded write-through bypass bug)
//   KNOWN_BUG_FMUL_SUBNORM  FMUL result mismatch with a subnormal operand
//                    (found by this env; root cause in fpu.v fp16_mul)
//   SB_OPERAND       any other operand mismatch
//   SB_PC SB_WB SB_STORE SB_NEXTPC SB_FINAL_REG SB_FINAL_MEM SB_TIMEOUT
//
// After a mismatch the model is re-synchronised to the DUT (it adopts the
// DUT's value / PC) so one defect is reported once instead of cascading.
// ============================================================================
`uvm_analysis_imp_decl(_retire)
`uvm_analysis_imp_decl(_ctrl)

class cpu_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(cpu_scoreboard)

    uvm_analysis_imp_retire #(cpu_retire_txn, cpu_scoreboard) retire_imp;
    uvm_analysis_imp_ctrl   #(cpu_ctrl_txn,   cpu_scoreboard) ctrl_imp;

    cpu_ref_model iss;
    bit           active;
    string        cur_tag;
    bit           diverged_known;     // the known bug altered this program's data or control flow

    // statistics
    longint unsigned n_checked, n_programs, n_halted;
    int unsigned n_known_bug, n_known_bug_ctrl, n_unknown, n_fmul_bug;
    int unsigned n_err_by_id [string];
    int unsigned n_retired_by_op [NUM_OPS];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        retire_imp = new("retire_imp", this);
        ctrl_imp   = new("ctrl_imp", this);
        iss        = cpu_ref_model::type_id::create("iss");
    endfunction

    // known: 0 = unexplained, 1 = seeded WB->ID bug, 2 = FMUL subnormal bug
    function void err(string id, string msg, int known = 0);
        if (!n_err_by_id.exists(id)) n_err_by_id[id] = 0;
        n_err_by_id[id]++;
        if (known == 1) n_known_bug++; else if (known == 0) n_unknown++;
        `uvm_error(id, {"[", cur_tag, "] ", msg})
    endfunction

    // ------------------------------------------------------------------
    function void write_ctrl(cpu_ctrl_txn t);
        case (t.kind)
            CTRL_START: begin
                iss.load(t.prog.imem, t.prog.dmem, t.prog.regs);
                active         = 1;
                cur_tag        = t.prog.tag;
                diverged_known = 0;
                n_programs++;
            end
            CTRL_RESYNC: begin
                // Reset kills in-flight instructions at an arbitrary point; the
                // architectural state that survives is taken from the DUT and
                // execution restarts at PC 0.
                iss.load(t.prog.imem, t.dmem, t.regs);
                if (t.regs[0] !== 16'h0)
                    err("SB_RESET_R0", $sformatf("R0 = %04h after reset", t.regs[0]));
                `uvm_info("SB", $sformatf("[%s] reset resync", cur_tag), UVM_MEDIUM)
            end
            CTRL_END: begin
                final_check(t);
                active = 0;
            end
        endcase
    endfunction

    function void final_check(cpu_ctrl_txn t);
        if (!t.halted) begin
            if (diverged_known)
                `uvm_warning("SB_TIMEOUT_KNOWN", $sformatf("[%s] no halt within %0d cycles; the known bug changed this program's state earlier",
                                                           cur_tag, t.cycles))
            else
                err("SB_TIMEOUT", $sformatf("program did not halt within %0d cycles (model pc=%04h)", t.cycles, iss.pc));
            return;
        end
        n_halted++;
        for (int r = 0; r < 8; r++)
            if (t.regs[r] !== iss.regs[r])
                err("SB_FINAL_REG", $sformatf("R%0d DUT=%04h model=%04h", r, t.regs[r], iss.regs[r]));
        for (int a = 0; a < 256; a++)
            if (t.dmem[a] !== iss.dmem[a])
                err("SB_FINAL_MEM", $sformatf("DMEM[%0d] DUT=%04h model=%04h", a, t.dmem[a], iss.dmem[a]));
        if (!(cpu_decode(iss.fetch()).cls inside {CL_JAL, CL_JALR}))
            err("SB_HALT", $sformatf("DUT halted but model pc=%04h is not on a halt", iss.pc));
    endfunction

    // ------------------------------------------------------------------
    function void write_retire(cpu_retire_txn r);
        cpu_dec_t    d;
        cpu_exp_t    e;
        logic [15:0] a, b;
        bit          bad_op = 0, known = 0;

        if (!active) begin
            err("SB_SPURIOUS", {"retire outside a program: ", r.convert2string()});
            return;
        end
        n_checked++;

        // 1. PC / instruction ------------------------------------------
        // The model always adopts the DUT's next PC, so this checks that the
        // pipeline retires exactly the instruction its own redirect selected
        // (no lost, duplicated or wrongly-flushed instruction).
        if (r.pc !== iss.pc) begin
            err("SB_PC", $sformatf("retired pc=%04h, expected pc=%04h", r.pc, iss.pc));
            iss.pc = r.pc;
        end
        if (r.instr !== iss.fetch())
            err("SB_INSTR", $sformatf("pc=%04h DUT instr=%04h model imem=%04h", r.pc, r.instr, iss.fetch()));

        d = cpu_decode(iss.fetch());
        n_retired_by_op[int'(d.op)]++;

        // 2. operands --------------------------------------------------
        a = iss.regs[d.src1];
        b = iss.regs[d.src2];
        if (d.use1 && r.op_a !== a) begin
            bad_op = 1;
            if (r.stale_a) begin
                known = 1;
                err("KNOWN_BUG_WB_ID", $sformatf("%s @pc=%04h: operand A (R%0d) read %04h but architectural value is %04h; R%0d was being written back in the consumer's ID cycle (no WB->ID bypass)",
                                               cpu_disasm(r.instr), r.pc, d.src1, r.op_a, a, d.src1), 1);
            end
            else err("SB_OPERAND", $sformatf("%s @pc=%04h: operand A (R%0d) DUT=%04h model=%04h fwd=%0d",
                                             cpu_disasm(r.instr), r.pc, d.src1, r.op_a, a, r.fwd_a));
            a = r.op_a;
        end
        if (d.use2 && r.op_b !== b) begin
            bad_op = 1;
            if (r.stale_b) begin
                known = 1;
                err("KNOWN_BUG_WB_ID", $sformatf("%s @pc=%04h: operand B (R%0d) read %04h but architectural value is %04h; R%0d was being written back in the consumer's ID cycle (no WB->ID bypass)",
                                               cpu_disasm(r.instr), r.pc, d.src2, r.op_b, b, d.src2), 1);
            end
            else err("SB_OPERAND", $sformatf("%s @pc=%04h: operand B (R%0d) DUT=%04h model=%04h fwd=%0d",
                                             cpu_disasm(r.instr), r.pc, d.src2, r.op_b, b, r.fwd_b));
            b = r.op_b;
        end

        // 3. results, from the operands the DUT actually used ------------
        e = iss.exec(d, r.pc, a, b);

        if (r.wb_we !== e.wr || (e.wr && (r.wb_rd !== e.rd || r.wb_data !== e.wdata)))
            if (d.op == OP_FMUL && r.wb_we && r.wb_rd == e.rd &&
                (fp16_class(a) == FPC_SUB || fp16_class(b) == FPC_SUB)) begin
                n_fmul_bug++;
                err("KNOWN_BUG_FMUL_SUBNORM", $sformatf("%s @pc=%04h a=%04h b=%04h: DUT %04h, IEEE-754 RNE %04h (subnormal operand not normalised)",
                                                       cpu_disasm(r.instr), r.pc, a, b, r.wb_data, e.wdata), 2);
            end
            else err(res_id(d), $sformatf("%s @pc=%04h a=%04h b=%04h: DUT we=%0d R%0d=%04h, model we=%0d R%0d=%04h",
                                     cpu_disasm(r.instr), r.pc, a, b, r.wb_we, r.wb_rd, r.wb_data, e.wr, e.rd, e.wdata));
        if (r.mem_we !== e.st || (e.st && (r.mem_addr !== e.addr || r.mem_wdata !== e.sdata)))
            err("SB_STORE", $sformatf("%s @pc=%04h: DUT we=%0d [%04h]=%04h, model we=%0d [%04h]=%04h",
                                      cpu_disasm(r.instr), r.pc, r.mem_we, r.mem_addr, r.mem_wdata, e.st, e.addr, e.sdata));
        if (e.ld && r.mem_addr !== e.addr)
            err("SB_LOAD_ADDR", $sformatf("%s @pc=%04h: DUT addr=%04h model addr=%04h",
                                          cpu_disasm(r.instr), r.pc, r.mem_addr, e.addr));
        if (r.next_pc !== e.next_pc)
            err("SB_NEXTPC", $sformatf("%s @pc=%04h a=%04h b=%04h: DUT next=%04h model next=%04h",
                                       cpu_disasm(r.instr), r.pc, a, b, r.next_pc, e.next_pc));

        // a stale operand changes the program's data (and maybe its path), so
        // the reference pre-run that guaranteed termination no longer applies
        if (known) diverged_known = 1;
        // control-flow effect of a stale operand (counted, already reported)
        if (known) begin
            cpu_exp_t arch = iss.exec(d, r.pc, iss.regs[d.src1], iss.regs[d.src2]);
            if (arch.next_pc !== e.next_pc) begin
                n_known_bug_ctrl++;
                diverged_known = 1;
            end
        end

        // commit what the DUT did (re-sync on any mismatch)
        if (r.wb_we && r.wb_rd != 0) e.wdata = r.wb_data;
        if (r.mem_we) begin e.addr = r.mem_addr; e.sdata = r.mem_wdata; end
        e.next_pc = r.next_pc;
        iss.commit(e);
    endfunction

    function string res_id(cpu_dec_t d);
        case (d.cls)
            CL_FPU:    return "SB_WB_FPU";
            CL_CRYPTO: return "SB_WB_CRYPTO";
            CL_LOAD:   return "SB_WB_LOAD";
            default:   return "SB_WB";
        endcase
    endfunction

    // ------------------------------------------------------------------
    function void report_phase(uvm_phase phase);
        string s;
        s = $sformatf("\n---------------- SCOREBOARD SUMMARY ----------------\n");
        s = {s, $sformatf("programs run           : %0d (halted %0d)\n", n_programs, n_halted)};
        s = {s, $sformatf("instructions checked   : %0d\n", n_checked)};
        s = {s, $sformatf("known-bug mismatches   : %0d (of which changed control flow: %0d)\n", n_known_bug, n_known_bug_ctrl)};
        s = {s, $sformatf("FMUL subnormal bug     : %0d\n", n_fmul_bug)};
        s = {s, $sformatf("unexplained mismatches : %0d\n", n_unknown)};
        foreach (n_err_by_id[id]) s = {s, $sformatf("   %-18s : %0d\n", id, n_err_by_id[id])};
        s = {s, "retired per opcode     :"};
        for (int i = 0; i < NUM_OPS; i++) begin
            cpu_op_e o = cpu_op_e'(i);
            string   nm = o.name();
            if (i % 6 == 0) s = {s, "\n  "};
            s = {s, $sformatf("%-5s %6d  ", nm.substr(3, nm.len() - 1), n_retired_by_op[i])};
        end
        `uvm_info("SB_SUMMARY", s, UVM_NONE)
    endfunction
endclass
