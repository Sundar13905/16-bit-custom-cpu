// ============================================================================
// cpu_seqs.svh : stimulus sequences
//
//   cpu_directed_seq  hand-written smoke programs
//   cpu_rand_seq      constrained-random programs with RAW-dependency bias
//   cpu_hazard_seq    systematic producer x consumer-slot x distance matrix
//                     (distance list configurable; {3} = seeded-bug hunt)
//   cpu_ctrl_seq      branches / jumps: all types, directions, taken-once
//                     backward loops, back-to-back redirects, call/return
//   cpu_mem_seq       loads / stores, address aliasing, store->load distance
//   cpu_fpu_seq       FADD / FMUL on binary16 corner values
//   cpu_crypto_seq    ENC / DEC chains and round trips
//   cpu_reset_seq     random straight-line programs with a mid-run reset
// ============================================================================

// ---------------------------------------------------------------------------
class cpu_directed_seq extends cpu_base_seq;
    `uvm_object_utils(cpu_directed_seq)
    function new(string name = "cpu_directed_seq"); super.new(name); endfunction

    task body();
        bit ok;
        // 1. arithmetic with forwarding (distances 1 and 2 only)
        begin_program("dir_alu");
        regs[1] = 16'd10; regs[2] = 16'd3;
        emit(cpu_encode(OP_ADD,  3, 1, 2, 0));     // R3 = 13
        emit(cpu_encode(OP_SUB,  4, 3, 2, 0));     // R4 = 10  (fwd EX/MEM)
        emit(cpu_encode(OP_SLL,  5, 3, 2, 0));     // R5 = 104 (fwd MEM/WB)
        emit(cpu_encode(OP_ADDI, 6, 4, 0, 4'hF));  // R6 = 9
        emit(cpu_encode(OP_SRAI, 7, 6, 0, 4'h1));  // R7 = 4
        send_program(ok);
        // 2. load / store / load-use
        begin_program("dir_mem");
        regs[1] = 16'd20; regs[2] = 16'h1234;
        emit(cpu_encode(OP_SH, 2, 1, 0, 4'd3));    // M[23] = 1234
        emit(cpu_encode(OP_LH, 3, 1, 0, 4'd3));    // R3 = 1234
        emit(cpu_encode(OP_ADD, 4, 3, 3, 0));      // load-use stall
        emit(cpu_encode(OP_SH, 4, 1, 0, 4'd4));    // M[24] = 2468
        send_program(ok);
        // 3. counted loop (backward BNE)
        begin_program("dir_loop");
        regs[1] = 16'd0; regs[2] = 16'd0;
        emit(cpu_encode(OP_ADDI, 1, 0, 0, 4'd5));  // R1 = 5
        emit(cpu_encode(OP_ADDI, 2, 2, 0, 4'd2));  // L: R2 += 2
        emit(cpu_encode(OP_ADDI, 1, 1, 0, 4'hF));  //    R1 -= 1
        emit(cpu_encode(OP_BNE,  1, 0, 0, 4'hE));  //    BNE R1,R0,L (-2)
        send_program(ok);
        // 4. FPU + crypto round trip
        begin_program("dir_fpu_crypto");
        regs[1] = 16'h3C00; regs[2] = 16'h4000;     // 1.0, 2.0
        emit(cpu_encode(OP_FADD, 3, 1, 2, 0));      // 3.0
        emit(cpu_encode(OP_FMUL, 4, 3, 2, 0));      // 6.0
        emit(cpu_encode(OP_ENC,  5, 4, 0, 0));
        emit(cpu_encode(OP_DEC,  6, 5, 0, 0));      // R6 == R4
        send_program(ok);
    endtask
endclass

// ---------------------------------------------------------------------------
class cpu_rand_seq extends cpu_base_seq;
    `uvm_object_utils(cpu_rand_seq)

    int unsigned min_len = 30, max_len = 90;
    int unsigned p_dep   = 45;   // % chance that a source reads a recent destination
    int unsigned p_back  = 15;   // % of branches / JALs with a backward offset
    int unsigned p_fpval = 25;   // % of programs initialised with binary16 values

    function new(string name = "cpu_rand_seq"); super.new(name); endfunction

    task body();
        int tries = 0;
        while (n_sent < n_programs && tries < 20 * n_programs) begin
            bit ok;
            int len = $urandom_range(min_len, max_len);
            tries++;
            begin_program($sformatf("%s_%0d", get_name(), n_sent), $urandom_range(0, 99) < p_fpval);
            for (int i = 0; i < len; i++) begin
                logic [15:0] w = rand_instr();
                cpu_dec_t    d = cpu_decode(w);
                for (int s = 0; s < 2; s++) begin
                    bit u = (s == 0) ? d.use1 : d.use2;
                    if (u && $urandom_range(0, 99) < p_dep) begin
                        int k = $urandom_range(1, 4);
                        if (i >= k) begin
                            cpu_dec_t pd = cpu_decode(code[i - k]);
                            if (pd.wr && pd.rd != 0) w = set_src(w, s, pd.rd);
                        end
                    end
                end
                if ((d.cls == CL_BRANCH || d.cls == CL_JAL) && $urandom_range(0, 99) >= p_back) begin
                    w[15]  = 1'b0;                        // forward offset 1..7
                    w[5:3] = 3'($urandom_range(1, 7));
                end
                emit(w);
            end
            send_program(ok, (reset_at >= 0) ? $urandom_range(5, 60) : -1, $urandom_range(0, 3));
        end
        `uvm_info("SEQ", $sformatf("%s: sent %0d programs, rejected %0d non-terminating", get_name(), n_sent, n_rejected), UVM_LOW)
    endtask
endclass

// ---------------------------------------------------------------------------
class cpu_hazard_seq extends cpu_base_seq;
    `uvm_object_utils(cpu_hazard_seq)

    int dists [$] = '{1, 2, 3, 4};
    int unsigned n_passes = 1;
    localparam int NPROD = 6, NCONS = 12;
    // producers : 0 ALU_R 1 ALU_I 2 LOAD 3 FPU 4 CRYPTO 5 LINK(JAL)
    // consumers : 0 R.a 1 R.b 2 I.a 3 LH.base 4 SH.base 5 SH.data 6 BR.a 7 BR.b
    //             8 JALR.base 9 FPU.a 10 FPU.b 11 ENC.a

    function new(string name = "cpu_hazard_seq"); super.new(name); endfunction

    function bit [2:0] other_reg(bit [2:0] a, bit [2:0] b = 0);
        bit [2:0] r;
        do r = 3'($urandom_range(1, 7)); while (r == a || r == b);
        return r;
    endfunction

    function void filler(bit [2:0] x, bit [2:0] y);
        bit [2:0] f = other_reg(x, y);
        emit(cpu_encode($urandom_range(0, 1) ? OP_ADDI : OP_ORI, f, other_reg(x, y), 0, 4'($urandom)));
    endfunction

    function void producer(int p, bit [2:0] x);
        case (p)
            0: emit(cpu_encode(cpu_op_e'($urandom_range(0, 7)), x, 3'($urandom), 3'($urandom), 0));
            1: emit(cpu_encode(cpu_op_e'($urandom_range(8, 15)), x, 3'($urandom), 0, 4'($urandom)));
            2: emit(cpu_encode(OP_LH, x, 3'($urandom), 0, 4'($urandom)));
            3: emit(cpu_encode($urandom_range(0, 1) ? OP_FADD : OP_FMUL, x, 3'($urandom), 3'($urandom), 0));
            4: emit(cpu_encode($urandom_range(0, 1) ? OP_ENC : OP_DEC, x, 3'($urandom), 0, 0));
            default: emit(cpu_encode(OP_JAL, x, 0, 0, 4'd1, 6'($urandom)));   // link, target = next
        endcase
    endfunction

    function void consumer(int c, bit [2:0] x, bit [2:0] y);
        case (c)
            0:  emit(cpu_encode(cpu_op_e'($urandom_range(0, 7)), 3'($urandom), x, y, 0));
            1:  emit(cpu_encode(cpu_op_e'($urandom_range(0, 7)), 3'($urandom), y, x, 0));
            2:  emit(cpu_encode(cpu_op_e'($urandom_range(8, 15)), 3'($urandom), x, 0, 4'($urandom)));
            3:  emit(cpu_encode(OP_LH, 3'($urandom), x, 0, 4'($urandom)));
            4:  emit(cpu_encode(OP_SH, y, x, 0, 4'($urandom)));
            5:  emit(cpu_encode(OP_SH, x, y, 0, 4'($urandom)));
            6:  emit(cpu_encode(cpu_op_e'($urandom_range(18, 21)), x, y, 0, 4'd1));   // target = next either way
            7:  emit(cpu_encode(cpu_op_e'($urandom_range(18, 21)), y, x, 0, 4'd1));
            9:  emit(cpu_encode($urandom_range(0, 1) ? OP_FADD : OP_FMUL, 3'($urandom), x, y, 0));
            10: emit(cpu_encode($urandom_range(0, 1) ? OP_FADD : OP_FMUL, 3'($urandom), y, x, 0));
            11: emit(cpu_encode($urandom_range(0, 1) ? OP_ENC : OP_DEC, 3'($urandom), x, 0, 0));
            default: ;
        endcase
    endfunction

    // JALR consumer: the producer must generate a valid return address so the
    // program continues at the instruction after the JALR.
    function void snippet(int cmb);
        int d = cmb >> 8, p = (cmb >> 4) & 15, c = cmb & 15;
        bit [2:0] x = 3'($urandom_range(1, 7));
        bit [2:0] y = other_reg(x);
        if (c == 8) jalr_snippet(p, d, x);
        else begin
            producer(p, x);
            for (int f = 1; f < d; f++) filler(x, y);
            consumer(c, x, y);
        end
        emit(cpu_encode(OP_ADDI, 0, 0, 0, 0));   // separator (writes R0)
    endfunction

    function void jalr_snippet(int p, int d, bit [2:0] x);
        bit [2:0] v = other_reg(x);
        int setup = (p == 2 || p == 5) ? 0 : 1;
        logic [15:0] target = 16'(pc_now() + setup + 1 + (d - 1) + 1);
        case (p)
            0: begin void'(load_const(v, target)); emit(cpu_encode(OP_ADD,  x, v, 0, 0)); end
            1: begin void'(load_const(v, target)); emit(cpu_encode(OP_ORI,  x, v, 0, 0)); end
            2: void'(load_const(x, target));
            3: begin void'(load_const(v, target)); emit(cpu_encode(OP_FADD, x, v, 0, 0)); end
            4: begin void'(load_const(v, ref_dec(target))); emit(cpu_encode(OP_ENC, x, v, 0, 0)); end
            default: emit(cpu_encode(OP_JAL, x, 0, 0, 4'd1));
        endcase
        for (int f = 1; f < d; f++) filler(x, v);
        emit(cpu_encode(OP_JALR, $urandom_range(0, 1) ? 3'd0 : other_reg(x, v), x, 0,
                        (p == 5) ? 4'(d) : 4'd0));
    endfunction

    task body();
        int combos [$], solo [$];
        bit ok;
        for (int pass = 0; pass < n_passes; pass++)
            foreach (dists[k])
                for (int p = 0; p < NPROD; p++)
                    for (int c = 0; c < NCONS; c++) begin
                        int cmb = (dists[k] << 8) | (p << 4) | c;
                        // a JALR that consumes its base inside the WB->ID window of the
                        // seeded bug jumps to a stale address; give it its own program
                        // so the redirection cannot derail other snippets
                        if (c == 8 && ((p != 5 && dists[k] == 3) || (p == 5 && dists[k] == 1)))
                            solo.push_back(cmb);
                        else
                            combos.push_back(cmb);
                    end
        combos.shuffle();
        begin_program($sformatf("%s_%0d", get_name(), n_sent));
        foreach (combos[i]) begin
            if (code.size() > 220 || next_slot >= 15) begin
                send_program(ok);
                begin_program($sformatf("%s_%0d", get_name(), n_sent));
            end
            snippet(combos[i]);
        end
        send_program(ok);
        foreach (solo[i]) begin
            begin_program($sformatf("%s_solo_%0d", get_name(), n_sent));
            snippet(solo[i]);
            send_program(ok);
        end
        `uvm_info("SEQ", $sformatf("%s: %0d snippets in %0d programs (rejected %0d)", get_name(),
                                   combos.size() + solo.size(), n_sent, n_rejected), UVM_LOW)
    endtask
endclass

// ---------------------------------------------------------------------------
class cpu_ctrl_seq extends cpu_base_seq;
    `uvm_object_utils(cpu_ctrl_seq)
    function new(string name = "cpu_ctrl_seq"); super.new(name); endfunction

    // R7 holds the constant 5 for the whole program, R6/R5 are jump bases
    function void fill1();
        emit(cpu_encode(OP_ORI, 3'($urandom_range(1, 4)), 3'($urandom_range(0, 4)), 0, 4'($urandom)));
    endfunction

    function cpu_op_e any_branch();
        return cpu_op_e'($urandom_range(int'(OP_BEQ), int'(OP_BRX)));
    endfunction

    function void fwd_branch();
        int k = $urandom_range(1, 7);
        emit(cpu_encode(any_branch(), 3'($urandom_range(0, 7)), 3'($urandom_range(0, 7)), 0, 4'(k),
                        0, 3'($urandom_range(0, 1) ? 3'b010 : 3'($urandom_range(5, 7)))));
        for (int i = 1; i < k; i++) fill1();
    endfunction

    function void zero_ofs_not_taken();
        cpu_op_e op = any_branch();
        // R7 == 5 (never written), R0 == 0 -> each form below is false
        case (op)
            OP_BEQ, OP_BRX: emit(cpu_encode(op, 0, 7, 0, 0, 0, 3'b110));
            OP_BNE:         emit(cpu_encode(op, 7, 7, 0, 0));
            OP_BLT:         emit(cpu_encode(op, 7, 0, 0, 0));
            default:        emit(cpu_encode(op, 0, 7, 0, 0));   // BGE 0 >= 5 false
        endcase
    endfunction

    // backward branch taken exactly once: Rf counts 1,2 ; Rk constant
    function void taken_once_loop();
        cpu_op_e op = any_branch();
        int nf = $urandom_range(0, 1) ? 0 : 1;
        emit(cpu_encode(OP_ADDI, 2, 0, 0, 4'd0));                               // Rf = 0
        case (op)
            OP_BNE, OP_BLT: emit(cpu_encode(OP_ADDI, 1, 0, 0, 4'd2));           // Rk = 2
            default:        emit(cpu_encode(OP_ADDI, 1, 0, 0, 4'd1));           // Rk = 1
        endcase
        // spacers keep Rf/Rk producers >= 4 instructions away from their
        // consumers, outside the WB->ID window of the seeded bug
        repeat (3) emit(cpu_encode(OP_ADDI, 4, 0, 0, 4'($urandom)));
        emit(cpu_encode(OP_ADDI, 2, 2, 0, 4'd1));                                // L: Rf++
        for (int i = 0; i < nf; i++) emit(cpu_encode(OP_ORI, 3, 4, 0, 4'($urandom)));
        case (op)
            OP_BGE:  emit(cpu_encode(op, 1, 2, 0, 4'(-(nf + 1))));              // Rk >= Rf
            default: emit(cpu_encode(op, 2, 1, 0, 4'(-(nf + 1)), 0, 3'b111));    // Rf ? Rk
        endcase
    endfunction

    // prev redirect (0 BR, 1 JAL, 2 JALR) landing on cur control (0 BR, 1 JAL, 2 JALR)
    function void back_to_back(int prev, int cur);
        int base = pc_now();
        // constants first (JALR targets), so the addresses below are fixed
        int n_const = (prev == 2) + (cur == 2);
        int t_cur   = base + n_const + 2;     // address of the 'cur' instruction
        int t_after = t_cur + 2;              // continuation after cur's redirect
        if (prev == 2) void'(load_const(6, 16'(t_cur)));
        if (cur  == 2) void'(load_const(5, 16'(t_after)));
        case (prev)
            0: emit(cpu_encode(OP_BEQ, 0, 0, 0, 4'd2));
            1: emit(cpu_encode(OP_JAL, $urandom_range(0, 1) ? 3'd0 : 3'd3, 0, 0, 4'd2));
            2: emit(cpu_encode(OP_JALR, 0, 6, 0, 4'd0));
        endcase
        fill1();                                                                  // skipped
        case (cur)
            0: emit(cpu_encode(OP_BNE, 7, 0, 0, 4'd2));                          // 5 != 0 taken
            1: emit(cpu_encode(OP_JAL, 0, 0, 0, 4'd2));
            2: emit(cpu_encode(OP_JALR, 0, 5, 0, 4'd0));
        endcase
        fill1();                                                                  // skipped
    endfunction

    function void backward_jumps();
        int i;
        void'(load_const(5, 16'(pc_now() + 2)));    // JALR target = i+1
        i = pc_now();
        emit(cpu_encode(OP_JAL, 0, 0, 0, 4'd2));    // i   : -> i+2
        emit(cpu_encode(OP_JAL, 0, 0, 0, 4'd3));    // i+1 : -> i+4 (exit)
        if ($urandom_range(0, 1))
            emit(cpu_encode(OP_JAL, $urandom_range(0, 1) ? 3'd0 : 3'd3, 0, 0, 4'hF));  // i+2: back to i+1
        else
            emit(cpu_encode(OP_JALR, $urandom_range(0, 1) ? 3'd0 : 3'd3, 5, 0, 4'd0)); // i+2: back to i+1
        fill1();                                    // i+3 : skipped
    endfunction

    // Backward redirect with offset -k (k = 1..8) and a JALR exit with a
    // random immediate:
    //   E  : JALR R0, R6, 0       -> B          (R6 preloaded with B)
    //   E+1: JALR R0, R5, imm     -> B+1 (exit) (R5 preloaded with B+1-imm)
    //   ... k-1 skipped words ...
    //   B  : JAL R0,-k / Bxx(taken),-k  -> E+1
    function void backward_any();
        int          k   = $urandom_range(1, 8);
        bit [3:0]    imm = 4'($urandom);
        int          e, b;
        e = pc_now() + 2;                 // two constant loads first
        b = e + k + 1;
        void'(load_const(6, 16'(b)));
        void'(load_const(5, 16'(b + 1) - sext4(imm)));
        emit(cpu_encode(OP_JALR, 0, 6, 0, 4'd0));
        emit(cpu_encode(OP_JALR, $urandom_range(0, 1) ? 3'd0 : 3'd4, 5, 0, imm));
        for (int i = 1; i < k; i++) fill1();
        case ($urandom_range(0, 5))
            0: emit(cpu_encode(OP_JAL, $urandom_range(0, 1) ? 3'd0 : 3'd3, 0, 0, 4'(-k)));
            1: emit(cpu_encode(OP_BEQ, 0, 0, 0, 4'(-k)));
            2: emit(cpu_encode(OP_BNE, 7, 0, 0, 4'(-k)));
            3: emit(cpu_encode(OP_BLT, 0, 7, 0, 4'(-k)));
            4: emit(cpu_encode(OP_BGE, 7, 0, 0, 4'(-k)));
            5: emit(cpu_encode(OP_BRX, 0, 0, 0, 4'(-k), 0, 3'($urandom_range(5, 7))));
        endcase
    endfunction

    function void call_return();
        emit(cpu_encode(OP_JAL, 6, 0, 0, 4'd2));    // i   : call i+2, R6 = i+1
        emit(cpu_encode(OP_JAL, 0, 0, 0, 4'd3));    // i+1 : -> i+4
        fill1();                                    // i+2 : subroutine body
        emit(cpu_encode(OP_JALR, 0, 6, 0, 4'd0));   // i+3 : return
    endfunction

    task body();
        int b2b [$];
        bit ok;
        for (int i = 0; i < 9; i++) b2b.push_back(i);
        while (n_sent < n_programs) begin
            begin_program($sformatf("%s_%0d", get_name(), n_sent));
            regs[7] = 16'd5;
            b2b.shuffle();
            for (int k = 0; k < 9; k++) back_to_back(b2b[k] / 3, b2b[k] % 3);
            repeat (2) backward_jumps();
            repeat (3) backward_any();
            repeat (2) call_return();
            repeat (6) begin
                case ($urandom_range(0, 2))
                    0: fwd_branch();
                    1: taken_once_loop();
                    2: zero_ofs_not_taken();
                endcase
                fwd_branch();
            end
            // absolute jump through R0 into the aliased top of IMEM
            // (PC 0xFFF8..0xFFFF fetches words 248..255, which hold halts)
            emit(cpu_encode(OP_JALR, $urandom_range(0, 1) ? 3'd0 : 3'd3, 0, 0, 4'($urandom_range(8, 15))));
            send_program(ok);
        end
    endtask
endclass

// ---------------------------------------------------------------------------
class cpu_mem_seq extends cpu_base_seq;
    `uvm_object_utils(cpu_mem_seq)
    function new(string name = "cpu_mem_seq"); super.new(name); endfunction

    task body();
        bit ok;
        while (n_sent < n_programs) begin
            begin_program($sformatf("%s_%0d", get_name(), n_sent));
            regs[1] = 16'h0000; regs[2] = 16'h00F8; regs[3] = 16'h0100 + 16'($urandom_range(0, 255));
            regs[4] = 16'($urandom);
            for (int n = 0; n < 25; n++) begin
                bit [2:0] b   = 3'($urandom_range(0, 4));
                bit [3:0] imm = 4'($urandom);
                int       dd  = $urandom_range(1, 5);
                // occasionally hit the exact boundaries
                case ($urandom_range(0, 5))
                    0: begin b = 1; imm = 0; end              // address 0
                    1: begin b = 2; imm = 7; end              // address 255 (in range)
                    2: begin b = 0; imm = 4'hF; end           // 0xFFFF -> 255 aliased
                    default: ;
                endcase
                emit(cpu_encode(OP_SH, 3'($urandom_range(0, 7)), b, 0, imm, 6'($urandom)));
                for (int f = 1; f < dd; f++)
                    emit(cpu_encode(OP_ADDI, 3'($urandom_range(5, 7)), 3'($urandom_range(5, 7)), 0, 4'($urandom)));
                emit(cpu_encode(OP_LH, 3'($urandom_range(5, 7)), b, 0, imm, 6'($urandom)));
                if ($urandom_range(0, 2) == 0)
                    emit(cpu_encode(OP_ADD, 3'($urandom_range(5, 7)), 3'($urandom), 3'($urandom), 0));
            end
            send_program(ok);
        end
    endtask
endclass

// ---------------------------------------------------------------------------
class cpu_fpu_seq extends cpu_base_seq;
    `uvm_object_utils(cpu_fpu_seq)
    int unsigned len = 120;
    function new(string name = "cpu_fpu_seq"); super.new(name); endfunction

    task body();
        bit ok;
        while (n_sent < n_programs) begin
            begin_program($sformatf("%s_%0d", get_name(), n_sent), 1);
            // constant pool: pairs (x, -x) and huge / tiny values
            for (int s = 0; s < 8; s += 2) begin
                logic [15:0] v = rand_fp_val();
                dmem[s] = v; dmem[s + 1] = v ^ 16'h8000;
            end
            dmem[6]   = 16'h3DA8; dmem[7]   = 16'hBDA8;  // 1.4140625^2 rounds up to 2.0 (significand carry-out)
            dmem[248] = 16'h7800; dmem[249] = 16'h7A00;  // 32768, 49152: sums overflow
            dmem[250] = 16'h0C00; dmem[251] = 16'h1000;  // 2^-12, 2^-11: products underflow
            dmem[252] = 16'h3C01; dmem[253] = 16'h3BFF;  // 1+ulp, 1-ulp/2: rounding
            dmem[254] = 16'h0401 + 16'($urandom_range(0, 255));          // small normals of
            dmem[255] = 16'h8400 + 16'($urandom_range(0, 255));          // opposite sign
            for (int i = 0; i < len; i++) begin
                bit [2:0] rd = 3'($urandom_range(1, 7));
                if ($urandom_range(0, 3) == 0)
                    emit(cpu_encode(OP_LH, rd, 0, 0, 4'($urandom)));
                else
                    emit(cpu_encode($urandom_range(0, 1) ? OP_FADD : OP_FMUL, rd,
                                    3'($urandom_range(0, 7)), 3'($urandom_range(0, 7)), 0, 6'($urandom)));
            end
            send_program(ok);
        end
    endtask
endclass

// ---------------------------------------------------------------------------
class cpu_crypto_seq extends cpu_base_seq;
    `uvm_object_utils(cpu_crypto_seq)
    int unsigned len = 60;
    function new(string name = "cpu_crypto_seq"); super.new(name); endfunction

    task body();
        bit ok;
        while (n_sent < n_programs) begin
            bit [2:0] last = 1;
            begin_program($sformatf("%s_%0d", get_name(), n_sent));
            regs[1] = 16'h0000; regs[2] = 16'hFFFF;
            for (int i = 0; i < len; i++) begin
                bit [2:0] rd  = 3'($urandom_range(1, 7));
                bit [2:0] src = ($urandom_range(0, 99) < 60) ? last : 3'($urandom_range(0, 7));
                case ($urandom_range(0, 5))
                    0: emit(rand_instr_of(cpu_op_e'($urandom_range(0, 15))));
                    1: emit(cpu_encode(OP_LH, rd, 0, 0, 4'($urandom)));
                    default: emit(cpu_encode($urandom_range(0, 1) ? OP_ENC : OP_DEC, rd, src, 0, 0, 6'($urandom)));
                endcase
                last = rd;
            end
            send_program(ok);
        end
    endtask
endclass

// ---------------------------------------------------------------------------
class cpu_reset_seq extends cpu_rand_seq;
    `uvm_object_utils(cpu_reset_seq)
    function new(string name = "cpu_reset_seq");
        super.new(name);
        reset_at = 0;      // enables a random reset point per program
        p_back   = 0;      // straight-line + forward branches: always terminates
        w_jalr   = 0;
    endfunction
endclass
