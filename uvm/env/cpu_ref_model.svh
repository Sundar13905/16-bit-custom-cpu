// ============================================================================
// cpu_ref_model.svh : architectural (instruction-accurate) reference model.
//
// The reference model is written from the ISA specification, NOT by copying
// the RTL micro-architecture:
//   * integer ops    : plain SystemVerilog arithmetic on 16-bit values
//   * FADD/FMUL      : exact evaluation in IEEE double precision ('real'),
//                      followed by an independent round-to-nearest-even
//                      conversion to binary16.  Both a+b and a*b of two
//                      binary16 numbers are exact in binary64, so the only
//                      rounding is the final one.
//   * ENC/DEC        : 8-round Feistel network with the documented key
//                      schedule (MASTER_KEY = 16'h1EEE).
// ============================================================================

// ---------------------------------------------------------------- FP16 ----
typedef enum int { FPC_ZERO = 0, FPC_SUB = 1, FPC_NORM = 2, FPC_INF = 3, FPC_NAN = 4 } fp_class_e;

localparam logic [15:0] FP16_QNAN = 16'h7E00;   // canonical NaN produced by DUT spec

function automatic fp_class_e fp16_class(logic [15:0] h);
    if (h[14:10] == 5'h1F) return (h[9:0] != 0) ? FPC_NAN : FPC_INF;
    if (h[14:10] == 5'h00) return (h[9:0] != 0) ? FPC_SUB : FPC_ZERO;
    return FPC_NORM;
endfunction

// 2^e as a real (exact for the exponent range used here)
function automatic real pow2(int e);
    real r = 1.0;
    if (e >= 0) for (int i = 0; i < e; i++)  r = r * 2.0;
    else        for (int i = 0; i < -e; i++) r = r / 2.0;
    return r;
endfunction

// Exact value of a finite binary16 number.
function automatic real fp16_to_real(logic [15:0] h);
    real m;
    if (h[14:10] == 0) m = real'(h[9:0]) * pow2(-24);
    else               m = real'({1'b1, h[9:0]}) * pow2(int'(h[14:10]) - 25);
    return h[15] ? -m : m;
endfunction

// Round-to-nearest-even of a real number to an integer (input exactly
// representable, |x| < 2^52).
function automatic longint rne_int(real x);
    real    fl = $floor(x);
    real    fr = x - fl;
    longint n  = longint'(fl);
    if (fr > 0.5)                       n = n + 1;
    else if (fr == 0.5 && n[0] == 1'b1) n = n + 1;
    return n;
endfunction

// Convert a non-zero finite real to binary16 with RNE, overflow to Inf.
function automatic logic [15:0] real_to_fp16(real x);
    bit     s = (x < 0.0);
    real    m = s ? -x : x;
    int     e = 0;
    longint n;
    // find e such that 2^e <= m < 2^(e+1)  (exact power-of-two scaling)
    while (m >= pow2(e + 1)) e++;
    while (m <  pow2(e))          e--;
    if (e < -14) begin
        n = rne_int(m * pow2(24));             // units of 2^-24
        // n == 1024 naturally encodes the minimum normal (exp=1, frac=0)
        return {s, 15'(n)};
    end
    n = rne_int(m * pow2(10 - e));           // in [1024, 2048]
    if (n == 2048) begin n = 1024; e++; end
    if (e > 15) return {s, 5'h1F, 10'h000};
    return {s, 5'(e + 15), 10'(n - 1024)};
endfunction

function automatic logic [15:0] ref_fadd(logic [15:0] a, logic [15:0] b);
    fp_class_e ca = fp16_class(a), cb = fp16_class(b);
    real r;
    if (ca == FPC_NAN || cb == FPC_NAN) return FP16_QNAN;
    if (ca == FPC_INF && cb == FPC_INF) return (a[15] != b[15]) ? FP16_QNAN : a;
    if (ca == FPC_INF) return a;
    if (cb == FPC_INF) return b;
    r = fp16_to_real(a) + fp16_to_real(b);
    if (r == 0.0) begin
        // IEEE 754 6.3: exact zero sum is +0 under RNE unless both operands are -0
        if (ca == FPC_ZERO && cb == FPC_ZERO) return {a[15] & b[15], 15'h0};
        return 16'h0000;
    end
    return real_to_fp16(r);
endfunction

function automatic logic [15:0] ref_fmul(logic [15:0] a, logic [15:0] b);
    fp_class_e ca = fp16_class(a), cb = fp16_class(b);
    bit s = a[15] ^ b[15];
    real r;
    if (ca == FPC_NAN || cb == FPC_NAN) return FP16_QNAN;
    if ((ca == FPC_INF && cb == FPC_ZERO) || (cb == FPC_INF && ca == FPC_ZERO)) return FP16_QNAN;
    if (ca == FPC_INF || cb == FPC_INF) return {s, 5'h1F, 10'h0};
    if (ca == FPC_ZERO || cb == FPC_ZERO) return {s, 15'h0};
    r = fp16_to_real(a) * fp16_to_real(b);
    if (r == 0.0) return {s, 15'h0};     // cannot happen for non-zero inputs, kept for safety
    // underflow below half of the smallest subnormal rounds to signed zero
    return real_to_fp16(r);
endfunction

// -------------------------------------------------------------- CRYPTO ----
localparam logic [15:0] CRYPTO_MASTER_KEY = 16'h1EEE;

// round_key[r] for encryption round r (r = 0..7)
function automatic void crypto_keys(output logic [15:0] rk [8]);
    logic [15:0] seed = CRYPTO_MASTER_KEY;
    logic [15:0] sched [8];
    for (int i = 0; i < 8; i++) begin
        seed = seed ^ (seed << 7);
        seed = seed ^ (seed >> 9);
        seed = seed ^ (seed << 8);
        sched[i] = seed;
    end
    // Round 0 uses the most-significant 16 bits of the expanded key,
    // i.e. the LAST generated word.
    for (int r = 0; r < 8; r++) rk[r] = sched[7 - r];
endfunction

function automatic logic [7:0] crypto_f(logic [7:0] x, logic [15:0] k);
    return (x ^ k[7:0]) + k[15:8];
endfunction

function automatic logic [15:0] ref_enc(logic [15:0] d);
    logic [15:0] rk [8];
    logic [7:0]  l = d[15:8], r = d[7:0], t;
    crypto_keys(rk);
    for (int i = 0; i < 8; i++) begin
        t = r;
        r = l ^ crypto_f(r, rk[i]);
        l = t;
    end
    return {l, r};
endfunction

function automatic logic [15:0] ref_dec(logic [15:0] d);
    logic [15:0] rk [8];
    logic [7:0]  l = d[15:8], r = d[7:0], t;
    crypto_keys(rk);
    for (int i = 7; i >= 0; i--) begin
        t = l;
        l = r ^ crypto_f(l, rk[i]);
        r = t;
    end
    return {l, r};
endfunction

// ----------------------------------------------------------------- ALU ----
function automatic logic [15:0] ref_alu(int fn, logic [15:0] a, logic [15:0] b);
    case (fn)
        0: return a + b;
        1: return a - b;
        2: return ($signed(a) < $signed(b)) ? 16'd1 : 16'd0;
        3: return a >> b[3:0];
        4: return a | b;
        5: return a << b[3:0];
        6: return a & b;
        default: return 16'($signed(a) >>> b[3:0]);
    endcase
endfunction

// ------------------------------------------------- expected side effects ----
typedef struct {
    bit          wr;
    bit [2:0]    rd;
    logic [15:0] wdata;
    bit          st;
    logic [15:0] addr;      // effective address (full 16 bits) for LH/SH
    logic [15:0] sdata;
    bit          ld;
    bit          ctrl_taken;
    logic [15:0] next_pc;
    logic [15:0] a;         // architectural operand values used
    logic [15:0] b;
} cpu_exp_t;

// ------------------------------------------------------------------ ISS ----
class cpu_ref_model extends uvm_object;
    `uvm_object_utils(cpu_ref_model)

    logic [15:0] imem [256];
    logic [15:0] dmem [256];
    logic [15:0] regs [8];
    logic [15:0] pc;
    longint unsigned n_exec;

    function new(string name = "cpu_ref_model");
        super.new(name);
    endfunction

    function void load(const ref logic [15:0] im[256], const ref logic [15:0] dm[256],
                       const ref logic [15:0] rg[8]);
        foreach (imem[i]) imem[i] = im[i];
        foreach (dmem[i]) dmem[i] = dm[i];
        foreach (regs[i]) regs[i] = rg[i];
        regs[0] = 16'h0;
        pc      = 16'h0;
        n_exec  = 0;
    endfunction

    function logic [15:0] fetch();
        return imem[pc[7:0]];
    endfunction

    // Pure function: compute the effects of instruction d at address pc with
    // operand values a (src1) and b (src2).
    function cpu_exp_t exec(cpu_dec_t d, logic [15:0] ipc, logic [15:0] a, logic [15:0] b);
        cpu_exp_t e;
        e.wr = d.wr; e.rd = d.rd; e.wdata = 0; e.st = 0; e.addr = 0; e.sdata = 0;
        e.ld = 0; e.ctrl_taken = 0; e.next_pc = ipc + 16'd1; e.a = a; e.b = b;
        case (d.cls)
            CL_ALU_R:  e.wdata = ref_alu(int'(d.op),     a, b);
            CL_ALU_I:  e.wdata = ref_alu(int'(d.op) - 8, a, d.imm);
            CL_LOAD:   begin e.ld = 1; e.addr = a + d.imm; e.wdata = dmem[e.addr[7:0]]; end
            CL_STORE:  begin e.st = 1; e.addr = a + d.imm; e.sdata = b; end
            CL_BRANCH: begin
                           case (d.op)
                               OP_BNE:  e.ctrl_taken = (a != b);
                               OP_BLT:  e.ctrl_taken = ($signed(a) <  $signed(b));
                               OP_BGE:  e.ctrl_taken = ($signed(a) >= $signed(b));
                               default: e.ctrl_taken = (a == b);   // BEQ and aliases
                           endcase
                           if (e.ctrl_taken) e.next_pc = ipc + d.imm;
                       end
            CL_JAL:    begin e.wdata = ipc + 16'd1; e.ctrl_taken = 1; e.next_pc = ipc + d.imm; end
            CL_JALR:   begin e.wdata = ipc + 16'd1; e.ctrl_taken = 1; e.next_pc = a + d.imm; end
            CL_FPU:    e.wdata = (d.op == OP_FADD) ? ref_fadd(a, b) : ref_fmul(a, b);
            CL_CRYPTO: e.wdata = (d.op == OP_ENC) ? ref_enc(a) : ref_dec(a);
            default:   ;   // reserved: architectural no-op
        endcase
        return e;
    endfunction

    // Expected effects of the instruction at the current PC, using the
    // model's own register state.
    function cpu_exp_t peek(output cpu_dec_t d);
        d = cpu_decode(fetch());
        return exec(d, pc, regs[d.src1], regs[d.src2]);
    endfunction

    function void commit(const ref cpu_exp_t e);
        if (e.wr && e.rd != 0) regs[e.rd] = e.wdata;
        if (e.st)              dmem[e.addr[7:0]] = e.sdata;
        pc = e.next_pc;
        n_exec++;
    endfunction

    function void step();
        cpu_dec_t d;
        cpu_exp_t e = peek(d);
        commit(e);
    endfunction

    // Run until the PC sits on a self-jump (halt) or the step budget runs out.
    // Returns the number of executed instructions, or -1 on budget exhaustion.
    function int run_to_halt(int max_steps);
        for (int s = 0; s < max_steps; s++) begin
            cpu_dec_t d = cpu_decode(fetch());
            if ((d.cls == CL_JAL && d.imm == 0)) return s;
            step();
        end
        return -1;
    endfunction
endclass
