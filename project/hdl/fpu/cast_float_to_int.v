module cast_float_to_int (
	input [31:0] in,
	output reg [31:0] out,
	input is_signed,
	
	// Exceptions
	output reg cast_out_of_bounds, // Casting a negative to unsigned integer, or value outside of the range of the integer type
	output reg cast_undefined // Casting NaN or inf to an integer
);
	wire sign;
	wire [7:0] exponent;
	wire [22:0] mantissa;
	
	assign {sign, exponent, mantissa} = in;
	
	// Compare the exponent against two known values:
	// 1.xxx * 2^31 = maximum legal unsigned integer, in Excess-127, exponent > 159
	// 1.xxx * 2^30 = maximum legal signed integer (except for -1.0 * 2^-31), in Excess-127, exponent > 158
	// 1.xxx * 2^0 = minimum nonzero integer, in Excess-127, exponent = 127
	wire [7:0] maximum_legal_integer;
	wire gt_max, lt_min;
	
	assign maximum_legal_integer = is_signed ? 8'b10011101 : 8'b10011110;
	
	greater_than_unsigned #( .BITS(8) ) _gt_max ( .a(exponent), .b(maximum_legal_integer), .gt(gt_max) );
	greater_than_unsigned #( .BITS(8) ) _gt_min ( .a(8'b01111111), .b(exponent), .gt(lt_min) );
	
	// For valid exponents, pad the mantissa with 1.xxx, and shift (right) to the correct magnitude, accounting for Excess-127
	wire exp_carry_out;
	wire [7:0] shift_amount;
	wire [31:0] normalized;
	
	ripple_carry_adder #( .BITS(8) ) _exp_sub ( .a(/* 158 */ 8'b10011110), .b(~exponent), .sum(shift_amount), .c_in(1'b1), .c_out(exp_carry_out) );
	right_shift #( .BITS(32), .SHIFT_BITS(8) ) _exp_shift ( .in({1'b1, mantissa, 8'b0}), .shift(shift_amount), .out(normalized), .is_rotate(1'b0), .accumulate() );

	// Compliment the result for negative values
	wire [31:0] normalized_c;
	
	signed_compliment #( .BITS(32) ) _norm_c ( .in(normalized), .out(normalized_c) );
	
	always @(*) begin
		out = 32'b0;
		cast_out_of_bounds = 1'b0;
		cast_undefined = 1'b0;
		
		if (in == 32'h7fc00000 || in == 32'hffc00000 || in == 32'h7f800000 || in == 32'hff80000) // +/- NaN or +/- inf
			cast_undefined = 1'b1;
		else if (sign && !is_signed && normalized != 32'b0) // Negative to Unsigned (Nonzero)
			cast_out_of_bounds = 1'b1;
		else if (is_signed && in == 32'hcf000000) // Exact value for largest negative signed value
			out = 32'h80000000;
		else if (gt_max) // Positive overflow
			cast_out_of_bounds = 1'b1;
		else if (lt_min) // Less than minimum nonzero integer
			out = 32'b0;
		else if (sign && is_signed) // Signed 2's compliment
			out = normalized_c;
		else
			out = normalized;
	end
endmodule


`timescale 1ns/100ps
module cast_float_to_int_test;

	reg [31:0] in;
	reg is_signed;
	wire [31:0] out;
	wire cast_out_of_bounds, cast_undefined;
	
	wire exception;
	assign exception = cast_out_of_bounds | cast_undefined;
	
	integer i;
	
	cast_float_to_int _ftoi (
		.in(in),
		.out(out),
		.is_signed(is_signed),
		.cast_out_of_bounds(cast_out_of_bounds),
		.cast_undefined(cast_undefined)
	);

	initial begin
	
		// (Signed) Special Cases
		is_signed <= 1'b1;
		
		in <= 32'h7fc00000; #1 $display("Test fpu i | signed +NaN | %h | %h | %b", in, out, exception);
		in <= 32'hffc00000; #1 $display("Test fpu i | signed -NaN | %h | %h | %b", in, out, exception);
		in <= 32'h7f800000; #1 $display("Test fpu i | signed +inf | %h | %h | %b", in, out, exception);
		in <= 32'hff800000; #1 $display("Test fpu i | signed -inf | %h | %h | %b", in, out, exception);
		
		in <= 32'h00000000; #1 $display("Test fpu i | signed +0 | %h | %h | %b", in, out, exception);
		in <= 32'h10000000; #1 $display("Test fpu i | signed -0 | %h | %h | %b", in, out, exception);
		
		in <= 32'h4f000000; #1 $display("Test fpu i | signed +2^31   | %h | %h | %b", in, out, exception);
		in <= 32'h4effffff; #1 $display("Test fpu i | signed +2^31-1 | %h | %h | %b", in, out, exception);
		in <= 32'hcf000001; #1 $display("Test fpu i | signed -2^31+1 | %h | %h | %b", in, out, exception);
		in <= 32'hcf000000; #1 $display("Test fpu i | signed -2^31   | %h | %h | %b", in, out, exception);
		in <= 32'hceffffff; #1 $display("Test fpu i | signed -2^31-1 | %h | %h | %b", in, out, exception);
	
		// (Unsigned) Special Cases
		is_signed <= 1'b0;
		
		in <= 32'h7fc00000; #1 $display("Test fpu j | unsigned +NaN | %h | %h | %b", in, out, exception);
		in <= 32'hffc00000; #1 $display("Test fpu j | unsigned -NaN | %h | %h | %b", in, out, exception);
		in <= 32'h7f800000; #1 $display("Test fpu j | unsigned +inf | %h | %h | %b", in, out, exception);
		in <= 32'hff800000; #1 $display("Test fpu j | unsigned -inf | %h | %h | %b", in, out, exception);
		
		in <= 32'h00000000; #1 $display("Test fpu j | unsigned +0 | %h | %h | %b", in, out, exception);
		in <= 32'h10000000; #1 $display("Test fpu j | unsigned -0 | %h | %h | %b", in, out, exception);
		
		in <= 32'h4f800000; #1 $display("Test fpu j | unsigned +2^32   | %h | %h | %b", in, out, exception);
		in <= 32'h4f7fffff; #1 $display("Test fpu j | unsigned +2^32-1 | %h | %h | %b", in, out, exception);
		in <= 32'h80000001; #1 $display("Test fpu j | unsigned ? <<< 0 | %h | %h | %b", in, out, exception);
	
		// Random Tests
		
		for (i = 0; i < 1000; i = i + 1) begin
			in <= $urandom;
			is_signed <= 1'b1; #1 $display("Test fpu i | cast (signed)   0x%h | %h | %h | %b", in, in, out, exception);
			is_signed <= 1'b0; #1 $display("Test fpu j | cast (unsigned) 0x%h | %h | %h | %b", in, in, out, exception);
		end
		
		// Regressions
		is_signed <= 1'b0; in <= 32'h4cc73403; #1 $display("Test fpu j | cast regression 0x%h | %h | %h | %b", in, in, out, exception);
		is_signed <= 1'b0; in <= 32'hc64a8cd1; #1 $display("Test fpu j | cast regression 0x%h | %h | %h | %b", in, in, out, exception);
		
		$finish;
	end
endmodule
