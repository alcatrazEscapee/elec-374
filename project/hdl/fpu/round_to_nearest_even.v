module round_to_nearest_even #(
	parameter BITS_IN = 32,
	parameter BITS_OUT = 8
) (
	input [BITS_IN - 1:0] in,
	output [BITS_OUT - 1:0] out,
	output overflow // If while rounding, the value overflowed
);
	localparam FIRST_ROUNDED_BIT = BITS_IN - BITS_OUT - 1;
	localparam FIRST_KEPT_BIT = BITS_IN - BITS_OUT;
	
	wire round_up, carry;

	// Rounding is complicated
	// IEEE-754 rounds to nearest, but also rounds ties to even
	// A tie occurs when the lower bits of the input are exactly 1000...0
	// Rounding then needs to happen only if the lowest bit of the mantissa is 1 (aka, the truncated integer is odd)
	assign round_up = in[FIRST_ROUNDED_BIT] & (
		(| in[FIRST_ROUNDED_BIT - 1:0]) | // Any lower bits are non-zero (this would break the tie)
		in[FIRST_KEPT_BIT]); // Or the lowest bit of the mantissa is 1
	
	wire [BITS_OUT - 1:0] rounded_up;
	
	ripple_carry_adder #( .BITS(BITS_OUT) ) _round_up (
		.a(in[BITS_IN - 1:FIRST_KEPT_BIT]),
		.b({BITS_OUT{1'b0}}),
		.sum(rounded_up),
		.c_in(1'b1),
		.c_out(carry)
	);
	
	assign out = round_up ? rounded_up : in[BITS_IN - 1:FIRST_KEPT_BIT];
	assign overflow = round_up & carry;
endmodule


`timescale 1ns/100ps
module round_to_nearest_even_test;

	reg [3:0] in;
	wire [1:0] out;
	wire overflow;
	
	round_to_nearest_even #( .BITS_IN(4), .BITS_OUT(2) ) _round ( .in(in), .out(out), .overflow(overflow) );
	
	initial begin
		in <= 4'b0000; #1 $display("Test | round %b | 0b00 v=0 | 0b%b v=%b", in, out, overflow);
		in <= 4'b0001; #1 $display("Test | round %b | 0b00 v=0 | 0b%b v=%b", in, out, overflow);
		in <= 4'b0010; #1 $display("Test | round %b | 0b00 v=0 | 0b%b v=%b", in, out, overflow);
		in <= 4'b0011; #1 $display("Test | round %b | 0b01 v=0 | 0b%b v=%b", in, out, overflow);
		in <= 4'b0100; #1 $display("Test | round %b | 0b01 v=0 | 0b%b v=%b", in, out, overflow);
		in <= 4'b0101; #1 $display("Test | round %b | 0b01 v=0 | 0b%b v=%b", in, out, overflow);
		in <= 4'b0110; #1 $display("Test | round %b | 0b10 v=0 | 0b%b v=%b", in, out, overflow);
		in <= 4'b0111; #1 $display("Test | round %b | 0b10 v=0 | 0b%b v=%b", in, out, overflow);
		in <= 4'b1000; #1 $display("Test | round %b | 0b10 v=0 | 0b%b v=%b", in, out, overflow);
		in <= 4'b1001; #1 $display("Test | round %b | 0b10 v=0 | 0b%b v=%b", in, out, overflow);
		in <= 4'b1010; #1 $display("Test | round %b | 0b10 v=0 | 0b%b v=%b", in, out, overflow);
		in <= 4'b1011; #1 $display("Test | round %b | 0b11 v=0 | 0b%b v=%b", in, out, overflow);
		in <= 4'b1100; #1 $display("Test | round %b | 0b11 v=0 | 0b%b v=%b", in, out, overflow);
		in <= 4'b1101; #1 $display("Test | round %b | 0b11 v=0 | 0b%b v=%b", in, out, overflow);
		in <= 4'b1110; #1 $display("Test | round %b | 0b00 v=1 | 0b%b v=%b", in, out, overflow);
		in <= 4'b1111; #1 $display("Test | round %b | 0b00 v=1 | 0b%b v=%b", in, out, overflow);
	end
endmodule
