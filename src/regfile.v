`timescale 1ns / 1ps

// Simple 8x16 Register File
module regfile (
    input  wire        clk,          // clock
    input  wire        reg_write,    // write enable
    input  wire [2:0]  read_reg1,    // address of source register 1
    input  wire [2:0]  read_reg2,    // address of source register 2
    input  wire [2:0]  write_reg,    // address of destination register
    input  wire [15:0] write_data,   // data to be written
    output wire [15:0] read_data1,   // data from source register 1
    output wire [15:0] read_data2    // data from source register 2
);
    // inside regfile module (after declaration of registers)
    initial begin
        registers[0] = 16'h0000;
        registers[1] = 16'h0001; // r1 = 1
        registers[2] = 16'h0002; // r2 = 2
        registers[3] = 16'h0003; // r3 = 3
        registers[4] = 16'h0004;
        registers[5] = 16'h0005;
        // others = 0 already (optional)
    end


    // 8 general-purpose 16-bit registers
    reg [15:0] registers [7:0];

    // Read operations (combinational)
    assign read_data1 = registers[read_reg1];
    assign read_data2 = registers[read_reg2];

    // Write operation (synchronous on positive edge)
    always @(posedge clk) begin
        if (reg_write && (write_reg != 0))
            registers[write_reg] <= write_data;
if (reg_write) registers[write_reg] <= write_data;
    end

endmodule
