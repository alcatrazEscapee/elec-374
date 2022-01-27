module register_file (
	input [31:0] write_data,
	input [15:0] write_select, // 1-hot encoded, as it will be mapped to control signals
	input [3:0] read_addr_a, // bit encoded, as it will be read directly from a field in the instructions
	input [3:0] read_addr_b,
	output [31:0] data_a,
	output [31:0] data_b,
	input clk,
	input clr
);
	// 16x 32-Bit Register File
	// Dual ported: each register connects to two multiplexers which determine the output
	wire [31:0] data [15:0];

	// r0
	assign data[0] = 32'b0;
	
	genvar i;
	generate
		// Ignore r0, as it has a no-op (zero) connection
		for (i = 1; i < 16; i = i + 1) begin : gen_r
			register ri ( .q(write_data), .d(data[i]), .clk(clk), .clr(clr), .en(write_select[i]) );
		end
	endgenerate
	
	assign data_a = data[read_addr_a];
	assign data_b = data[read_addr_b];

endmodule


`timescale 1ns/100ps
module register_file_test;

	reg [31:0] z;
	reg [15:0] sel_z;
	reg [3:0] addr_a, addr_b;
	wire [31:0] a, b;
	reg clk, clr;
	
	register_file rf ( .write_data(z), .write_select(sel_z), .read_addr_a(addr_a), .read_addr_b(addr_b), .data_a(a), .data_b(b), .clk(clk), .clr(clr) );
	
	// Clock
	initial begin
		clk <= 1'b0;
		forever #5 clk = ~clk;
	end
	
	// Test
	initial begin
		#7 // Offset so we're in the middle of the positive clock signal
		clr <= 1'b1; // clr is assumed to work as it's only connected to the internal register's clr line
		
		// Write some data
		z <= 853;
		sel_z <= 16'b0000100000000000; // r11
		#10;
		z <= 124;
		sel_z <= 16'b0000000000010000; // r4
		#10;
		z <= 888;
		sel_z <= 16'b1000000000000000; // r15
		#10;
		z <= 999;
		sel_z <= 16'b0000000000000001; // r0
		#10;
		
		sel_z <= 16'b0;
		
		// Read data back again, checking both channels
		addr_a <= 11;
		addr_b <= 15;
		#1;
		$display("Test | register file read a1 | a=853 | a=%0d", a);
		$display("Test | register file read b1 | b=888 | b=%0d", b);
		
		#9;
		addr_a <= 4;
		addr_b <= 0;
		#1;
		$display("Test | register file read a2 | a=124 | a=%0d", a);
		$display("Test | register file read b2 | b=0 | b=%0d", b);
		
		$finish;
	end
endmodule
