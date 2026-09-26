module forwarding_unit (
    input wire [2:0] id_ex_rs1,
    input wire [2:0] id_ex_rs2,

    input wire [2:0] ex_mem_rd,
    input wire       ex_mem_reg_write,

    input wire [2:0] mem_wb_rd,
    input wire       mem_wb_reg_write,

    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);

    always @(*) begin

        // Default:
        // Use values read from register file
        forward_a = 2'b00;
        forward_b = 2'b00;

        // ========================================================
        // Forwarding for ALU/FPU operand A
        // ========================================================

        // EX/MEM has the newest value
        if (ex_mem_reg_write &&
            (ex_mem_rd != 3'b000) &&
            (ex_mem_rd == id_ex_rs1)) begin

            forward_a = 2'b01;
        end

        // MEM/WB forwarding
        else if (mem_wb_reg_write &&
                 (mem_wb_rd != 3'b000) &&
                 (mem_wb_rd == id_ex_rs1)) begin

            forward_a = 2'b10;
        end

        // ========================================================
        // Forwarding for ALU/FPU operand B
        // ========================================================

        // EX/MEM has the newest value
        if (ex_mem_reg_write &&
            (ex_mem_rd != 3'b000) &&
            (ex_mem_rd == id_ex_rs2)) begin

            forward_b = 2'b01;
        end

        // MEM/WB forwarding
        else if (mem_wb_reg_write &&
                 (mem_wb_rd != 3'b000) &&
                 (mem_wb_rd == id_ex_rs2)) begin

            forward_b = 2'b10;
        end

    end

endmodule
