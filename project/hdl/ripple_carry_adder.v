/**
 * N-Bit Ripple Carry Adder (RCA)
 */
module ripple_carry_adder #(
	parameter BITS = 32
) (
	input [BITS - 1:0] a,
	input [BITS - 1:0] b,
	output [BITS - 1:0] sum,
	input c_in,
	output c_out
);

	// Internal carry line
	wire [BITS:0] carry;
	
	// Connect to c_in and c_out
	assign carry[0] = c_in;
	assign c_out = carry[BITS];
	
	genvar i;
	generate
		for (i = 0; i < BITS; i = i + 1) begin : gen_adder
			full_adder fa ( .a(a[i]), .b(b[i]), .sum(sum[i]), .c_in(carry[i]), .c_out(carry[i + 1]) );
		end
	endgenerate
endmodule


`timescale 1ns/100ps
module ripple_carry_adder_test;
	
	// 5-Bit RCA : Small enough to test all possible inputs exhaustively (32 * 32 * 2 = 2048 inputs)
	reg [4:0] a, b;
	reg c_in;
	wire [5:0] sum;
	
	ripple_carry_adder #( .BITS(5) ) rca ( .a(a), .b(b), .sum(sum[4:0]), .c_in(c_in), .c_out(sum[5]) );

	integer i, j, k;
	
	initial begin
		for (i = 0; i < 32; i = i + 1) begin
			for (j = 0; j < 32; j = j + 1) begin
				for (k = 0; k <= 1; k = k + 1) begin
					a <= i;
					b <= j;
					c_in <= k;
					#1 $display("Test | add %0d + %0d | %0d | %0d", a, b, i + j + k, sum);
				end
			end
		end
		
		$finish;
	end
endmodule
