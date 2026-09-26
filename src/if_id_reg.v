`timescale 1ns / 1ps

module if_id_reg (

    input wire clk,
    input wire rst_n,

    input wire stall,
    input wire flush,

    input wire [15:0] pc_in,
    input wire [15:0] pc_plus1_in,
    input wire [15:0] instr_in,

    output reg [15:0] pc_out,
    output reg [15:0] pc_plus1_out,
    output reg [15:0] instr_out

);

    always @(posedge clk) begin

        if (!rst_n) begin

            pc_out       <= 16'h0000;
            pc_plus1_out <= 16'h0000;
            instr_out    <= 16'h0000;

        end

        else if (flush) begin

            pc_out       <= 16'h0000;
            pc_plus1_out <= 16'h0000;
            instr_out    <= 16'h0000;

        end

        else if (stall) begin

            // Hold current instruction
            pc_out       <= pc_out;
            pc_plus1_out <= pc_plus1_out;
            instr_out    <= instr_out;

        end

        else begin

            pc_out       <= pc_in;
            pc_plus1_out <= pc_plus1_in;
            instr_out    <= instr_in;

        end

    end

endmodule
