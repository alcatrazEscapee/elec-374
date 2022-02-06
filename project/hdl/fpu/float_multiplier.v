module float_multiplier (
	input [31:0] fa,
	input [31:0] fb,
	output reg [31:0] fz,
	
	// ALU Interface
	output [31:0] alu_a,
	output [31:0] alu_b,
	input [63:0] alu_product
);
	// Decompose
	wire sa, sb, sz;
	wire [7:0] ea, eb;
	wire [22:0] ma, mb;
	reg [31:0] fproduct;
	
	assign {sa, ea, ma} = fa;
	assign {sb, eb, mb} = fb;
	assign sz = sa ^ sb;
	
	// Handle special cases of NaN, Infinity, and Zero
	always @(*) begin
		casez ({1'b0, fa[30:0], 1'b0, fb[30:0]}) // Ignore the sign bit for now
			// NaN * NaN = NaN
			// Output is negative only if both inputs are negative.
			64'h7fc00000_7fc00000 : fz = {sa & sb, 31'h7fc00000};
			// NaN * Anything or Anything * NaN
			// Output the NaN input exactly (copy the sign)
			64'h7fc00000_???????? : fz = fa;
			64'h????????_7fc00000 : fz = fb;
			// Infinity * Infinity
			// Multiplication takes the product of the sign and returns infinity
			// Division of infinity / infinity is always -NaN
			64'h7f800000_7f800000 : fz = {sz, 31'h7f800000};
			// Infinity * Zero and Zero * Infinity
			// Multiplication of infinity and zero is undefined and will return -NaN
			64'h7f800000_00000000 : fz = 32'hffc00000;
			64'h00000000_7f800000 : fz = 32'hffc00000;
			// Infinity * Real and Real * Infinity
			// Multiplication takes the product of the sign and returns infinity
			64'h7f800000_???????? : fz = {sz, 31'h7f800000};
			64'h????????_7f800000 : fz = {sz, 31'h7f800000};			
			// Zero * Zero
			// Multiplication takes the product of the signs
			// Division is undefined and returns -NaN
			64'h00000000_00000000 : fz = {sz, 31'b0};
			// Zero * Anything or Anything * Zero
			// Multiplication takes the product of the signs and returns zero
			64'h00000000_???????? : fz = {sz, 31'b0};
			64'h????????_00000000 : fz = {sz, 31'b0};
			// Nonzero + Nonzero
			// Output the sum as calculated below
			default : fz = fproduct;
		endcase
	end
	
	// Assume both operands are not NaN, Infinity, or Zero
	
	// Subnormal inputs have a leading '0' instead of '1', and have a +1 exponent
	wire a_subnormal, b_subnormal;
	
	assign a_subnormal = ea == 8'b0;
	assign b_subnormal = eb == 8'b0;
	
	// Compute the new target exponent: ea + (eb - 127)
	// Extend ea and eb to 10-bit, 2's compliment, enough for positive and overflow protection
	// Also handle subnormal exponents here
	wire [9:0] ea_long, eb_long;
	
	assign ea_long = {2'b00, a_subnormal ? 8'b1 : ea};
	assign eb_long = {2'b00, b_subnormal ? 8'b1 : eb};
	
	wire [9:0] e_sum0, e_sum1, e_sum2;
	
	ripple_carry_adder #( .BITS(10) ) _exp_sum0 ( .a(ea_long), .b(eb_long), .sum(e_sum0), .c_in(1'b0), .c_out() );
	ripple_carry_adder #( .BITS(10) ) _exp_sum1 ( .a(e_sum0), .b(/* -127 */ 10'b1110000001), .sum(e_sum1), .c_in(1'b0), .c_out() );
		
	// Calculate the product / quotient of the mantissas
	// Extend both by the leading digit, and then extend to 32-bit
	// The actual operation is performed by the ALU, as both are large (area) operations
	assign alu_a = {8'b0, a_subnormal ? 1'b0 : 1'b1, ma};
	assign alu_b = {8'b0, b_subnormal ? 1'b0 : 1'b1, mb};
	
	// The result of the ALU operation is a 64-bit product, with no loss of precision.
	// Cases:
	// Maximum Normal x Normal    : 1.111..1 * 1.111..1 = 11.111..1, with top bit at bit 47
	// 1 x 1 Normal               : 1.000..0 * 1.000..0 = 1.000..0, with top bit at bit 46
	// Minimum Normal x Subnormal : 1.000..0 * 0.000..1 = 1.000..0, with top bit at bit 23
	// Subnormal x Subnormal      : Always zero, due to the exponents, even with maximum value mantissas
	// The maximum value of the multiplication 1.x...x * 1.x...x = 11.x...x, with the top bit in bit 47
	// We then count the leading zeros to determine our shift and normalization
	wire [5:0] leading_zeros;
	wire [9:0] leading_zeros_compliment, e_sum_norm;
	
	count_leading_zeros #( .BITS(6) ) _clz ( .value({alu_product[47:0], 16'b0}), .count(leading_zeros), .zero() );
	
	// Exponent += 1 - leading_zeros
	signed_compliment #( .BITS(10) ) _lzc ( .in({4'b0, leading_zeros}), .out(leading_zeros_compliment) );
	ripple_carry_adder #( .BITS(10) ) _exp_sum2 ( .a(e_sum1), .b(leading_zeros_compliment), .sum(e_sum2), .c_in(1'b1), .c_out() );
	
	// Detect subnormal exponents
	// If the exponent is negative, we set the result exponent to zero, and adjust the shift amount accordingly
	wire is_subnormal;
	wire [9:0] e_normalized, e_normalized_c;
	wire [63:0] m_shifted_64b, m_normalized_64b;
	
	assign is_subnormal = e_sum2[9] || e_sum2 == 10'b0; // Negative, or Zero
	assign e_normalized = is_subnormal ? 10'b0 : e_sum2;
		
	left_shift #( .BITS(64), .SHIFT_BITS(7) ) _normalize_m (
		.in({alu_product[47:0], 16'b0}),
		.shift({1'b0, leading_zeros}),
		.out(m_shifted_64b),
		.is_rotate(1'b0), .accumulate()
	);
	
	// Handle subnormal products
	// Right shift the mantissa based on the difference between the min exponent (-126), and the required exponent
	signed_compliment #( .BITS(10) ) _subnormal_exp_c ( .in(e_sum2), .out(e_normalized_c) );
	right_shift #( .BITS(64), .SHIFT_BITS(10) ) _subnormal_m (
		.in(m_shifted_64b),
		.shift(is_subnormal ? e_normalized_c : 10'b0),
		.out(m_normalized_64b),
		.is_rotate(1'b0), .accumulate()
	);
	
	wire [22:0] m_rounded;
	wire round_overflow;
	
	// Round the shifted result to 23-bit
	// Drop the implicit leading bit '1', if not subnormal
	wire [62:0] m_normalized_no_leading;
	
	assign m_normalized_no_leading = is_subnormal ? m_normalized_64b[63:1] : m_normalized_64b[62:0];
	round_to_nearest_even #( .BITS_IN(63), .BITS_OUT(23) ) _m_round ( .in(m_normalized_no_leading), .out(m_rounded), .overflow(round_overflow) );
	
	// If there was a rounding overflow, the exponent needs to be incremented
	wire [9:0] e_increment;
	
	ripple_carry_adder #( .BITS(10) ) _e_inc ( .a(e_normalized), .b(10'b0), .sum(e_increment), .c_in(round_overflow), .c_out() );
	
	// Detect overflow - if the exponent is greater than +126, overflow occurred at some previous step
	wire exponent_overflow;
	
	greater_than_unsigned #( .BITS(10) ) _e_overflow ( .a(e_increment), .b(/* +126 */ 10'b0011111110), .gt(exponent_overflow) );
	
	always @(*) begin
		if (a_subnormal && b_subnormal) // Subnormal x Subnormal = Zero
			fproduct = {sz, 31'b0};
		if (exponent_overflow) // Overflow (+inf / -inf)
			fproduct = {sz, 31'h7f800000};
		else
			fproduct = {sz, e_increment[7:0], m_rounded};
	end

endmodule


`timescale 1ns/100ps
module float_multiplier_test;

	reg [31:0] a, b;
	reg sa, sb;
	reg [7:0] ea, eb;
	reg [22:0] ma, mb;
	reg decomposed_in; // If the input should be mapped to {s, e, m} or the direct 32-bit input
	
	wire signed [63:0] alu_product, alu_a, alu_b;
	
	wire [31:0] a_in, b_in, result;
	
	integer i, exponent, sign, mantissa;

	assign a_in = decomposed_in ? {sa, ea, ma} : a;
	assign b_in = decomposed_in ? {sb, eb, mb} : b;
	
	// Mock ALU
	assign alu_product = alu_a * alu_b;
	assign alu_a[63:32] = 32'b0;
	assign alu_b[63:32] = 32'b0;
	
	float_multiplier _fmul ( .fa(a_in), .fb(b_in), .fz(result), .alu_a(alu_a[31:0]), .alu_b(alu_b[31:0]), .alu_product(alu_product) );

	initial begin
	
		// Specific Test Cases
		decomposed_in <= 1'b0;
		
		// NaN
		
		a <= 32'h7fc00000; b <= 32'h7fc00000; #1 $display("Test fpu * |  NaN *  NaN | %h | %h | %h", a, b, result);
		a <= 32'h7fc00000; b <= 32'hffc00000; #1 $display("Test fpu * |  NaN * -NaN | %h | %h | %h", a, b, result);
		a <= 32'hffc00000; b <= 32'h7fc00000; #1 $display("Test fpu * | -NaN *  NaN | %h | %h | %h", a, b, result);
		a <= 32'hffc00000; b <= 32'hffc00000; #1 $display("Test fpu * | -NaN * -NaN | %h | %h | %h", a, b, result);
		
		a <= 32'h7fc00000; b <= 32'h12345678; #1 $display("Test fpu * |  NaN *   ?  | %h | %h | %h", a, b, result);
		a <= 32'hffc00000; b <= 32'h12345678; #1 $display("Test fpu * | -NaN *   ?  | %h | %h | %h", a, b, result);
		a <= 32'h12345678; b <= 32'h7fc00000; #1 $display("Test fpu * |   ?  *  NaN | %h | %h | %h", a, b, result);
		a <= 32'h12345678; b <= 32'hffc00000; #1 $display("Test fpu * |   ?  * -NaN | %h | %h | %h", a, b, result);

		// Infinity
		
		a <= 32'h7f800000; b <= 32'h7f800000; #1 $display("Test fpu * |  inf *  inf | %h | %h | %h", a, b, result);
		a <= 32'h7f800000; b <= 32'hff800000; #1 $display("Test fpu * |  inf * -inf | %h | %h | %h", a, b, result);
		a <= 32'hff800000; b <= 32'h7f800000; #1 $display("Test fpu * | -inf *  inf | %h | %h | %h", a, b, result);
		a <= 32'hff800000; b <= 32'hff800000; #1 $display("Test fpu * | -inf * -inf | %h | %h | %h", a, b, result);
		
		a <= 32'h7f800000; b <= 32'h12345678; #1 $display("Test fpu * |  inf *   ?  | %h | %h | %h", a, b, result);
		a <= 32'hff800000; b <= 32'h12345678; #1 $display("Test fpu * | -inf *   ?  | %h | %h | %h", a, b, result);
		a <= 32'h7f800000; b <= 32'h92345678; #1 $display("Test fpu * |  inf *  -?  | %h | %h | %h", a, b, result);
		a <= 32'hff800000; b <= 32'h92345678; #1 $display("Test fpu * | -inf *  -?  | %h | %h | %h", a, b, result);
		a <= 32'h12345678; b <= 32'h7f800000; #1 $display("Test fpu * |   ?  *  inf | %h | %h | %h", a, b, result);
		a <= 32'h12345678; b <= 32'hff800000; #1 $display("Test fpu * |   ?  * -inf | %h | %h | %h", a, b, result);
		a <= 32'h92345678; b <= 32'h7f800000; #1 $display("Test fpu * |  -?  *  inf | %h | %h | %h", a, b, result);
		a <= 32'h92345678; b <= 32'hff800000; #1 $display("Test fpu * |  -?  * -inf | %h | %h | %h", a, b, result);
		
		// Infinity and Zero
				
		a <= 32'h7f800000; b <= 32'h00000000; #1 $display("Test fpu * |  inf *  0 | %h | %h | %h", a, b, result);
		a <= 32'h7f800000; b <= 32'h80000000; #1 $display("Test fpu * |  inf * -0 | %h | %h | %h", a, b, result);
		a <= 32'hff800000; b <= 32'h00000000; #1 $display("Test fpu * | -inf *  0 | %h | %h | %h", a, b, result);
		a <= 32'hff800000; b <= 32'h80000000; #1 $display("Test fpu * | -inf * -0 | %h | %h | %h", a, b, result);
		
		a <= 32'h00000000; b <= 32'h7f800000; #1 $display("Test fpu * |  0 *  inf | %h | %h | %h", a, b, result);
		a <= 32'h80000000; b <= 32'h7f800000; #1 $display("Test fpu * | -0 *  inf | %h | %h | %h", a, b, result);
		a <= 32'h00000000; b <= 32'hff800000; #1 $display("Test fpu * |  0 * -inf | %h | %h | %h", a, b, result);
		a <= 32'h80000000; b <= 32'hff800000; #1 $display("Test fpu * | -0 * -inf | %h | %h | %h", a, b, result);
				
		// Zero (Positive and Negative)
		
		a <= 32'h00000000; b <= 32'h00000000; #1 $display("Test fpu * |  0 *  0 | %h | %h | %h", a, b, result);
		a <= 32'h00000000; b <= 32'h80000000; #1 $display("Test fpu * |  0 * -0 | %h | %h | %h", a, b, result);
		a <= 32'h80000000; b <= 32'h00000000; #1 $display("Test fpu * | -0 *  0 | %h | %h | %h", a, b, result);
		a <= 32'h80000000; b <= 32'h80000000; #1 $display("Test fpu * | -0 * -0 | %h | %h | %h", a, b, result);
		
		a <= 32'h00000000; b <= 32'h12345678; #1 $display("Test fpu * |  0 *  ? | %h | %h | %h", a, b, result);
		a <= 32'h80000000; b <= 32'h12345678; #1 $display("Test fpu * | -0 *  ? | %h | %h | %h", a, b, result);
		a <= 32'h12345678; b <= 32'h00000000; #1 $display("Test fpu * |  ? *  0 | %h | %h | %h", a, b, result);
		a <= 32'h12345678; b <= 32'h80000000; #1 $display("Test fpu * |  ? * -0 | %h | %h | %h", a, b, result);

		// Switch to using the decomposed input
		sa <= 1'b0; ea <= 8'b0; ma <= 23'b0;
		sb <= 1'b0; eb <= 8'b0; mb <= 32'b0;
		decomposed_in <= 1'b1;
		
		for (i = 0; i < 4000; i = i + 1) begin
			sa <= $urandom;
			sb <= $urandom;
			ea <= 20 + ($urandom % 215);
			eb <= 20 + ($urandom % 215);
			ma <= $urandom;
			mb <= $urandom;
			#1 $display("Test fpu * | float multiply | %h | %h | %h", a_in, b_in, result);
		end
		
		$finish;
	end
endmodule
