// ============================================================================
// files.f : compile list for the UVM environment of pipelined_core (Xcelium)
// Run from the project root (the folder that has src/ and uvm/).
// ============================================================================

// ---- RTL: only the modules pipelined_core actually uses ----
// (src/datapath.v also defines "module decoder" and clashes with src/decoder.v,
//  and testbenches/ has its own "module pipelined_core_tb", so neither is listed)
src/pc.v
src/instr_mem.v
src/if_id_reg.v
src/control_unit.v
src/regfile.v
src/immgen.v
src/hazard_unit.v
src/id_ex_reg.v
src/forwarding_unit.v
src/alu.v
src/fpu.v
src/crypto_coproc.v
src/ex_mem_reg.v
src/data_mem.v
src/mem_wb_reg.v
src/top_module/pipelined_core.v

// ---- UVM environment ----
// The .svh class files are `included by cpu_uvm_pkg.sv, so they are NOT listed
// here (listing them as well gives duplicate-definition warnings).
-incdir uvm/env
-incdir uvm/seq
-incdir uvm/tests
uvm/env/cpu_uvm_pkg.sv
uvm/tb/cpu_probe_if.sv
uvm/tb/cpu_ctrl_if.sv
uvm/tb/pipelined_core_tb.sv
