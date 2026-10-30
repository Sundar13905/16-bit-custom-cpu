// ============================================================================
// cpu_txn.svh : transactions
//   cpu_instr_item   - one constrained-random instruction (sequence building block)
//   cpu_program_item - the item the driver consumes: IMEM/DMEM/regfile image
//   cpu_retire_txn   - one retired instruction as observed by the monitor
//   cpu_ctrl_txn     - program START / RESYNC (after reset) / END markers
// ============================================================================

class cpu_instr_item extends uvm_sequence_item;
    `uvm_object_utils(cpu_instr_item)

    rand cpu_op_e  op;
    rand bit [2:0] rd;
    rand bit [2:0] rs1;
    rand bit [2:0] rs2;
    rand bit [3:0] imm;
    rand bit [5:0] dc;        // values for don't-care fields
    rand bit [2:0] alias_f;   // funct for OP_BRX / OP_RSVD

    // Class weights (set by the sequence before randomize)
    int unsigned w_alu_r = 20, w_alu_i = 20, w_load = 8, w_store = 8, w_branch = 10,
                 w_jal = 2, w_jalr = 1, w_fpu = 6, w_crypto = 4, w_rsvd = 1;
    int unsigned p_dc = 20;   // % of instructions with non-zero don't-care fields

    constraint c_op_dist {
        op dist {
            [OP_ADD:OP_SRA]   :/ w_alu_r,
            [OP_ADDI:OP_SRAI] :/ w_alu_i,
            OP_LH             := w_load,
            OP_SH             := w_store,
            [OP_BEQ:OP_BRX]   :/ w_branch,
            OP_JAL            := w_jal,
            OP_JALR           := w_jalr,
            [OP_FADD:OP_FMUL] :/ w_fpu,
            [OP_ENC:OP_DEC]   :/ w_crypto,
            OP_RSVD           := w_rsvd
        };
    }
    constraint c_alias {
        (op == OP_BRX)  -> alias_f inside {3'b010, 3'b101, 3'b110, 3'b111};
        (op == OP_RSVD) -> alias_f inside {[3'b100:3'b111]};
    }
    constraint c_dc { dc dist { 6'd0 := (100 - p_dc), [6'd1:6'd63] :/ p_dc }; }
    // JAL with offset 0 is the halt idiom; keep it out of random bodies
    constraint c_no_halt { (op == OP_JAL) -> imm != 0; }

    function new(string name = "cpu_instr_item");
        super.new(name);
    endfunction

    function logic [15:0] encode();
        return cpu_encode(op, rd, rs1, rs2, imm, dc, alias_f);
    endfunction

    function string convert2string();
        return cpu_disasm(encode());
    endfunction
endclass

// ----------------------------------------------------------------------------
class cpu_program_item extends uvm_sequence_item;
    `uvm_object_utils(cpu_program_item)

    string       tag;
    logic [15:0] imem [256];
    logic [15:0] dmem [256];
    logic [15:0] regs [8];
    int unsigned n_instr;        // static program length (before halt fill)
    int unsigned max_cycles;     // simulation budget for this program
    int          reset_at  = -1; // cycle (after reset release) to re-assert reset, -1 = never
    int unsigned reset_len = 2;  // reset pulse length in cycles
    int          reset_cond = 0; // 0: at reset_at, 1: wait for a store in MEM,
                                 // 2: a taken redirect in EX, 3: a load-use stall
                                 // (gives up 40 cycles after reset_at)

    function new(string name = "cpu_program_item");
        super.new(name);
        foreach (imem[i]) imem[i] = HALT_INSTR;
        foreach (dmem[i]) dmem[i] = 0;
        foreach (regs[i]) regs[i] = 0;
    endfunction

    function string convert2string();
        string s = $sformatf("program '%s' : %0d instrs, budget %0d cycles%s\n", tag, n_instr,
                             max_cycles, (reset_at >= 0) ? $sformatf(", reset @%0d", reset_at) : "");
        for (int i = 0; i < n_instr; i++)
            s = {s, $sformatf("  %3d: %04h  %s\n", i, imem[i], cpu_disasm(imem[i]))};
        return s;
    endfunction
endclass

// ----------------------------------------------------------------------------
class cpu_retire_txn extends uvm_sequence_item;
    `uvm_object_utils(cpu_retire_txn)

    longint unsigned seq_no;       // retire order within the run
    longint unsigned cyc_id;       // cycle the instruction left ID
    longint unsigned cyc_wb;       // cycle the instruction was in WB
    logic [15:0] pc;
    logic [15:0] instr;
    cpu_dec_t    dec;

    // ID stage observations
    int unsigned stall_cycles;     // load-use stall cycles spent in ID
    bit          risk_a, risk_b;   // WB was writing this source while it was read in ID
    // EX stage observations
    bit [1:0]    fwd_a, fwd_b;
    logic [15:0] op_a, op_b;
    logic [15:0] ex_result;
    bit          ctrl_taken;
    logic [15:0] next_pc;
    bit          stale_a, stale_b; // risk_x && no forwarding in EX -> stale RF value consumed
    // MEM stage observations
    bit          mem_we, mem_re;
    logic [15:0] mem_addr, mem_wdata, mem_rdata;
    // WB stage observations
    bit          wb_we;
    bit [2:0]    wb_rd;
    logic [15:0] wb_data;

    function new(string name = "cpu_retire_txn");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("#%0d pc=%04h %04h %-18s a=%04h(f%0d) b=%04h(f%0d) wb=%0d:R%0d=%04h st=%0d[%04h]=%04h next=%04h stall=%0d stale=%0d%0d",
                         seq_no, pc, instr, cpu_disasm(instr), op_a, fwd_a, op_b, fwd_b, wb_we, wb_rd,
                         wb_data, mem_we, mem_addr, mem_wdata, next_pc, stall_cycles, stale_a, stale_b);
    endfunction
endclass

// ----------------------------------------------------------------------------
typedef enum int { CTRL_START, CTRL_RESYNC, CTRL_END } cpu_ctrl_kind_e;

class cpu_ctrl_txn extends uvm_sequence_item;
    `uvm_object_utils(cpu_ctrl_txn)

    cpu_ctrl_kind_e  kind;
    cpu_program_item prog;
    logic [15:0]     regs [8];     // backdoor snapshot (RESYNC / END)
    logic [15:0]     dmem [256];
    bit              halted;
    longint unsigned cycles;
    // pipeline state when reset was asserted (RESYNC only)
    bit              rst_store_in_mem, rst_ctrl_in_ex, rst_stall;

    function new(string name = "cpu_ctrl_txn");
        super.new(name);
    endfunction
endclass
