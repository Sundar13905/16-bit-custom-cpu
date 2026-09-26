`timescale 1ns / 1ps

module hazard_unit (

    // Instruction currently in ID/EX
    input wire       id_ex_mem_read,
    input wire [2:0] id_ex_rd,

    // Instruction currently in IF/ID
    input wire [2:0] if_id_rs1,
    input wire [2:0] if_id_rs2,

    // Stall controls
    output reg       pc_stall,
    output reg       if_id_stall,
    output reg       id_ex_flush

);

    always @(*) begin

        // Default: no stall
        pc_stall    = 1'b0;
        if_id_stall = 1'b0;
        id_ex_flush = 1'b0;

        // ========================================================
        // LOAD-USE HAZARD
        // ========================================================
        //
        // Example:
        //
        //     LH  R1, ...
        //     ADD R3, R1, R4
        //
        // The load result is not available soon enough for
        // forwarding into the immediately following EX stage.
        //
        // Therefore:
        //
        //     PC      = hold
        //     IF/ID   = hold
        //     ID/EX   = NOP
        //
        // This creates one bubble.
        // ========================================================

        if (id_ex_mem_read &&
            (id_ex_rd != 3'b000) &&
            ((id_ex_rd == if_id_rs1) ||
             (id_ex_rd == if_id_rs2))) begin

            pc_stall    = 1'b1;
            if_id_stall = 1'b1;
            id_ex_flush = 1'b1;

        end

    end

endmodule
