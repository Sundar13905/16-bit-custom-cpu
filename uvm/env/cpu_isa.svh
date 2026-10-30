// ============================================================================
// cpu_isa.svh : ISA definitions, encoder and decoder for the 16-bit core.
//
//  15     14:12   11:9   8:6    5:3           2:0
// [imm3] [opcode] [rd]  [rs1]  [rs2/imm2:0]  [funct]
// ============================================================================

typedef enum int {
    OP_ADD  = 0,  OP_SUB  = 1,  OP_SLT  = 2,  OP_SRL  = 3,
    OP_OR   = 4,  OP_SLL  = 5,  OP_AND  = 6,  OP_SRA  = 7,
    OP_ADDI = 8,  OP_SUBI = 9,  OP_SLTI = 10, OP_SRLI = 11,
    OP_ORI  = 12, OP_SLLI = 13, OP_ANDI = 14, OP_SRAI = 15,
    OP_LH   = 16, OP_SH   = 17,
    OP_BEQ  = 18, OP_BNE  = 19, OP_BLT  = 20, OP_BGE  = 21,
    OP_BRX  = 22,               // branch funct 010/101/110/111 (decodes as BEQ)
    OP_JAL  = 23, OP_JALR = 24,
    OP_FADD = 25, OP_FMUL = 26, OP_ENC  = 27, OP_DEC  = 28,
    OP_RSVD = 29                // opcode 110, funct 100..111 (no-op)
} cpu_op_e;

localparam int NUM_OPS = 30;

typedef enum int {
    CL_ALU_R  = 0, CL_ALU_I = 1, CL_LOAD  = 2, CL_STORE = 3,
    CL_BRANCH = 4, CL_JAL   = 5, CL_JALR  = 6, CL_FPU   = 7,
    CL_CRYPTO = 8, CL_RSVD  = 9
} cpu_class_e;

localparam logic [15:0] HALT_INSTR = 16'h5000;   // JAL R0, 0  (self loop)

// Decoded instruction (architectural view)
typedef struct {
    logic [15:0] raw;
    cpu_op_e     op;
    cpu_class_e  cls;
    bit [2:0]    opc;
    bit [2:0]    funct;
    bit [2:0]    rd;        // destination (valid when wr)
    bit [2:0]    src1;      // maps to DUT EX operand A
    bit [2:0]    src2;      // maps to DUT EX operand B
    bit          use1;
    bit          use2;
    bit          wr;        // instruction asserts reg_write
    logic [15:0] imm;       // sign-extended {instr[15], instr[5:3]}
    bit [3:0]    imm4;
    bit          dc_nonzero; // a don't-care field holds a non-zero value
} cpu_dec_t;

function automatic logic [15:0] sext4(bit [3:0] v);
    return {{12{v[3]}}, v};
endfunction

function automatic cpu_class_e op_class(cpu_op_e op);
    if (op <= OP_SRA)                  return CL_ALU_R;
    if (op <= OP_SRAI)                 return CL_ALU_I;
    if (op == OP_LH)                   return CL_LOAD;
    if (op == OP_SH)                   return CL_STORE;
    if (op >= OP_BEQ && op <= OP_BRX)  return CL_BRANCH;
    if (op == OP_JAL)                  return CL_JAL;
    if (op == OP_JALR)                 return CL_JALR;
    if (op == OP_FADD || op == OP_FMUL) return CL_FPU;
    if (op == OP_ENC  || op == OP_DEC)  return CL_CRYPTO;
    return CL_RSVD;
endfunction

