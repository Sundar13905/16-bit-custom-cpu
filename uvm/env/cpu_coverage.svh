// ============================================================================
// cpu_coverage.svh : functional coverage model.
//
// Sampled from the monitor's retire stream (what the DUT actually executed,
// including forwarding / stall information observed in the pipeline) and from
// the driver's control stream (program start, mid-program reset).
//
// The Verilator 5.052 flow does not support explicit bins / ignore_bins inside a
// 'cross', so crosses that contain impossible combinations are written as a
// single coverpoint over an encoded value with an explicit list of legal
// bins ("flattened cross").  Every bin in this file is reachable; nothing is
// excluded to inflate the score.
// ============================================================================

// Category encodings shared with the report generator ------------------------
// integer operand category
function automatic int val_cat(logic [15:0] v);
    if (v == 16'h0000) return 0;          // zero
    if (v == 16'h0001) return 1;          // one
    if (v == 16'hFFFF) return 2;          // all ones (-1)
    if (v == 16'h7FFF) return 3;          // max positive
    if (v == 16'h8000) return 4;          // min negative
    if (v[15] == 1'b0) return 5;          // other positive
    return 6;                             // other negative
endfunction

class cpu_coverage extends uvm_component;
    `uvm_component_utils(cpu_coverage)

    uvm_analysis_imp_retire #(cpu_retire_txn, cpu_coverage) retire_imp;
    uvm_analysis_imp_ctrl   #(cpu_ctrl_txn,   cpu_coverage) ctrl_imp;

    // retired-instruction history for dependency analysis (index 0 = newest)
    cpu_retire_txn hist [$];
    // last store per address (dynamic index), for store->load distance
    longint unsigned last_store_idx [int];
    longint unsigned dyn_idx;
    bit              first_after_reset;

    // ======================================================================
    // 1. Opcode coverage: every instruction of the ISA was executed
    covergroup cg_opcode with function sample(int op);
        option.per_instance = 1;
        cp_op : coverpoint op {
            bins ADD  = {OP_ADD};  bins SUB  = {OP_SUB};  bins SLT  = {OP_SLT};  bins SRL  = {OP_SRL};
            bins OR   = {OP_OR};   bins SLL  = {OP_SLL};  bins AND  = {OP_AND};  bins SRA  = {OP_SRA};
            bins ADDI = {OP_ADDI}; bins SUBI = {OP_SUBI}; bins SLTI = {OP_SLTI}; bins SRLI = {OP_SRLI};
            bins ORI  = {OP_ORI};  bins SLLI = {OP_SLLI}; bins ANDI = {OP_ANDI}; bins SRAI = {OP_SRAI};
            bins LH   = {OP_LH};   bins SH   = {OP_SH};
            bins BEQ  = {OP_BEQ};  bins BNE  = {OP_BNE};  bins BLT  = {OP_BLT};  bins BGE  = {OP_BGE};
            bins BRX  = {OP_BRX};  bins JAL  = {OP_JAL};  bins JALR = {OP_JALR};
            bins FADD = {OP_FADD}; bins FMUL = {OP_FMUL}; bins ENC  = {OP_ENC};  bins DEC  = {OP_DEC};
            bins RSVD = {OP_RSVD};
        }
    endgroup

    // 2. Register-field coverage per instruction class
    covergroup cg_rd with function sample(int cls, int r);
        option.per_instance = 1;
        cp_cls : coverpoint cls {
            bins alu_r = {CL_ALU_R}; bins alu_i = {CL_ALU_I}; bins load = {CL_LOAD};
            bins jal = {CL_JAL}; bins jalr = {CL_JALR}; bins fpu = {CL_FPU}; bins crypto = {CL_CRYPTO};
        }
        cp_reg : coverpoint r { bins r[] = {[0:7]}; }
        x_cls_reg : cross cp_cls, cp_reg;
    endgroup

    covergroup cg_rs1 with function sample(int cls, int r);
        option.per_instance = 1;
        cp_cls : coverpoint cls {
            bins alu_r = {CL_ALU_R}; bins alu_i = {CL_ALU_I}; bins load = {CL_LOAD}; bins store_base = {CL_STORE};
            bins branch = {CL_BRANCH}; bins jalr = {CL_JALR}; bins fpu = {CL_FPU}; bins crypto = {CL_CRYPTO};
        }
        cp_reg : coverpoint r { bins r[] = {[0:7]}; }
        x_cls_reg : cross cp_cls, cp_reg;
    endgroup

    covergroup cg_rs2 with function sample(int cls, int r);
        option.per_instance = 1;
        cp_cls : coverpoint cls {
            bins alu_r = {CL_ALU_R}; bins store_data = {CL_STORE}; bins branch = {CL_BRANCH}; bins fpu = {CL_FPU};
        }
        cp_reg : coverpoint r { bins r[] = {[0:7]}; }
        x_cls_reg : cross cp_cls, cp_reg;
    endgroup

    // 3. Immediate / offset coverage (all 16 values of the 4-bit field)
    covergroup cg_imm with function sample(int cls, int imm4);
        option.per_instance = 1;
        cp_cls : coverpoint cls {
            bins alu_i = {CL_ALU_I}; bins load = {CL_LOAD}; bins store = {CL_STORE};
            bins branch = {CL_BRANCH}; bins jal = {CL_JAL}; bins jalr = {CL_JALR};
        }
        cp_imm : coverpoint imm4 { bins v[] = {[0:15]}; }
        x_cls_imm : cross cp_cls, cp_imm;
    endgroup

    // 4. Integer ALU operand / result coverage
    covergroup cg_alu with function sample(int fn, bit is_imm, int acat, int rcat);
        option.per_instance = 1;
        cp_fn   : coverpoint fn   { bins f[] = {[0:7]}; }
        cp_kind : coverpoint is_imm { bins reg_reg = {0}; bins reg_imm = {1}; }
        cp_acat : coverpoint acat { bins zero = {0}; bins one = {1}; bins neg1 = {2}; bins maxpos = {3};
                                    bins minneg = {4}; bins pos = {5}; bins neg = {6}; }
        cp_rzero : coverpoint rcat { bins zero = {0}; bins nonzero = {[1:6]}; }
        x_fn_kind : cross cp_fn, cp_kind;
        x_fn_a    : cross cp_fn, cp_acat;
        x_fn_rz   : cross cp_fn, cp_rzero;
    endgroup

    // operand B corners (register-register forms only)
    covergroup cg_alu_b with function sample(int fn, int bcat);
        option.per_instance = 1;
        cp_fn   : coverpoint fn   { bins f[] = {[0:7]}; }
        cp_bcat : coverpoint bcat { bins zero = {0}; bins one = {1}; bins neg1 = {2}; bins maxpos = {3};
                                    bins minneg = {4}; bins pos = {5}; bins neg = {6}; }
        x_fn_b  : cross cp_fn, cp_bcat;
    endgroup

    covergroup cg_shift with function sample(int fn, int shamt);
        option.per_instance = 1;
        cp_sfn : coverpoint fn { bins srl = {3}; bins sll = {5}; bins sra = {7}; }
        cp_sh  : coverpoint shamt { bins s[] = {[0:15]}; }
        x_shift : cross cp_sfn, cp_sh;
    endgroup

    // SLT/SLTI signed compare and add/sub overflow corners (flattened)
    covergroup cg_arith with function sample(int ev);
        option.per_instance = 1;
        cp_ev : coverpoint ev {
            bins slt_pp_lt = {0}; bins slt_pp_ge = {1}; bins slt_nn_lt = {2}; bins slt_nn_ge = {3};
            bins slt_np_lt = {4}; bins slt_pn_ge = {5}; bins slt_eq   = {6};
            bins add_signed_ovf = {10}; bins add_carry_out = {11};
            bins sub_signed_ovf = {12}; bins sub_borrow    = {13};
        }
    endgroup

    // 5. Branch coverage
    covergroup cg_branch with function sample(int bt, bit taken, int dir);
        option.per_instance = 1;
        cp_bt    : coverpoint bt { bins beq = {0}; bins bne = {1}; bins blt = {2}; bins bge = {3}; bins alias_beq = {4}; }
        cp_taken : coverpoint taken { bins not_taken = {0}; bins taken = {1}; }
        cp_dir   : coverpoint dir { bins forward = {1}; bins backward = {2}; bins zero_ofs_not_taken = {0}; }
        x_bt_taken : cross cp_bt, cp_taken;
        x_bt_dir   : cross cp_bt, cp_dir;
    endgroup

    // signed relation of the branch operands for BLT/BGE (flattened)
    covergroup cg_bcmp with function sample(int ev);
        option.per_instance = 1;
        // ev = (is_bge*5) + rel ; rel: 0 eq, 1 lt same-sign, 2 lt neg<nonneg, 3 gt same-sign, 4 gt nonneg>neg
        cp_ev : coverpoint ev {
            bins blt_eq = {0}; bins blt_lt_same = {1}; bins blt_lt_mixed = {2}; bins blt_gt_same = {3}; bins blt_gt_mixed = {4};
            bins bge_eq = {5}; bins bge_lt_same = {6}; bins bge_lt_mixed = {7}; bins bge_gt_same = {8}; bins bge_gt_mixed = {9};
        }
    endgroup

    // 6. Jumps
    covergroup cg_jump with function sample(bit is_jalr, int dir, bit link_r0);
        option.per_instance = 1;
        cp_jt   : coverpoint is_jalr { bins jal = {0}; bins jalr = {1}; }
        cp_dir  : coverpoint dir { bins forward = {1}; bins backward = {2}; }
        cp_link : coverpoint link_r0 { bins link_r0 = {1}; bins link_rn = {0}; }
        x_jt_dir  : cross cp_jt, cp_dir;
        x_jt_link : cross cp_jt, cp_link;
    endgroup

    covergroup cg_jalr_base with function sample(int fwd);
        option.per_instance = 1;
        cp_bfwd : coverpoint fwd { bins rf = {0}; bins ex_mem = {1}; bins mem_wb = {2}; }
    endgroup

    // 7. Memory
    covergroup cg_mem with function sample(bit is_store, int region, bit aliased);
        option.per_instance = 1;
        cp_ls     : coverpoint is_store { bins load = {0}; bins store = {1}; }
        cp_region : coverpoint region { bins addr_0 = {0}; bins addr_mid = {1}; bins addr_255 = {2}; }
        cp_alias  : coverpoint aliased { bins in_range = {0}; bins aliased_hi = {1}; }
        x_ls_region : cross cp_ls, cp_region;
        x_ls_alias  : cross cp_ls, cp_alias;
    endgroup

    covergroup cg_st_ld with function sample(int dd);
        option.per_instance = 1;
        cp_dist : coverpoint dd { bins d1 = {1}; bins d2 = {2}; bins d3 = {3}; bins d4_8 = {[4:8]}; }
    endgroup

    // 8. Pipeline hazards: forwarding, load-use stalls, RAW distance
    covergroup cg_fwd_a with function sample(int cls, int fwd);
        option.per_instance = 1;
        cp_cls : coverpoint cls {
            bins alu_r = {CL_ALU_R}; bins alu_i = {CL_ALU_I}; bins load = {CL_LOAD}; bins store_base = {CL_STORE};
            bins branch = {CL_BRANCH}; bins jalr = {CL_JALR}; bins fpu = {CL_FPU}; bins crypto = {CL_CRYPTO};
        }
        cp_fwd : coverpoint fwd { bins none = {0}; bins ex_mem = {1}; bins mem_wb = {2}; }
        x_cls_fwd : cross cp_cls, cp_fwd;
    endgroup

    covergroup cg_fwd_b with function sample(int cls, int fwd);
        option.per_instance = 1;
        cp_cls : coverpoint cls {
            bins alu_r = {CL_ALU_R}; bins store_data = {CL_STORE}; bins branch = {CL_BRANCH}; bins fpu = {CL_FPU};
        }
        cp_fwd : coverpoint fwd { bins none = {0}; bins ex_mem = {1}; bins mem_wb = {2}; }
        x_cls_fwd : cross cp_cls, cp_fwd;
    endgroup

    covergroup cg_fwd_both with function sample(int ev);
        option.per_instance = 1;
        cp_ev : coverpoint ev { bins exmem_exmem = {5}; bins exmem_memwb = {6}; bins memwb_exmem = {9}; bins memwb_memwb = {10}; }
    endgroup

    covergroup cg_loaduse with function sample(int ev);
        option.per_instance = 1;
        // consumer of a load in the next instruction (1-cycle stall)
        cp_ev : coverpoint ev {
            bins alu_r_a = {0};  bins alu_r_b = {1};  bins alu_i = {2};   bins load_base = {3};
            bins store_base = {4}; bins store_data = {5}; bins branch_a = {6}; bins branch_b = {7};
            bins jalr_base = {8}; bins fpu_a = {9};   bins fpu_b = {10};  bins crypto = {11};
        }
    endgroup

    covergroup cg_raw with function sample(int pcls, int dd);
        option.per_instance = 1;
        // producer: 0 ALU, 1 LOAD, 2 FPU, 3 CRYPTO, 4 LINK (JAL/JALR)
        cp_prod : coverpoint pcls { bins alu = {0}; bins load = {1}; bins fpu = {2}; bins crypto = {3}; bins link = {4}; }
        cp_dist : coverpoint dd { bins d1 = {1}; bins d2 = {2}; bins d3 = {3}; bins d4 = {4}; }
        x_raw   : cross cp_prod, cp_dist;
    endgroup

    // WB->ID same-cycle register write/read (the window of the seeded bug)
    covergroup cg_wbid with function sample(int ev);
        option.per_instance = 1;
        cp_ev : coverpoint ev {
            bins collide_fwd_a  = {0};   // collision, newer value forwarded in EX (masked)
            bins collide_fwd_b  = {1};
            bins collide_stale_a = {2};  // collision consumed through the RF port (bug window)
            bins collide_stale_b = {3};
        }
    endgroup

    // 9. Control flow / flush interactions (flattened prev x cur)
    covergroup cg_ctrl with function sample(int ev);
        option.per_instance = 1;
        // ev = prev*3 + cur, prev = control type that redirected to this instruction
        // (0 taken branch, 1 JAL, 2 JALR); cur = 0 branch, 1 JAL, 2 JALR at the target
        cp_ev : coverpoint ev {
            bins br_br = {0}; bins br_jal = {1}; bins br_jalr = {2};
            bins jal_br = {3}; bins jal_jal = {4}; bins jal_jalr = {5};
            bins jalr_br = {6}; bins jalr_jal = {7}; bins jalr_jalr = {8};
        }
    endgroup

    covergroup cg_flush with function sample(int cause);
        option.per_instance = 1;
        cp_cause : coverpoint cause { bins branch = {0}; bins jal = {1}; bins jalr = {2}; bins load_use_then_taken_branch = {3}; }
    endgroup

    // 10. FPU
    covergroup cg_fpu with function sample(bit is_mul, int ca, int cb, int cr, int signs);
        option.per_instance = 1;
        cp_op : coverpoint is_mul { bins fadd = {0}; bins fmul = {1}; }
        cp_ca : coverpoint ca { bins zero = {FPC_ZERO}; bins sub = {FPC_SUB}; bins norm = {FPC_NORM}; bins inf = {FPC_INF}; bins nan = {FPC_NAN}; }
        cp_cb : coverpoint cb { bins zero = {FPC_ZERO}; bins sub = {FPC_SUB}; bins norm = {FPC_NORM}; bins inf = {FPC_INF}; bins nan = {FPC_NAN}; }
        cp_cr : coverpoint cr { bins zero = {FPC_ZERO}; bins sub = {FPC_SUB}; bins norm = {FPC_NORM}; bins inf = {FPC_INF}; bins nan = {FPC_NAN}; }
        cp_sg : coverpoint signs { bins pp = {0}; bins pn = {1}; bins np = {2}; bins nn = {3}; }
        x_op_a_b : cross cp_op, cp_ca, cp_cb;
        x_op_res : cross cp_op, cp_cr;
        x_op_sg  : cross cp_op, cp_sg;
    endgroup

    covergroup cg_fpu_ev with function sample(int ev);
        option.per_instance = 1;
        cp_ev : coverpoint ev {
            bins add_overflow   = {0};  // finite + finite -> Inf
            bins add_cancel     = {1};  // x + (-x) -> +0
            bins add_round_up   = {2};  // inexact, magnitude rounded up
            bins add_round_down = {3};  // inexact, magnitude truncated
            bins add_sub_result = {4};  // normal operands, subnormal result
            bins mul_overflow   = {5};
            bins mul_uflow_zero = {6};  // non-zero finite operands -> 0
            bins mul_uflow_sub  = {7};  // normal operands -> subnormal
            bins mul_round_up   = {8};
            bins mul_round_down = {9};
            bins mul_exact      = {10};
            bins inf_minus_inf  = {11};
            bins inf_times_zero = {12};
        }
    endgroup

    // 11. Crypto
    covergroup cg_crypto with function sample(bit is_dec, int icat, int chain);
        option.per_instance = 1;
        cp_op   : coverpoint is_dec { bins enc = {0}; bins dec = {1}; }
        cp_in   : coverpoint icat { bins zero = {0}; bins ones = {2}; bins other = {[1:1], [3:6]}; }
        cp_chain: coverpoint chain { bins dec_of_enc = {1}; bins enc_of_dec = {2}; bins enc_of_enc = {3}; bins dec_of_dec = {4}; }
        x_op_in : cross cp_op, cp_in;
    endgroup

    // 12. Decode robustness: reserved / alias encodings and don't-care fields
    covergroup cg_decode with function sample(int ev);
        option.per_instance = 1;
        cp_ev : coverpoint ev {
            bins rsvd_f4 = {4}; bins rsvd_f5 = {5}; bins rsvd_f6 = {6}; bins rsvd_f7 = {7};
            bins bralias_f2 = {12}; bins bralias_f5 = {15}; bins bralias_f6 = {16}; bins bralias_f7 = {17};
            bins dc_alu_r = {20 + CL_ALU_R}; bins dc_load = {20 + CL_LOAD}; bins dc_store = {20 + CL_STORE};
            bins dc_jal = {20 + CL_JAL}; bins dc_jalr = {20 + CL_JALR}; bins dc_fpu = {20 + CL_FPU};
            bins dc_crypto = {20 + CL_CRYPTO};
            bins write_r0 = {40};
        }
    endgroup

    // 13. Reset
    covergroup cg_reset with function sample(int ev);
        option.per_instance = 1;
        cp_ev : coverpoint ev {
            bins reset_mid_program = {0}; bins reset_store_in_mem = {1};
            bins reset_ctrl_in_ex  = {2}; bins reset_during_stall = {3};
            bins restart_at_pc0    = {4};
        }
    endgroup

    // ======================================================================
    function new(string name, uvm_component parent);
        super.new(name, parent);
        retire_imp = new("retire_imp", this);
        ctrl_imp   = new("ctrl_imp", this);
        cg_opcode = new(); cg_rd = new(); cg_rs1 = new(); cg_rs2 = new(); cg_imm = new();
        cg_alu = new(); cg_alu_b = new(); cg_shift  = new(); cg_arith = new();
        cg_branch = new(); cg_bcmp = new(); cg_jump = new(); cg_jalr_base = new();
        cg_mem = new(); cg_st_ld = new(); cg_fwd_a = new(); cg_fwd_b = new();
        cg_fwd_both = new(); cg_loaduse = new(); cg_raw = new(); cg_wbid = new();
        cg_ctrl   = new(); cg_flush = new();  cg_fpu = new();   cg_fpu_ev = new();
        cg_crypto = new(); cg_decode = new(); cg_reset = new();
    endfunction

    function void write_ctrl(cpu_ctrl_txn t);
        if (t.kind == CTRL_START || t.kind == CTRL_RESYNC) begin
            hist.delete();
            last_store_idx.delete();
        end
        if (t.kind == CTRL_RESYNC) begin
            cg_reset.sample(0);
            if (t.rst_store_in_mem) cg_reset.sample(1);
            if (t.rst_ctrl_in_ex)   cg_reset.sample(2);
            if (t.rst_stall)        cg_reset.sample(3);
            first_after_reset = 1;
        end
    endfunction

    static function int prod_class(cpu_class_e c);
        case (c)
            CL_ALU_R, CL_ALU_I: return 0;
            CL_LOAD:            return 1;
            CL_FPU:             return 2;
            CL_CRYPTO:          return 3;
            CL_JAL, CL_JALR:    return 4;
            default:            return -1;
        endcase
    endfunction

    // dynamic distance (1 = previous retired instruction) to the newest
    // producer of register r, 0 if none within the history window
    function int producer(bit [2:0] r, output cpu_retire_txn p);
        p = null;
        if (r == 0) return 0;
        foreach (hist[i])
            if (hist[i].dec.wr && hist[i].dec.rd == r) begin p = hist[i]; return i + 1; end
        return 0;
    endfunction

    function void write_retire(cpu_retire_txn t);
        cpu_dec_t d = t.dec;
        cpu_retire_txn p;
        int dst;

        cg_opcode.sample(int'(d.op));

        if (d.wr)   cg_rd.sample(int'(d.cls), d.rd);
        if (d.use1) cg_rs1.sample(int'(d.cls), d.src1);
        if (d.use2) cg_rs2.sample(int'(d.cls), d.src2);
        if (d.cls inside {CL_ALU_I, CL_LOAD, CL_STORE, CL_BRANCH, CL_JAL, CL_JALR})
            cg_imm.sample(int'(d.cls), d.imm4);

        // ---- decode robustness ---------------------------------------
        if (d.op == OP_RSVD)                cg_decode.sample(d.funct);
        if (d.op == OP_BRX)                 cg_decode.sample(10 + d.funct);
        if (d.dc_nonzero)                   cg_decode.sample(20 + int'(d.cls));
        if (d.wr && d.rd == 0 && d.cls != CL_JAL) cg_decode.sample(40);

        // ---- ALU --------------------------------------------------------
        if (d.cls == CL_ALU_R || d.cls == CL_ALU_I) begin
            bit          is_imm = (d.cls == CL_ALU_I);
            int          fn     = is_imm ? int'(d.op) - 8 : int'(d.op);
            logic [15:0] bval   = is_imm ? d.imm : t.op_b;
            cg_alu.sample(fn, is_imm, val_cat(t.op_a), val_cat(t.wb_data));
            if (!is_imm) cg_alu_b.sample(fn, val_cat(bval));
            if (fn inside {3, 5, 7}) cg_shift.sample(fn, bval[3:0]);
            if (fn == 2) begin
                bit an = t.op_a[15], bn = bval[15];
                bit lt = $signed(t.op_a) < $signed(bval);
                if (t.op_a == bval)   cg_arith.sample(6);
                else if (!an && !bn)  cg_arith.sample(lt ? 0 : 1);
                else if (an && bn)    cg_arith.sample(lt ? 2 : 3);
                else if (an && !bn)   cg_arith.sample(4);
                else                  cg_arith.sample(5);
            end
            if (fn == 0) begin
                logic [16:0] s = {1'b0, t.op_a} + {1'b0, bval};
                if (s[16]) cg_arith.sample(11);
                if (t.op_a[15] == bval[15] && s[15] != t.op_a[15]) cg_arith.sample(10);
            end
            if (fn == 1) begin
                logic [15:0] s = t.op_a - bval;
                if (t.op_a < bval) cg_arith.sample(13);
                if (t.op_a[15] != bval[15] && s[15] != t.op_a[15]) cg_arith.sample(12);
            end
        end

        // ---- branches / jumps --------------------------------------------
        if (d.cls == CL_BRANCH) begin
            int bt  = int'(d.op) - int'(OP_BEQ);
            int dir = (d.imm == 0) ? 0 : (d.imm[15] ? 2 : 1);
            if (!(dir == 0 && t.ctrl_taken))
                cg_branch.sample(bt, t.ctrl_taken, dir);
            if (d.op == OP_BLT || d.op == OP_BGE) begin
                int rel;
                logic [15:0] a = t.op_a, b = t.op_b;
                if (a == b)                         rel = 0;
                else if ($signed(a) < $signed(b))   rel = (a[15] == b[15]) ? 1 : 2;
                else                                rel = (a[15] == b[15]) ? 3 : 4;
                cg_bcmp.sample(((d.op == OP_BGE) ? 5 : 0) + rel);
            end
        end
        if (d.cls == CL_JAL || d.cls == CL_JALR) begin
            int dir;
            logic [15:0] off = t.next_pc - t.pc;
            dir = (off == 0) ? 0 : (off[15] ? 2 : 1);
            if (dir != 0) cg_jump.sample(d.cls == CL_JALR, dir, d.rd == 0);
            if (d.cls == CL_JALR) cg_jalr_base.sample(t.fwd_a);
        end
        if (hist.size() > 0 && hist[0].ctrl_taken && (d.cls inside {CL_BRANCH, CL_JAL, CL_JALR})) begin
            int prev = (hist[0].dec.cls == CL_BRANCH) ? 0 : (hist[0].dec.cls == CL_JAL) ? 1 : 2;
            int cur  = (d.cls == CL_BRANCH) ? 0 : (d.cls == CL_JAL) ? 1 : 2;
            cg_ctrl.sample(prev * 3 + cur);
        end
        if (t.ctrl_taken) begin
            cg_flush.sample((d.cls == CL_BRANCH) ? 0 : (d.cls == CL_JAL) ? 1 : 2);
            if (d.cls == CL_BRANCH && t.stall_cycles > 0) cg_flush.sample(3);
        end

        // ---- memory -------------------------------------------------------
        if (d.cls == CL_LOAD || d.cls == CL_STORE) begin
            int region = (t.mem_addr[7:0] == 8'd0) ? 0 : (t.mem_addr[7:0] == 8'd255) ? 2 : 1;
            cg_mem.sample(d.cls == CL_STORE, region, t.mem_addr[15:8] != 0);
            if (d.cls == CL_STORE) last_store_idx[int'(t.mem_addr[7:0])] = dyn_idx;
            else if (last_store_idx.exists(int'(t.mem_addr[7:0]))) begin
                longint unsigned dd = dyn_idx - last_store_idx[int'(t.mem_addr[7:0])];
                if (dd <= 8) cg_st_ld.sample(int'(dd));
            end
        end

        // ---- hazards ------------------------------------------------------
        if (d.use1) cg_fwd_a.sample(int'(d.cls), t.fwd_a);
        if (d.use2) cg_fwd_b.sample(int'(d.cls), t.fwd_b);
        if (d.use1 && d.use2 && t.fwd_a != 0 && t.fwd_b != 0) cg_fwd_both.sample(t.fwd_a * 4 + t.fwd_b);

        if (t.risk_a && d.use1) cg_wbid.sample(t.stale_a ? 2 : 0);
        if (t.risk_b && d.use2) cg_wbid.sample(t.stale_b ? 3 : 1);

        if (t.stall_cycles > 0 && hist.size() > 0 && hist[0].dec.cls == CL_LOAD) begin
            bit [2:0] lr = hist[0].dec.rd;
            bit ha = d.use1 && d.src1 == lr;
            bit hb = d.use2 && d.src2 == lr;
            case (d.cls)
                CL_ALU_R:  begin if (ha) cg_loaduse.sample(0); if (hb) cg_loaduse.sample(1); end
                CL_ALU_I:  if (ha) cg_loaduse.sample(2);
                CL_LOAD:   if (ha) cg_loaduse.sample(3);
                CL_STORE:  begin if (ha) cg_loaduse.sample(4); if (hb) cg_loaduse.sample(5); end
                CL_BRANCH: begin if (ha) cg_loaduse.sample(6); if (hb) cg_loaduse.sample(7); end
                CL_JALR:   if (ha) cg_loaduse.sample(8);
                CL_FPU:    begin if (ha) cg_loaduse.sample(9); if (hb) cg_loaduse.sample(10); end
                CL_CRYPTO: if (ha) cg_loaduse.sample(11);
                default: ;
            endcase
        end

        for (int s = 0; s < 2; s++) begin
            bit       u = (s == 0) ? d.use1 : d.use2;
            bit [2:0] r = (s == 0) ? d.src1 : d.src2;
            if (!u || r == 0) continue;
            dst = producer(r, p);
            if (dst >= 1 && dst <= 4 && prod_class(p.dec.cls) >= 0)
                cg_raw.sample(prod_class(p.dec.cls), dst);
        end

        // ---- FPU ----------------------------------------------------------
        if (d.cls == CL_FPU) begin
            bit is_mul = (d.op == OP_FMUL);
            fp_class_e ca = fp16_class(t.op_a), cb = fp16_class(t.op_b), cr = fp16_class(t.wb_data);
            cg_fpu.sample(is_mul, ca, cb, cr, {t.op_a[15], t.op_b[15]});
            sample_fpu_events(is_mul, t.op_a, t.op_b, t.wb_data, ca, cb, cr);
        end

        // ---- crypto -------------------------------------------------------
        if (d.cls == CL_CRYPTO) begin
            int chain = 0;
            dst = producer(d.src1, p);
            if (dst > 0 && p.dec.cls == CL_CRYPTO) begin
                bit pd = (p.dec.op == OP_DEC), cd = (d.op == OP_DEC);
                chain = (!pd && cd) ? 1 : (pd && !cd) ? 2 : (!pd && !cd) ? 3 : 4;
            end
            cg_crypto.sample(d.op == OP_DEC, val_cat(t.op_a), chain);
        end

        if (first_after_reset) begin
            if (t.pc == 0) cg_reset.sample(4);
            first_after_reset = 0;
        end

        hist.push_front(t);
        if (hist.size() > 8) void'(hist.pop_back());
        dyn_idx++;
    endfunction

    function void sample_fpu_events(bit is_mul, logic [15:0] a, logic [15:0] b, logic [15:0] r,
                                    fp_class_e ca, fp_class_e cb, fp_class_e cr);
        bit fin = (ca inside {FPC_ZERO, FPC_SUB, FPC_NORM}) && (cb inside {FPC_ZERO, FPC_SUB, FPC_NORM});
        if (!is_mul) begin
            if (ca == FPC_INF && cb == FPC_INF && a[15] != b[15]) cg_fpu_ev.sample(11);
            if (fin) begin
                real ex = fp16_to_real(a) + fp16_to_real(b);
                if (cr == FPC_INF) cg_fpu_ev.sample(0);
                if (ex == 0.0 && ca != FPC_ZERO) cg_fpu_ev.sample(1);
                if (ca == FPC_NORM && cb == FPC_NORM && cr == FPC_SUB) cg_fpu_ev.sample(4);
                if (cr inside {FPC_SUB, FPC_NORM}) begin
                    real rr = fp16_to_real(r);
                    real ae = (ex < 0) ? -ex : ex, ar = (rr < 0) ? -rr : rr;
                    if (ar > ae) cg_fpu_ev.sample(2);
                    if (ar < ae) cg_fpu_ev.sample(3);
                end
            end
        end
        else begin
            if ((ca == FPC_INF && cb == FPC_ZERO) || (cb == FPC_INF && ca == FPC_ZERO)) cg_fpu_ev.sample(12);
            if (fin && ca != FPC_ZERO && cb != FPC_ZERO) begin
                real ex = fp16_to_real(a) * fp16_to_real(b);
                if (cr == FPC_INF)  cg_fpu_ev.sample(5);
                if (cr == FPC_ZERO) cg_fpu_ev.sample(6);
                if (ca == FPC_NORM && cb == FPC_NORM && cr == FPC_SUB) cg_fpu_ev.sample(7);
                if (cr inside {FPC_SUB, FPC_NORM}) begin
                    real rr = fp16_to_real(r);
                    real ae = (ex < 0) ? -ex : ex, ar = (rr < 0) ? -rr : rr;
                    if (ar > ae)  cg_fpu_ev.sample(8);
                    if (ar < ae)  cg_fpu_ev.sample(9);
                    if (ar == ae) cg_fpu_ev.sample(10);
                end
            end
        end
    endfunction

    // ----------------------------------------------------------------------
    // Plain-text summary of THIS run's functional coverage, printed in the log
    // and, with +COV_SUMMARY=<file>, written to a text file.  Uses the LRM
    // get_inst_coverage(), so it is the same in every simulator.  Coverage
    // MERGED over several runs comes from the simulator's database (Xcelium:
    // imc, see scripts/cov_report.tcl).
    function void add_cov_line(int f, string name, real pct, ref real sum);
        string l = $sformatf("  %-14s %7.2f %%", name, pct);
        `uvm_info("COV", l, UVM_NONE)
        if (f != 0) $fdisplay(f, "%s", l);
        sum += pct;
    endfunction

    function void report_phase(uvm_phase phase);
        string fname, l;
        int    f = 0;
        real   sum = 0.0;
        if ($value$plusargs("COV_SUMMARY=%s", fname)) begin
            f = $fopen(fname, "w");
            if (f == 0) `uvm_warning("COV", {"cannot open ", fname})
        end
        `uvm_info("COV", "functional coverage of this run (per covergroup, LRM get_inst_coverage):", UVM_NONE)
        if (f != 0) $fdisplay(f, "functional coverage of this run (per covergroup, LRM get_inst_coverage)");
        add_cov_line(f, "cg_opcode", cg_opcode.get_inst_coverage(), sum);
        add_cov_line(f, "cg_rd", cg_rd.get_inst_coverage(), sum);
        add_cov_line(f, "cg_rs1", cg_rs1.get_inst_coverage(), sum);
        add_cov_line(f, "cg_rs2", cg_rs2.get_inst_coverage(), sum);
        add_cov_line(f, "cg_imm", cg_imm.get_inst_coverage(), sum);
        add_cov_line(f, "cg_alu", cg_alu.get_inst_coverage(), sum);
        add_cov_line(f, "cg_alu_b", cg_alu_b.get_inst_coverage(), sum);
        add_cov_line(f, "cg_shift", cg_shift.get_inst_coverage(), sum);
        add_cov_line(f, "cg_arith", cg_arith.get_inst_coverage(), sum);
        add_cov_line(f, "cg_branch", cg_branch.get_inst_coverage(), sum);
        add_cov_line(f, "cg_bcmp", cg_bcmp.get_inst_coverage(), sum);
        add_cov_line(f, "cg_jump", cg_jump.get_inst_coverage(), sum);
        add_cov_line(f, "cg_jalr_base", cg_jalr_base.get_inst_coverage(), sum);
        add_cov_line(f, "cg_mem", cg_mem.get_inst_coverage(), sum);
        add_cov_line(f, "cg_st_ld", cg_st_ld.get_inst_coverage(), sum);
        add_cov_line(f, "cg_fwd_a", cg_fwd_a.get_inst_coverage(), sum);
        add_cov_line(f, "cg_fwd_b", cg_fwd_b.get_inst_coverage(), sum);
        add_cov_line(f, "cg_fwd_both", cg_fwd_both.get_inst_coverage(), sum);
        add_cov_line(f, "cg_loaduse", cg_loaduse.get_inst_coverage(), sum);
        add_cov_line(f, "cg_raw", cg_raw.get_inst_coverage(), sum);
        add_cov_line(f, "cg_wbid", cg_wbid.get_inst_coverage(), sum);
        add_cov_line(f, "cg_ctrl", cg_ctrl.get_inst_coverage(), sum);
        add_cov_line(f, "cg_flush", cg_flush.get_inst_coverage(), sum);
        add_cov_line(f, "cg_fpu", cg_fpu.get_inst_coverage(), sum);
        add_cov_line(f, "cg_fpu_ev", cg_fpu_ev.get_inst_coverage(), sum);
        add_cov_line(f, "cg_crypto", cg_crypto.get_inst_coverage(), sum);
        add_cov_line(f, "cg_decode", cg_decode.get_inst_coverage(), sum);
        add_cov_line(f, "cg_reset", cg_reset.get_inst_coverage(), sum);
        l = $sformatf("  %-14s %7.2f %% (average of 28 covergroups)", "TOTAL", sum / 28.0);
        `uvm_info("COV", l, UVM_NONE)
        if (f != 0) begin
            $fdisplay(f, "%s", l);
            $fclose(f);
        end
    endfunction
endclass
