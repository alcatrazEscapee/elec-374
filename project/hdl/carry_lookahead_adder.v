/**
 * A 16N-Bit RCA, implemented with two levels of nested CLAs.
 * The parameter specifies the bits in multiples of 16 bits.
 */
module carry_lookahead_adder #(
	parameter BITS16 = 2
) (
	input [(BITS16 * 16) - 1:0] a,
	input [(BITS16 * 16) - 1:0] b,
	output [(BITS16 * 16) - 1:0] sum,
	input c_in,
	output c_out
);

	// Internal carry line
	wire [BITS16:0] carry;
	wire [BITS16 - 1:0] gi, pi;
	
	// Connect to c_in and c_out
	assign carry[0] = c_in;
	assign c_out = carry[BITS16];
	
	genvar i;
	generate
		for (i = 0; i < BITS16; i = i + 1) begin : gen_adder
			carry_lookahead_adder_16b cla (
				.a(a[(16 * i) + 15:16 * i]),
				.b(b[(16 * i) + 15:16 * i]),
				.sum(sum[(16 * i) + 15:16 * i]),
				.c_in(carry[i]),
				.c_out(carry[i + 1])
			);
		end
	endgenerate
endmodule


`timescale 1ns/100ps
module carry_lookahead_adder_test;
	
	reg [31:0] a, b;
	wire [32:0] sum, a32, b32;
	reg c_in;
	
	integer i;
	
	assign a32 = {1'b0, a};
	assign b32 = {1'b0, b};
	
	carry_lookahead_adder #( .BITS16(2) ) cla ( .a(a), .b(b), .sum(sum[31:0]), .c_in(c_in), .c_out(sum[32]) );
	
	initial begin
		for (i = 0; i < 1000; i = i + 1) begin
			a <= $random;
			b <= $random;
			c_in <= $random;
			#1 $display("Test | add %0d + %0d + %0d | %0d | %0d", a, b, c_in, a32 + b32 + c_in, sum);
		end
		
		$finish;
	end

endmodule