function automatic cpu_dec_t cpu_decode(logic [15:0] i);
    cpu_dec_t d;
    bit [2:0] f11, f8, f5;
    d.raw   = i;
    d.opc   = i[14:12];
    d.funct = i[2:0];
    f11     = i[11:9];
    f8      = i[8:6];
    f5      = i[5:3];
    d.imm4  = {i[15], i[5:3]};
    d.imm   = sext4(d.imm4);
    d.rd = 0; d.src1 = 0; d.src2 = 0; d.use1 = 0; d.use2 = 0; d.wr = 0;
    d.dc_nonzero = 0;
    case (d.opc)
        3'b000: begin d.op = cpu_op_e'(int'(d.funct));     d.rd = f11; d.src1 = f8; d.src2 = f5;
                      d.use1 = 1; d.use2 = 1; d.wr = 1; d.dc_nonzero = i[15]; end
        3'b011: begin d.op = cpu_op_e'(8 + int'(d.funct)); d.rd = f11; d.src1 = f8;
                      d.use1 = 1; d.wr = 1; end
        3'b001: begin d.op = OP_LH;  d.rd = f11; d.src1 = f8; d.use1 = 1; d.wr = 1;
                      d.dc_nonzero = (d.funct != 0); end
        3'b010: begin d.op = OP_SH;  d.src1 = f8; d.src2 = f11; d.use1 = 1; d.use2 = 1;
                      d.dc_nonzero = (d.funct != 0); end
        3'b100: begin
                    case (d.funct)
                        3'b000:  d.op = OP_BEQ;
                        3'b001:  d.op = OP_BNE;
                        3'b100:  d.op = OP_BLT;
                        3'b011:  d.op = OP_BGE;
                        default: d.op = OP_BRX;
                    endcase
                    d.src1 = f11; d.src2 = f8; d.use1 = 1; d.use2 = 1;
                end
        3'b101: begin d.op = OP_JAL;  d.rd = f11; d.wr = 1;
                      d.dc_nonzero = (f8 != 0) || (d.funct != 0); end
        3'b111: begin d.op = OP_JALR; d.rd = f11; d.src1 = f8; d.use1 = 1; d.wr = 1;
                      d.dc_nonzero = (d.funct != 0); end
        default: begin // 3'b110
                    case (d.funct)
                        3'b000: begin d.op = OP_FADD; d.rd = f11; d.src1 = f8; d.src2 = f5;
                                      d.use1 = 1; d.use2 = 1; d.wr = 1; d.dc_nonzero = i[15]; end
                        3'b001: begin d.op = OP_FMUL; d.rd = f11; d.src1 = f8; d.src2 = f5;
                                      d.use1 = 1; d.use2 = 1; d.wr = 1; d.dc_nonzero = i[15]; end
                        3'b010: begin d.op = OP_ENC;  d.rd = f11; d.src1 = f8; d.use1 = 1; d.wr = 1;
                                      d.dc_nonzero = i[15] || (f5 != 0); end
                        3'b011: begin d.op = OP_DEC;  d.rd = f11; d.src1 = f8; d.use1 = 1; d.wr = 1;
                                      d.dc_nonzero = i[15] || (f5 != 0); end
                        default: d.op = OP_RSVD;
                    endcase
                 end
    endcase
    d.cls = op_class(d.op);
    return d;
endfunction

// Encoder. Field meaning depends on the class:
//   ALU_R/FPU : rd, rs1, rs2         ALU_I/LH/JALR : rd, rs1, imm
//   SH        : rd=data reg, rs1=base, imm        BRANCH : rd=rs1, rs1=rs2, imm
//   JAL       : rd, imm              ENC/DEC : rd, rs1
// 'dc' supplies values for don't-care fields; 'alias_f' selects the funct for
// OP_BRX / OP_RSVD.
function automatic logic [15:0] cpu_encode(cpu_op_e op, bit [2:0] rd, bit [2:0] rs1,
                                           bit [2:0] rs2, bit [3:0] imm,
                                           bit [5:0] dc = 0, bit [2:0] alias_f = 0);
    logic [15:0] i;
    case (op_class(op))
        CL_ALU_R:  i = {dc[0],    3'b000, rd, rs1, rs2,      3'(int'(op))};
        CL_ALU_I:  i = {imm[3],   3'b011, rd, rs1, imm[2:0], 3'(int'(op) - 8)};
        CL_LOAD:   i = {imm[3],   3'b001, rd, rs1, imm[2:0], dc[2:0]};
        CL_STORE:  i = {imm[3],   3'b010, rd, rs1, imm[2:0], dc[2:0]};
        CL_BRANCH: begin
                       bit [2:0] f;
                       case (op)
                           OP_BEQ:  f = 3'b000;
                           OP_BNE:  f = 3'b001;
                           OP_BLT:  f = 3'b100;
                           OP_BGE:  f = 3'b011;
                           default: f = alias_f;
                       endcase
                       i = {imm[3], 3'b100, rd, rs1, imm[2:0], f};
                   end
        CL_JAL:    i = {imm[3],   3'b101, rd, dc[5:3], imm[2:0], dc[2:0]};
        CL_JALR:   i = {imm[3],   3'b111, rd, rs1, imm[2:0], dc[2:0]};
        CL_FPU:    i = {dc[0],    3'b110, rd, rs1, rs2, (op == OP_FADD) ? 3'b000 : 3'b001};
        CL_CRYPTO: i = {dc[0],    3'b110, rd, rs1, dc[5:3], (op == OP_ENC) ? 3'b010 : 3'b011};
        default:   i = {dc[0],    3'b110, rd, rs1, rs2, alias_f};
    endcase
    return i;
endfunction

function automatic string cpu_disasm(logic [15:0] i);
    cpu_dec_t d = cpu_decode(i);
    string m = d.op.name();
    m = m.substr(3, m.len() - 1);
    case (d.cls)
        CL_ALU_R, CL_FPU: return $sformatf("%s R%0d,R%0d,R%0d", m, d.rd, d.src1, d.src2);
        CL_ALU_I, CL_JALR: return $sformatf("%s R%0d,R%0d,%0d", m, d.rd, d.src1, $signed(d.imm));
        CL_LOAD:   return $sformatf("LH R%0d,%0d(R%0d)", d.rd, $signed(d.imm), d.src1);
        CL_STORE:  return $sformatf("SH R%0d,%0d(R%0d)", d.src2, $signed(d.imm), d.src1);
        CL_BRANCH: return $sformatf("%s R%0d,R%0d,%0d", m, d.src1, d.src2, $signed(d.imm));
        CL_JAL:    return $sformatf("JAL R%0d,%0d", d.rd, $signed(d.imm));
        CL_CRYPTO: return $sformatf("%s R%0d,R%0d", m, d.rd, d.src1);
        default:   return $sformatf("RSVD(funct=%0d)", d.funct);
    endcase
endfunction
