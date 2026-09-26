`timescale 1ns / 1ps

module id_ex_reg (

    input wire clk,
    input wire rst_n,
    input wire flush,

    input wire [15:0] pc_in,
    input wire [15:0] pc_plus1_in,

    input wire [15:0] rs1_data_in,
    input wire [15:0] rs2_data_in,

    input wire [15:0] imm_in,

    input wire [2:0] rs1_in,
    input wire [2:0] rs2_in,
    input wire [2:0] rd_in,

    input wire [3:0] alu_control_in,
    input wire       alu_src_in,

    input wire       mem_read_in,
    input wire       mem_write_in,
    input wire       reg_write_in,

    input wire [1:0] wb_select_in,

    input wire       branch_in,
    input wire [1:0] branch_type_in,

    input wire       jump_in,
    input wire       jalr_in,

    input wire       fpu_enable_in,
    input wire [3:0] fpu_opcode_in,

    output reg [15:0] pc_out,
    output reg [15:0] pc_plus1_out,

    output reg [15:0] rs1_data_out,
    output reg [15:0] rs2_data_out,

    output reg [15:0] imm_out,

    output reg [2:0] rs1_out,
    output reg [2:0] rs2_out,
    output reg [2:0] rd_out,

    output reg [3:0] alu_control_out,
    output reg       alu_src_out,

    output reg       mem_read_out,
    output reg       mem_write_out,
    output reg       reg_write_out,

    output reg [1:0] wb_select_out,

    output reg       branch_out,
    output reg [1:0] branch_type_out,

    output reg       jump_out,
    output reg       jalr_out,

    output reg       fpu_enable_out,
    output reg [3:0] fpu_opcode_out

);

    always @(posedge clk) begin

        if (!rst_n) begin

            pc_out          <= 16'h0000;
            pc_plus1_out    <= 16'h0000;

            rs1_data_out    <= 16'h0000;
            rs2_data_out    <= 16'h0000;

            imm_out         <= 16'h0000;

            rs1_out         <= 3'b000;
            rs2_out         <= 3'b000;
            rd_out          <= 3'b000;

            alu_control_out <= 4'b0000;
            alu_src_out     <= 1'b0;

            mem_read_out    <= 1'b0;
            mem_write_out   <= 1'b0;
            reg_write_out   <= 1'b0;

            wb_select_out   <= 2'b00;

            branch_out      <= 1'b0;
            branch_type_out <= 2'b00;

            jump_out        <= 1'b0;
            jalr_out        <= 1'b0;

            fpu_enable_out  <= 1'b0;
            fpu_opcode_out  <= 4'b0000;

        end

        else if (flush) begin

            // ----------------------------------------------------
            // Insert NOP / bubble
            // ----------------------------------------------------

            pc_out          <= 16'h0000;
            pc_plus1_out    <= 16'h0000;

            rs1_data_out    <= 16'h0000;
            rs2_data_out    <= 16'h0000;

            imm_out         <= 16'h0000;

            rs1_out         <= 3'b000;
            rs2_out         <= 3'b000;
            rd_out          <= 3'b000;

            alu_control_out <= 4'b0000;
            alu_src_out     <= 1'b0;

            mem_read_out    <= 1'b0;
            mem_write_out   <= 1'b0;
            reg_write_out   <= 1'b0;

            wb_select_out   <= 2'b00;

            branch_out      <= 1'b0;
            branch_type_out <= 2'b00;

            jump_out        <= 1'b0;
            jalr_out        <= 1'b0;

            fpu_enable_out  <= 1'b0;
            fpu_opcode_out  <= 4'b0000;

        end

        else begin

            pc_out          <= pc_in;
            pc_plus1_out    <= pc_plus1_in;

            rs1_data_out    <= rs1_data_in;
            rs2_data_out    <= rs2_data_in;

            imm_out         <= imm_in;

            rs1_out         <= rs1_in;
            rs2_out         <= rs2_in;
            rd_out          <= rd_in;

            alu_control_out <= alu_control_in;
            alu_src_out     <= alu_src_in;

            mem_read_out    <= mem_read_in;
            mem_write_out   <= mem_write_in;
            reg_write_out   <= reg_write_in;

            wb_select_out   <= wb_select_in;

            branch_out      <= branch_in;
            branch_type_out <= branch_type_in;

            jump_out        <= jump_in;
            jalr_out        <= jalr_in;

            fpu_enable_out  <= fpu_enable_in;
            fpu_opcode_out  <= fpu_opcode_in;

        end

    end

endmodule
