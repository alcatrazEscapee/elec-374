/*
 * In a value of length (1 << BITS) bits, counts the number of leading zeros from the MSB
 * If the value is uniformly zero, this returns count = 0b111..1, and zero = 1
 * Otherwise, zero = 0
 */
module count_leading_zeros #(
	parameter BITS = 5
) (
	input [(1 << BITS) - 1:0] value,
	output [BITS - 1:0] count,
	output zero
);
	// This uses a recursive approach emulating the following (pseudocode) function
	// The recursive parameters of value is packed into the zeros vector, and the count stores each bit
	//
	// def clz(value, size = 32):
	//     if top size/2 bits are all zero:
	//         return size/2 + clz(top size/2 bits of value, size/2)
	//     else:
	//         return clz(bottom size/2 bits of value, size/2)
	
	// Layout: [    N bits  ]...[  8b  ][ 4b ][2b][1b]
	wire [(1 << (BITS + 1)) - 1:1] zeros;
	
	assign zeros[(1 << (BITS + 1)) - 1:(1 << BITS)] = value;
	assign zero = ~ (| value);

	genvar i;
	generate
		for (i = 1; i <= BITS; i = i + 1) begin : gen_cz
			assign count[i - 1] = zeros[(1 << (i + 1)) - 1:(1 << (i - 1)) + (1 << i)] == {(1 << (i - 1)){1'b0}};
			assign zeros[(1 << i) - 1:(1 << (i - 1))] = count[i - 1] ?
				zeros[(1 << (i + 1)) - (1 << (i - 1)) - 1:(1 << i)] :
				zeros[(1 << (i + 1)) - 1:(1 << (i - 1)) + (1 << i)];
		end
	endgenerate

endmodule


`timescale 1ns/100ps
module count_leading_zeros_test;

	reg [7:0] value;
	wire [2:0] count;
	wire zero;
	
	count_leading_zeros #( .BITS(3) ) clz ( .value(value), .count(count), .zero(zero) );
	
	integer i, j;
	
	initial begin
	
		// Explicit test cases
		value <= 8'b00000000; #1 $display("Test | count Z | v=0b00000000, c=7, z=1 | v=0b%b, c=%0d, z=%b", value, count, zero);
		value <= 8'b00000001; #1 $display("Test | count 7 | v=0b00000001, c=7, z=0 | v=0b%b, c=%0d, z=%b", value, count, zero);
		value <= 8'b00000010; #1 $display("Test | count 6 | v=0b00000010, c=6, z=0 | v=0b%b, c=%0d, z=%b", value, count, zero);
		value <= 8'b00000100; #1 $display("Test | count 5 | v=0b00000100, c=5, z=0 | v=0b%b, c=%0d, z=%b", value, count, zero);
		value <= 8'b00001000; #1 $display("Test | count 4 | v=0b00001000, c=4, z=0 | v=0b%b, c=%0d, z=%b", value, count, zero);
		value <= 8'b00010000; #1 $display("Test | count 3 | v=0b00010000, c=3, z=0 | v=0b%b, c=%0d, z=%b", value, count, zero);
		value <= 8'b00100000; #1 $display("Test | count 2 | v=0b00100000, c=2, z=0 | v=0b%b, c=%0d, z=%b", value, count, zero);
		value <= 8'b01000000; #1 $display("Test | count 1 | v=0b01000000, c=1, z=0 | v=0b%b, c=%0d, z=%b", value, count, zero);
		value <= 8'b10000000; #1 $display("Test | count 0 | v=0b10000000, c=0, z=0 | v=0b%b, c=%0d, z=%b", value, count, zero);
		
		// Random test cases
		for (i = 0; i < 100; i = i + 1) begin
			j = $urandom % 8;
			value = (($urandom & 8'hff) >> j) | (8'b1 << (7 - j));
			#1 $display("Test | count v=0b%b | c=%0d, z=0 | c=%0d, z=%b", value, j, count, zero);
		end
		
		$finish;
	end
endmodule
