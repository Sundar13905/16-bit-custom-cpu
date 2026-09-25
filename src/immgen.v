`timescale 1ns / 1ps

module immgen (
    input  wire [15:0] instr,
    output reg  [15:0] imm_out
);

    always @(*) begin

        case (instr[14:12])

            // ==================================================
            // LH
            // SH
            // Immediate arithmetic
            // JALR
            // ==================================================
            3'b001,
            3'b010,
            3'b011,
            3'b111: begin

                imm_out = {{12{instr[15]}},
                           instr[15],
                           instr[5:3]};

            end


            // ==================================================
            // Branch
            // ==================================================
            3'b100: begin

                imm_out = {{12{instr[15]}},
                           instr[15],
                           instr[5:3]};

            end


            // ==================================================
            // JAL
            // ==================================================
            3'b101: begin

                imm_out = {{12{instr[15]}},
                           instr[15],
                           instr[5:3]};

            end


            default: begin

                imm_out = 16'h0000;

            end

        endcase

    end

endmodule
