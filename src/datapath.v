`timescale 1ns / 1ps

module decoder (

    input wire [15:0] instr,

    output reg [3:0] alu_ctrl,

    output reg reg_write,
    output reg mem_read,
    output reg mem_write,

    output reg branch,
    output reg jump,

    output reg alu_src

);

    wire [2:0] opcode;
    wire [2:0] funct;

    assign opcode = instr[14:12];
    assign funct  = instr[2:0];


    always @(*) begin

        alu_ctrl  = 4'b0000;

        reg_write = 1'b0;
        mem_read  = 1'b0;
        mem_write = 1'b0;

        branch    = 1'b0;
        jump      = 1'b0;

        alu_src   = 1'b0;


        case (opcode)

            // R-type
            3'b000: begin

                reg_write = 1'b1;

                case (funct)

                    3'b000: alu_ctrl = 4'b0000; // ADD
                    3'b001: alu_ctrl = 4'b0001; // SUB
                    3'b010: alu_ctrl = 4'b1000; // SLT
                    3'b011: alu_ctrl = 4'b0110; // SRL
                    3'b100: alu_ctrl = 4'b0011; // OR
                    3'b101: alu_ctrl = 4'b0101; // SLL
                    3'b110: alu_ctrl = 4'b0010; // AND
                    3'b111: alu_ctrl = 4'b0111; // SRA

                    default:
                        alu_ctrl = 4'b0000;

                endcase

            end


            // LH
            3'b001: begin

                reg_write = 1'b1;
                mem_read  = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = 4'b0000;

            end


            // SH
            3'b010: begin

                mem_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = 4'b0000;

            end


            // Immediate
            3'b011: begin

                reg_write = 1'b1;
                alu_src   = 1'b1;

                case (funct)

                    3'b000: alu_ctrl = 4'b0000; // ADDI
                    3'b001: alu_ctrl = 4'b0001; // SUBI
                    3'b010: alu_ctrl = 4'b1000; // SLTI
                    3'b011: alu_ctrl = 4'b0110; // SRLI
                    3'b100: alu_ctrl = 4'b0011; // ORI
                    3'b101: alu_ctrl = 4'b0101; // SLLI
                    3'b110: alu_ctrl = 4'b0010; // ANDI
                    3'b111: alu_ctrl = 4'b0111; // SRAI

                    default:
                        alu_ctrl = 4'b0000;

                endcase

            end


            // Branch
            3'b100: begin

                branch   = 1'b1;
                alu_ctrl = 4'b0001;

            end


            // JAL
            3'b101: begin

                jump = 1'b1;

            end


            // FPU
            3'b110: begin

                reg_write = 1'b1;

            end


            // JALR
            3'b111: begin

                jump     = 1'b1;
                alu_src  = 1'b1;

            end


            default: begin
            end

        endcase

    end

endmodule
