module float_adder_subtractor (
	input [31:0] fa,
	input [31:0] fb,
	output reg [31:0] fz,
	input add_sub // add = 0 (a + b), sub = 1 (a - b)
);
	// IEEE-754 : [1b - Sign][8b - Exponent, Excess-127][23b - Mantissa]
			
	// Decompose
	wire sa, sb, sb_pre;
	wire [7:0] ea, eb;
	wire [22:0] ma, mb;
	
	assign {sa, ea, ma} = fa;
	assign {sb_pre, eb, mb} = fb; // Invert the sign of b if this is a subtraction
	assign sb = add_sub ? ~sb_pre : sb_pre;
	
	reg [31:0] f_sum; // Sum of fa + fb, assuming neither are inf or NaN
	
	// Handle special cases of NaN, Infinity, and Zero
	// NaN + Anything = NaN
	// inf + inf = NaN
	// inf + real = inf
	always @(*) begin
		casez ({1'b0, fa[30:0], 1'b0, fb[30:0]}) // Ignore the sign bit for now
			// NaN + NaN
			// Behaves the same in + or - meaning we use fa[31] and fb[31] to check the sign bit
			// Output is negative only if both inputs are negative, ignoring the operation (i.e. -NaN - -NaN is still negative)
			64'h7fc00000_7fc00000 : fz = 32'h7fc00000 | {fa[31] & fb[31], 31'b0};
			// NaN + Anything or Anything + NaN
			// Output the NaN input exactly (copy the sign)
			64'h7fc00000_???????? : fz = fa;
			64'h????????_7fc00000 : fz = fb;
			// Infinity + Infinity
			// This one **does** take into account the operation, and so inf - X == inf + (-X)
			// When the signs are the same, this outputs the input (so inf + inf = inf)
			// If the signs are different, it outputs -NaN
			64'h7f800000_7f800000 : fz = sa == sb ? fa : 32'hffc00000;
			// Infinity + Real or Real + Infinity
			// Output the infinity input exactly (copy the sign, including the operation)
			64'h7f800000_???????? : fz = fa;
			64'h????????_7f800000 : fz = {sb, fb[30:0]};
			// Zero + Zero
			// Output is zero, negative only when the signs of the operands (after applying the operation) are both negative
			64'h00000000_00000000 : fz = sa & sb ? 32'h80000000 : 32'h00000000;
			// Zero + Anything or Anything + Zero
			// Output the Anything input exactly (copy the sign, including the operation)
			64'h00000000_???????? : fz = {sb, fb[30:0]};
			64'h????????_00000000 : fz = fa;
			// Nonzero + Nonzero
			// Output the sum as calculated below
			default : fz = f_sum;
		endcase
	end
	
	// At this point, need to compute the sum fa + fb assuming neither are NaN
	// First determine which is the larger exponent
	// Exponents are stored in Excess-127
	
	wire a_gt_b;
	greater_than_unsigned #( .BITS(8) ) _exp_gt ( .a(ea), .b(eb), .gt(a_gt_b) );
	
	// Re-order the inputs into lo + hi (hi >= lo)
	wire s_lo, s_hi;
	wire [7:0] e_lo, e_hi;
	wire [22:0] m_lo, m_hi;
	
	assign {s_lo, s_hi} = a_gt_b ? {sb, sa} : {sa, sb};
	assign {e_lo, e_hi} = a_gt_b ? {eb, ea} : {ea, eb};
	assign {m_lo, m_hi} = a_gt_b ? {mb, ma} : {ma, mb};
	
	// Subtract the two exponents e_delta := (hi - lo) to find the difference
	// We can interpret both as 2's compliment (since signed + unsigned arithmetic works the same), and the difference will be valid for Excess-127
	// In addition, since we know hi >= lo there is no possibility for overflow or underflow (so we can ignore the carry out).
	wire [7:0] e_delta;
	wire exp_c_out;
	
	ripple_carry_adder #( .BITS(8) ) _exp_sub ( .a(e_hi), .b(~e_lo), .sum(e_delta), .c_in(1'b1), .c_out(exp_c_out) );
	
	// Pad the mantissas with a leading '01' and trailing '0', taking them from 23-bit -> 27-bit
	// - Leading '00' is needed as signed addition/subtraction is performed, and these need to initially represent positive numbers that are overflow protected
	// - Leading '1' is the implicit 1.xxx in the floating point representation, which is required when adding.
	// - Trailing '0' is an implicit bit used for rounding.
	wire [26:0] m_lo_long, m_hi_long;
	
	assign m_lo_long = {3'b001, m_lo, 1'b0};
	assign m_hi_long = {3'b001, m_hi, 1'b0};
	
	// Normalize the lower mantissa by shifting right by the difference in exponents.
	wire [27:0] m_lo_norm;
	wire [31:0] m_lo_norm_32b;	
	wire m_lo_bits;
	
	collecting_right_shift_32b _m_lz_shift ( .in({5'b0, m_lo_long}), .shift({24'b0, e_delta}), .out(m_lo_norm_32b), .collector(m_lo_bits) );
	assign m_lo_norm = m_lo_norm_32b[26:0];
		
	// Take the sum or difference between both mantissas
	// 23 bit mantissa + 1 bit leading '1' + 1 bit trailing zero (rounding) + 2 bits to allow signed 2's compliment values = 27 bits inputs (xxx.xxx... format)
	// The negative inputs are complimented, and a negative result is also complimented.
	wire [26:0] m_sum;
	wire [27:0] m_sum_compliment;
	wire m_sum_sign, m_sum_carry_out;
	
	wire [26:0] m_hi_compliment, m_hi_sum_in;
	wire [26:0] m_lo_compliment, m_lo_sum_in;
	
	// Compliment negative inputs (as determined by the sign bit of the inputs + operation)
	signed_compliment #( .BITS(27) ) _m_hi_compliment ( .in(m_hi_long), .out(m_hi_compliment) );
	signed_compliment #( .BITS(27) ) _m_lo_compliment ( .in(m_lo_norm), .out(m_lo_compliment) );
	
	assign m_hi_sum_in = s_hi ? m_hi_compliment : m_hi_long;
	assign m_lo_sum_in = s_lo ? m_lo_compliment : m_lo_norm;
	
	ripple_carry_adder #( .BITS(27) ) _mantissa_add ( .a(m_lo_sum_in), .b(m_hi_sum_in), .sum(m_sum), .c_in(1'b0), .c_out(m_sum_carry_o) );
	
	// If the sum is negative, convert it to positive
	// Use m_lo_bits as an additional fake bit at the end of the sum
	// This is required for rounding concerns with negative floats - the +1 part of the compliment needs to act on the lowest non-zero bit
	signed_compliment #( .BITS(27) ) _mantissa_compliment ( .in({m_sum, m_lo_bits}), .out(m_sum_compliment) );
	
	wire [26:0] m_sum_positive;
	
	assign m_sum_positive = m_sum[26] ? m_sum_compliment[27:1] : m_sum;
	assign m_sum_sign = m_sum[26];
	
	// Count leading zeros (is_zero flag will be set if the sum is zero, indicating the number itself is zero)
	// Exclude the upper bit of the sum, as that one is gaurenteed to be zero
	wire is_zero;
	wire [4:0] leading_zeros;
	count_leading_zeros #( .BITS(5) ) _count_zeros ( .value({m_sum_positive[25:0], 6'b0}), .count(leading_zeros), .zero(is_zero) );
	
	// Assuming the sum is not all zero, we can normalize the exponent, keeping in mind the sum has two digits before the decimal point
	wire [7:0] leading_zeros_c, e_sum;
	wire e_sum_carry, e_sum_overflow; // Exponent overflow (infinity detection)
	
	// e_sum = e_hi + 1 - leading_zeros
	// Take the signed compliment of leading_zeros, and then add it +1 with the carry in
	signed_compliment #( .BITS(8) ) _lz_comp ( .in({{3{leading_zeros[4]}}, leading_zeros}), .out(leading_zeros_c) );
	
	// todo: detect underflow properly
	ripple_carry_adder #( .BITS(8) ) _lz_add ( .a(e_hi), .b(leading_zeros_c), .sum(e_sum), .c_in(1'b1), .c_out(e_sum_carry) );
	
	// Overflow occurs under the +1 only if e_hi == 126, and leading_zeros_c == 0 (since 127 is the reserved exponent for infinity)
	assign e_sum_overflow = e_hi == 8'b11111110 && leading_zeros_c == 8'b0;
		
	// Detect overflow + underflow via the top bit of the sum
	// todo: overflow and inf/-inf as required
	
	// Shift the mantissa by 1 + leading zeros, and round according to IEEE-754 rounding rules to the nearest 23-bit mantissa.
	// Done by dropping the top two bits of the mantissa sum (implicit '01.xx'), and shifting by leading zeros
	// Additionally, use the m_lo_bits as a final bit input, to break ties
	wire [22:0] m_rounded;
	wire [31:0] m_shifted_32b;
	wire round_overflow;
	
	left_shift_32b _normalize_m ( .in({m_sum_positive[24:0], 7'b0}), .shift({{27{1'b0}}, leading_zeros}), .out(m_shifted_32b) );	
	round_to_nearest_even #( .BITS_IN(33), .BITS_OUT(23) ) _m_round ( .in({m_shifted_32b, m_lo_bits}), .out(m_rounded), .overflow(round_overflow) );
	
	// If there was a rounding overflow, the exponent needs to be incremented
	wire [7:0] e_increment;
	wire e_inc_overflow;
	
	ripple_carry_adder #( .BITS(8) ) _e_inc ( .a(e_sum), .b(8'b0), .sum(e_increment), .c_in(round_overflow), .c_out(e_inc_overflow) );
	
	// todo: handle zero results
	// todo: handle negative (infinity) overflow
	// todo: handle too-close-to-zero overflow
	
	always @(*) begin
		if (e_sum_overflow || e_inc_overflow || (& e_sum)) // Positive overflow (+inf)
			f_sum = 32'h7f800000;
		else
			// todo: handle output sign
			f_sum = {m_sum_sign, e_increment, m_rounded};
	end
	
