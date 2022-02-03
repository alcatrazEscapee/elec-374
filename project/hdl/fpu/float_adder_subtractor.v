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
			// If the signs are different, it outputs NaN
			// The sign of the NaN is negative if the LHS sign bit != the RHS sign (after including the operation)
			64'h7f800000_7f800000 : fz = sa == sb ? fa : (fa[31] != sb ? 32'hffc00000 : 32'h7fc00000);
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
	
	// Both mantissas are nonzero, and thus have an implicit leading '1'.
	wire [23:0] m_lo_long, m_hi_long;
	
	assign m_lo_long = {1'b1, m_lo};
	assign m_hi_long = {1'b1, m_hi};
	
	// Normalize the lower mantissa by shifting right by the difference in exponents.
	wire [23:0] m_lo_norm;
	wire [31:0] m_lo_norm_32b;
	
	right_shift_32b _m_lz_shift ( .in({m_lo_long, 8'b0}), .shift({24'b0, e_delta}), .out(m_lo_norm_32b) );
	assign m_lo_norm = m_lo_norm_32b[31:8]; // Truncate unused bits
	
	// todo : handle negative values (subtraction)
	
	// Sum both mantissas, to a 25-bit sum in XX.XXXX... format
	wire [24:0] m_sum;
	
	assign m_sub = s_hi ^ s_lo;
	ripple_carry_adder #( .BITS(24) ) _mantissa_add ( .a(m_hi_long), .b(m_lo_norm), .sum(m_sum[23:0]), .c_in(1'b0), .c_out(m_sum[24]) );
		
	// Count leading zeros (is_zero flag will be set if the sum is zero, indicating the number itself is zero)
	wire is_zero;
	wire [4:0] leading_zeros;
	count_leading_zeros #( .BITS(5) ) _count_zeros ( .value({m_sum, 7'b0}), .count(leading_zeros), .zero(is_zero) );
	
	// Assuming the sum is not all zero, we can normalize the exponent, keeping in mind the sum has two digits before the decimal point
	wire [7:0] leading_zeros_c, e_sum;
	wire e_sum_carry; // Exponent overflow (infinity detection)
	
	// e_sum = e_hi + 1 - leading_zeros
	// Take the signed compliment of leading_zeros, and then add it +1 with the carry in
	signed_compliment #( .BITS(8) ) _lz_comp ( .in({{3{leading_zeros[4]}}, leading_zeros}), .out(leading_zeros_c) );
	ripple_carry_adder #( .BITS(8) ) _lz_add ( .a(e_hi), .b(leading_zeros_c), .sum(e_sum), .c_in(1'b1), .c_out(e_sum_carry) );
	
	// Detect overflow + underflow via the top bit of the sum
	// todo: overflow and inf/-inf as required
	
	// Shift the mantissa by 1 + leading zeros.
	// Done by dropping the top bit of the mantissa sum, and shifting by leading zeros (which shifts away the leading '1')
	wire [22:0] m_rounded;
	wire [31:0] m_shifted_32b;
	
	left_shift_32b _normalize_m ( .in({m_sum[23:0], 8'b0}), .shift({{27{1'b0}}, leading_zeros}), .out(m_shifted_32b) );
	
	wire round_overflow;
	
	round_to_nearest_even #( .BITS_IN(32), .BITS_OUT(23) ) _m_round ( .in(m_shifted_32b), .out(m_rounded), .overflow(round_overflow) );
	
	// Assign to the result fields, using the is_zero flag
	// todo: handle zero results
	// todo: handle negative (infinity) overflow
	// todo: handle too-close-to-zero overflow
	
	always @(*) begin
		if (e_sum_carry || round_overflow || (& e_sum)) // Positive overflow (+inf)
			f_sum = 32'h7f800000;
		else
			// todo: handle output sign
			f_sum = {1'b0, e_sum, m_rounded};
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
	
	integer i, exponent;

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
		
		decomposed_in <= 1'b1;
		sa <= 1'b0; ea <= 8'b0; ma <= 23'b0;
		sb <= 1'b0; eb <= 8'b0; mb <= 32'b0;
		
		for (i = 0; i < 1000; i = i + 1) begin
			exponent = 1 + ($urandom % 254); // [1, 254]
			sa <= 1'b0;
			sb <= 1'b0;
			ea <= exponent;
			eb <= exponent;
			ma <= $urandom;
			mb <= $urandom;
			#1 $display("Test fpu + | float + (equal exponent, positive + positive) | %h | %h | %h", a_in, b_in, sum);
		end
		
		$finish;
	end
endmodule
