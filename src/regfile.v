module regfile (
    input  wire        clk,
    input  wire        rst,
    input  wire        reg_write,

    input  wire [2:0]  read_reg1,
    input  wire [2:0]  read_reg2,
    input  wire [2:0]  write_reg,

    input  wire [15:0] write_data,

    output wire [15:0] read_data1,
    output wire [15:0] read_data2
);

    reg [15:0] registers [0:7];
    integer i;

    // Initial values for simulation/testing
    initial begin
        for (i = 0; i < 8; i = i + 1)
            registers[i] = 16'h0000;

        registers[0] = 16'h0000;
        registers[1] = 16'h0001;
        registers[2] = 16'h0002;
        registers[3] = 16'h0003;
        registers[4] = 16'h0004;
        registers[5] = 16'h0005;
        registers[6] = 16'h0006;
        registers[7] = 16'h0007;
    end

    // Combinational reads
    assign read_data1 = registers[read_reg1];
    assign read_data2 = registers[read_reg2];

    // Synchronous write
    always @(posedge clk) begin
        if (rst) begin
            registers[0] <= 16'h0000;
        end
        else if (reg_write && (write_reg != 3'b000)) begin
            registers[write_reg] <= write_data;
        end
    end

endmodule