endmodule


`timescale 1ns/100ps
module float_adder_subtractor_test;

	reg [31:0] a, b;
	reg sa, sb;
	reg [7:0] ea, eb;
	reg [22:0] ma, mb;
	reg add_sub;
	reg decomposed_in; // If the input should be mapped to {s, e, m} or the direct 32-bit input
	
	wire [31:0] a_in, b_in, sum;
	
	integer i, exponent, sign;

	assign a_in = decomposed_in ? {sa, ea, ma} : a;
	assign b_in = decomposed_in ? {sb, eb, mb} : b;
	
	float_adder_subtractor _fadd ( .fa(a_in), .fb(b_in), .fz(sum), .add_sub(add_sub) );

	initial begin
	
		// Specific Test Cases
		decomposed_in <= 1'b0;
		
		// NaN
		add_sub <= 1'b0;
		
		a <= 32'h7fc00000; b <= 32'h7fc00000; #1 $display("Test fpu + |  NaN +  NaN | %h | %h | %h", a, b, sum);
		a <= 32'h7fc00000; b <= 32'hffc00000; #1 $display("Test fpu + |  NaN + -NaN | %h | %h | %h", a, b, sum);
		a <= 32'hffc00000; b <= 32'h7fc00000; #1 $display("Test fpu + | -NaN +  NaN | %h | %h | %h", a, b, sum);
		a <= 32'hffc00000; b <= 32'hffc00000; #1 $display("Test fpu + | -NaN + -NaN | %h | %h | %h", a, b, sum);
		
		a <= 32'h7fc00000; b <= 32'h12345678; #1 $display("Test fpu + |  NaN +   ?  | %h | %h | %h", a, b, sum);
		a <= 32'hffc00000; b <= 32'h12345678; #1 $display("Test fpu + | -NaN +   ?  | %h | %h | %h", a, b, sum);
		a <= 32'h12345678; b <= 32'h7fc00000; #1 $display("Test fpu + |   ?  +  NaN | %h | %h | %h", a, b, sum);
		a <= 32'h12345678; b <= 32'hffc00000; #1 $display("Test fpu + |   ?  + -NaN | %h | %h | %h", a, b, sum);
		
		add_sub <= 1'b1;
		
		a <= 32'h7fc00000; b <= 32'h7fc00000; #1 $display("Test fpu - |  NaN -  NaN | %h | %h | %h", a, b, sum);
		a <= 32'h7fc00000; b <= 32'hffc00000; #1 $display("Test fpu - |  NaN - -NaN | %h | %h | %h", a, b, sum);
		a <= 32'hffc00000; b <= 32'h7fc00000; #1 $display("Test fpu - | -NaN -  NaN | %h | %h | %h", a, b, sum);
		a <= 32'hffc00000; b <= 32'hffc00000; #1 $display("Test fpu - | -NaN - -NaN | %h | %h | %h", a, b, sum);
		
		a <= 32'h7fc00000; b <= 32'h12345678; #1 $display("Test fpu - |  NaN -   ?  | %h | %h | %h", a, b, sum);
		a <= 32'hffc00000; b <= 32'h12345678; #1 $display("Test fpu - | -NaN -   ?  | %h | %h | %h", a, b, sum);
		a <= 32'h12345678; b <= 32'h7fc00000; #1 $display("Test fpu - |   ?  -  NaN | %h | %h | %h", a, b, sum);
		a <= 32'h12345678; b <= 32'hffc00000; #1 $display("Test fpu - |   ?  - -NaN | %h | %h | %h", a, b, sum);
		
		// Infinity
		
		add_sub <= 1'b0;
		
		a <= 32'h7f800000; b <= 32'h7f800000; #1 $display("Test fpu + |  inf +  inf | %h | %h | %h", a, b, sum);
		a <= 32'h7f800000; b <= 32'hff800000; #1 $display("Test fpu + |  inf + -inf | %h | %h | %h", a, b, sum);
		a <= 32'hff800000; b <= 32'h7f800000; #1 $display("Test fpu + | -inf +  inf | %h | %h | %h", a, b, sum);
		a <= 32'hff800000; b <= 32'hff800000; #1 $display("Test fpu + | -inf + -inf | %h | %h | %h", a, b, sum);
		
		a <= 32'h7f800000; b <= 32'h12345678; #1 $display("Test fpu + |  inf +   ?  | %h | %h | %h", a, b, sum);
		a <= 32'hff800000; b <= 32'h12345678; #1 $display("Test fpu + | -inf +   ?  | %h | %h | %h", a, b, sum);
		a <= 32'h12345678; b <= 32'h7f800000; #1 $display("Test fpu + |   ?  +  inf | %h | %h | %h", a, b, sum);
		a <= 32'h12345678; b <= 32'hff800000; #1 $display("Test fpu + |   ?  + -inf | %h | %h | %h", a, b, sum);
		
		add_sub <= 1'b1;
		
		a <= 32'h7f800000; b <= 32'h7f800000; #1 $display("Test fpu - |  inf -  inf | %h | %h | %h", a, b, sum);
		a <= 32'h7f800000; b <= 32'hff800000; #1 $display("Test fpu - |  inf - -inf | %h | %h | %h", a, b, sum);
		a <= 32'hff800000; b <= 32'h7f800000; #1 $display("Test fpu - | -inf -  inf | %h | %h | %h", a, b, sum);
		a <= 32'hff800000; b <= 32'hff800000; #1 $display("Test fpu - | -inf - -inf | %h | %h | %h", a, b, sum);
		
		a <= 32'h7f800000; b <= 32'h12345678; #1 $display("Test fpu - |  inf -   ?  | %h | %h | %h", a, b, sum);
		a <= 32'hff800000; b <= 32'h12345678; #1 $display("Test fpu - | -inf -   ?  | %h | %h | %h", a, b, sum);
		a <= 32'h12345678; b <= 32'h7f800000; #1 $display("Test fpu - |   ?  -  inf | %h | %h | %h", a, b, sum);
		a <= 32'h12345678; b <= 32'hff800000; #1 $display("Test fpu - |   ?  - -inf | %h | %h | %h", a, b, sum);
		
		add_sub <= 1'b0;
		
		// Zero (Positive and Negative)
		
		a <= 32'h00000000; b <= 32'h00000000; #1 $display("Test fpu + |  0 +  0 | %h | %h | %h", a, b, sum);
		a <= 32'h00000000; b <= 32'h80000000; #1 $display("Test fpu + |  0 + -0 | %h | %h | %h", a, b, sum);
		a <= 32'h80000000; b <= 32'h00000000; #1 $display("Test fpu + | -0 +  0 | %h | %h | %h", a, b, sum);
		a <= 32'h80000000; b <= 32'h80000000; #1 $display("Test fpu + | -0 + -0 | %h | %h | %h", a, b, sum);
		
		a <= 32'h00000000; b <= 32'h12345678; #1 $display("Test fpu + |  0 +  ? | %h | %h | %h", a, b, sum);
		a <= 32'h80000000; b <= 32'h12345678; #1 $display("Test fpu + | -0 +  ? | %h | %h | %h", a, b, sum);
		a <= 32'h12345678; b <= 32'h00000000; #1 $display("Test fpu + |  ? +  0 | %h | %h | %h", a, b, sum);
		a <= 32'h12345678; b <= 32'h80000000; #1 $display("Test fpu + |  ? + -0 | %h | %h | %h", a, b, sum);
		
		add_sub <= 1'b1;
		
		a <= 32'h00000000; b <= 32'h00000000; #1 $display("Test fpu - |  0 -  0 | %h | %h | %h", a, b, sum);
		a <= 32'h00000000; b <= 32'h80000000; #1 $display("Test fpu - |  0 - -0 | %h | %h | %h", a, b, sum);
		a <= 32'h80000000; b <= 32'h00000000; #1 $display("Test fpu - | -0 -  0 | %h | %h | %h", a, b, sum);
		a <= 32'h80000000; b <= 32'h80000000; #1 $display("Test fpu - | -0 - -0 | %h | %h | %h", a, b, sum);
		
		a <= 32'h00000000; b <= 32'h12345678; #1 $display("Test fpu - |  0 -  ? | %h | %h | %h", a, b, sum);
		a <= 32'h80000000; b <= 32'h12345678; #1 $display("Test fpu - | -0 -  ? | %h | %h | %h", a, b, sum);
		a <= 32'h12345678; b <= 32'h00000000; #1 $display("Test fpu - |  ? -  0 | %h | %h | %h", a, b, sum);
		a <= 32'h12345678; b <= 32'h80000000; #1 $display("Test fpu - |  ? - -0 | %h | %h | %h", a, b, sum);
		
		add_sub <= 1'b0;
		
		// Switch to using the decomposed input
		sa <= 1'b0; ea <= 8'b0; ma <= 23'b0;
		sb <= 1'b0; eb <= 8'b0; mb <= 32'b0;
		decomposed_in <= 1'b1;
		
		// Positive + Positive, Similar Exponents
		for (i = 0; i < 1000; i = i + 1) begin
			exponent = 1 + ($urandom % 223); // [1, 254]
			sa <= 1'b0;
			sb <= 1'b0;
			ea <= exponent;
			eb <= exponent + ($urandom % 30);
			ma <= $urandom;
			mb <= $urandom;
			#1 $display("Test fpu + | float positive + positive, similar exponents | %h | %h | %h", a_in, b_in, sum);
		end
		
		// Positive + Positive -> +Infinity Overflow
		for (i = 0; i < 1000; i = i + 1) begin
			exponent = 254;
			sa <= 1'b0;
			sb <= 1'b0;
			ea <= exponent;
			eb <= exponent;
			ma <= $urandom;
			mb <= $urandom;
			#1 $display("Test fpu + | float positive + positive, +inf overflow | %h | %h | %h", a_in, b_in, sum);
		end
		
		// Positive + Negative, Similar Exponents
		for (i = 0; i < 10; i = i + 1) begin
			exponent = 1 + ($urandom % 223); // [1, 254]
			sign = $urandom;
			sa <= sign;
			sb <= ~sign;
			ea <= exponent;
			eb <= exponent + ($urandom % 30);
			ma <= $urandom;
			mb <= $urandom;
			#1 $display("Test fpu + | float positive + negative, similar exponents | %h | %h | %h", a_in, b_in, sum);
		end
		
		//$finish;
	end
endmodule
