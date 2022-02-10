module register_file #(
	parameter WORDS = 16,
	parameter BITS = 32,
	parameter ADDRESS_BITS = $clog2(WORDS)
) (
	input [BITS - 1:0] data_in,
	input [ADDRESS_BITS - 1:0] addr_in,
	input [ADDRESS_BITS - 1:0] addr_a,
	input [ADDRESS_BITS - 1:0] addr_b,
	output [31:0] data_a,
	output [31:0] data_b,
	input clk,
	input clr
);
	wire [BITS - 1:0] data [WORDS - 1:0];

	// r0
	assign data[0] = 32'b0;
	
	genvar i;
	generate
		// Ignore r0, as it has a no-op (zero) connection
		for (i = 1; i < WORDS; i = i + 1) begin : gen_r
			register ri ( .q(data_in), .d(data[i]), .clk(clk), .clr(clr), .en(addr_in == i) );
		end
	endgenerate
	
	assign data_a = data[addr_a];
	assign data_b = data[addr_b];

endmodule


`timescale 1ns/100ps
module register_file_test;

	reg [31:0] z;
	reg [3:0] addr_z, addr_a, addr_b;
	wire [31:0] a, b;
	reg clk, clr;
	
	register_file rf ( .data_in(z), .addr_in(addr_z), .addr_a(addr_a), .addr_b(addr_b), .data_a(a), .data_b(b), .clk(clk), .clr(clr) );
	
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
		addr_z <= 11;
		#10;
		z <= 124;
		addr_z <= 4;
		#10;
		z <= 888;
		addr_z <= 15;
		#10;
		z <= 999;
		addr_z <= 0;
		#10;
		
		addr_z <= 0;
		
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
