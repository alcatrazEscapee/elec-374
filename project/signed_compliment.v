/**
 * N-Bit Signed 2's Compliment Negation x -> (-x)
 */
module signed_compliment #(
	parameter BITS = 32
) (
	input [BITS - 1:0] in,
	output [BITS - 1:0] out
);

	// Negation = Invert all bits and add one
	// Addition is performed with a single carry chain, similar to a RCA if b = 0
	wire [BITS - 1:0] carry;
	
	assign carry[0] = 1'b1; // c_in = 0
	assign carry[BITS - 1:1] = (~in[BITS - 2:0]) & carry[BITS - 2:0]; // carry chain, ci+1 = xi & ci
	assign out = (~in) ^ carry; // summation, s = xi ^ ci

endmodule


`timescale 1ns/100ps
module signed_compliment_test;

	reg signed [4:0] in;
	wire signed [4:0] out;

	integer i;
	
	signed_compliment #( .BITS(5) ) sc ( .in(in), .out(out) );
	
	initial begin
		for (i = 0; i < 32; i = i + 1) begin
			in <= i;
			#1 $display("Test | compliment -%0d | %0d | %0d", in, out, -in);
		end
	end

endmodule
