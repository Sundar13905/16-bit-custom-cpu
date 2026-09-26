module mem_wb_reg (
    input wire clk,
    input wire rst_n,

    input wire [15:0] memory_data_in,
    input wire [15:0] execution_result_in,
    input wire [15:0] pc_plus1_in,
    input wire [2:0]  rd_in,

    input wire        reg_write_in,
    input wire [1:0]  wb_select_in,

    output reg [15:0] memory_data_out,
    output reg [15:0] execution_result_out,
    output reg [15:0] pc_plus1_out,
    output reg [2:0]  rd_out,

    output reg        reg_write_out,
    output reg [1:0]  wb_select_out
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        memory_data_out     <= 16'h0000;
        execution_result_out<= 16'h0000;
        pc_plus1_out        <= 16'h0000;
        rd_out              <= 3'b000;

        reg_write_out       <= 1'b0;
        wb_select_out       <= 2'b00;
    end
    else begin
        memory_data_out      <= memory_data_in;
        execution_result_out <= execution_result_in;
        pc_plus1_out         <= pc_plus1_in;
        rd_out               <= rd_in;

        reg_write_out        <= reg_write_in;
        wb_select_out        <= wb_select_in;
    end
end

endmodule
