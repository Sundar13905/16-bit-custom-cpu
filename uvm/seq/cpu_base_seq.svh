// ============================================================================
// cpu_base_seq.svh : program-building helpers shared by all sequences.
//
// A sequence builds a program as a list of 16-bit words (using constrained
// random cpu_instr_item objects or the encoder), together with the initial
// register file and data memory image, and sends it to the driver as one
// cpu_program_item.  Before sending, the program is executed on the
// reference model: programs that do not reach the halt within the step
// budget (e.g. a random backward branch that loops forever) are discarded and
// regenerated, so every program that reaches the DUT is expected to halt.
// ============================================================================
class cpu_base_seq extends uvm_sequence #(cpu_program_item);
    `uvm_object_utils(cpu_base_seq)

    int unsigned n_programs = 4;
    int unsigned n_sent, n_rejected;
    int          reset_at   = -1;

    // instruction mix used by rand_instr()
    int unsigned w_alu_r = 20, w_alu_i = 20, w_load = 8, w_store = 8, w_branch = 10,
                 w_jal = 2, w_jalr = 1, w_fpu = 6, w_crypto = 4, w_rsvd = 1, p_dc = 20;

    // program under construction
    logic [15:0] code [$];
    logic [15:0] regs [8];
    logic [15:0] dmem [256];
    int          next_slot;                 // constant-pool slot allocator
    string       tag;

    function new(string name = "cpu_base_seq");
        super.new(name);
    endfunction

    // ------------------------------------------------------------ values --
    static function logic [15:0] rand_int_val();
        case ($urandom_range(0, 11))
            0:  return 16'h0000;
            1:  return 16'h0001;
            2:  return 16'hFFFF;
            3:  return 16'h7FFF;
            4:  return 16'h8000;
            5:  return 16'($urandom_range(2, 15));
            6:  return 16'(-$urandom_range(2, 15));
            7:  return {1'b0, 15'($urandom)};
            8:  return {1'b1, 15'($urandom)};
            default: return 16'($urandom);
        endcase
    endfunction

    static function logic [15:0] rand_fp_val();
        logic [15:0] corners [] = '{16'h0000, 16'h8000, 16'h0001, 16'h8001, 16'h03FF, 16'h83FF,
                                    16'h0400, 16'h8400, 16'h3C00, 16'hBC00, 16'h7BFF, 16'hFBFF,
                                    16'h7C00, 16'hFC00, 16'h7E00, 16'h7C01, 16'hFE00, 16'h0200,
                                    16'h3555, 16'h4000, 16'h3800, 16'h0401};
        bit s = $urandom_range(0, 1);
        case ($urandom_range(0, 9))
            0, 1, 2: return corners[$urandom_range(0, corners.size() - 1)];
            3:       return {s, 5'($urandom_range(27, 30)), 10'($urandom)};      // large
            4:       return {s, 5'($urandom_range(1, 4)),   10'($urandom)};      // small normal
            5:       return {s, 5'd0, 10'($urandom_range(1, 1023))};             // subnormal
            6:       return {s, 5'($urandom_range(13, 17)), 10'($urandom)};      // around 1.0
            default: return {s, 5'($urandom_range(1, 30)),  10'($urandom)};      // any normal
        endcase
    endfunction

    // ----------------------------------------------------- program build --
    function void begin_program(string t, bit fp_values = 0);
        tag = t;
        code.delete();
        next_slot = 0;
        regs[0] = 0;
        for (int i = 1; i < 8; i++) regs[i] = fp_values ? rand_fp_val() : rand_int_val();
        for (int i = 0; i < 256; i++) dmem[i] = fp_values ? rand_fp_val() : rand_int_val();
    endfunction

    function void emit(logic [15:0] w);
        code.push_back(w);
    endfunction

    function int pc_now();
        return code.size();
    endfunction

    // Put a 16-bit constant in a free constant-pool slot of DMEM and emit
    // "LH r, slot(R0)".  Slots reachable from R0: 0..7 and 248..255.
    function bit load_const(bit [2:0] r, logic [15:0] v);
        bit [3:0]    imm;
        logic [15:0] addr;
        if (next_slot >= 16) return 0;
        imm  = 4'(next_slot);              // 0..7 then 8..15 (= -8..-1 -> 248..255)
        addr = sext4(imm);
        dmem[addr[7:0]] = v;
        emit(cpu_encode(OP_LH, r, 3'd0, 3'd0, imm));
        next_slot++;
        return 1;
    endfunction

    // A randomised instruction with the sequence's class weights.
    function cpu_instr_item new_item();
        cpu_instr_item it = cpu_instr_item::type_id::create("it");
        it.w_alu_r = w_alu_r; it.w_alu_i = w_alu_i; it.w_load = w_load; it.w_store = w_store;
        it.w_branch = w_branch; it.w_jal = w_jal; it.w_jalr = w_jalr; it.w_fpu = w_fpu;
        it.w_crypto = w_crypto; it.w_rsvd = w_rsvd; it.p_dc = p_dc;
        return it;
    endfunction

    function logic [15:0] rand_instr();
        cpu_instr_item it = new_item();
        if (!it.randomize()) `uvm_fatal("RAND", "cpu_instr_item randomize failed")
        return it.encode();
    endfunction

    function logic [15:0] rand_instr_of(cpu_op_e want);
        cpu_instr_item it = new_item();
        it.c_op_dist.constraint_mode(0);      // the opcode is fixed by the caller
        if (!it.randomize() with { op == want; }) `uvm_fatal("RAND", $sformatf("randomize failed (op=%s)", want.name()))
        return it.encode();
    endfunction

    // Replace the register in an architectural source slot / destination.
    static function logic [15:0] set_src(logic [15:0] w, int slot, bit [2:0] r);
        cpu_dec_t d = cpu_decode(w);
        if (slot == 0) begin
            if (d.cls == CL_BRANCH) w[11:9] = r; else w[8:6] = r;
        end
        else begin
            if (d.cls == CL_STORE) w[11:9] = r;
            else if (d.cls == CL_BRANCH) w[8:6] = r;
            else w[5:3] = r;
        end
        return w;
    endfunction

    static function logic [15:0] set_rd(logic [15:0] w, bit [2:0] r);
        w[11:9] = r;
        return w;
    endfunction

    // ------------------------------------------------------------- send --
    // Finalise the current program; returns 0 if it was rejected.
    task automatic send_program(output bit ok, input int rst_at = -1, input int rst_cond = 0);
        cpu_program_item p;
        cpu_ref_model    m;
        int              steps;
        ok = 0;
        if (code.size() > 250) begin
            `uvm_warning("SEQ", $sformatf("%s: program truncated from %0d words", tag, code.size()))
            while (code.size() > 250) void'(code.pop_back());
        end
        p = cpu_program_item::type_id::create(tag);
        p.tag = tag;
        foreach (code[i]) p.imem[i] = code[i];
        for (int i = code.size(); i < 256; i++) p.imem[i] = HALT_INSTR;
        foreach (p.dmem[i]) p.dmem[i] = dmem[i];
        foreach (p.regs[i]) p.regs[i] = regs[i];
        p.regs[0] = 0;
        p.n_instr = code.size();

        m = cpu_ref_model::type_id::create("precheck");
        m.load(p.imem, p.dmem, p.regs);
        steps = m.run_to_halt(4000);
        if (steps < 0) begin
            n_rejected++;
            `uvm_info("SEQ", $sformatf("%s rejected: no halt within 4000 steps", tag), UVM_HIGH)
            return;
        end
        // worst case 3 cycles per instruction (taken branch), plus pipeline fill
        p.max_cycles = 3 * steps + 40;
        if (rst_at >= 0) begin
            p.reset_at   = (rst_at < int'(p.max_cycles) - 4) ? rst_at : int'(p.max_cycles) / 2;
            p.reset_cond = rst_cond;
            p.max_cycles = 2 * p.max_cycles + 40;   // the program restarts from PC 0 after the pulse
        end
        start_item(p);
        finish_item(p);
        n_sent++;
        ok = 1;
    endtask

    task body();
        `uvm_fatal("SEQ", "cpu_base_seq::body must be overridden")
    endtask
endclass
