module float_adder_subtractor (
	input [31:0] fa,
	input [31:0] fb,
	output reg [31:0] fz,
	input add_sub // add = 0 (a + b), sub = 1 (a - b)
);
	// IEEE-754 : [1b - Sign][8b - Exponent, Excess-127][23b - Mantissa]
	
	wire [31:0] f_sum; // Sum of fa + fb, assuming neither are inf or NaN
	
	// Decompose
	wire sa, sb, sb_pre, sz;
	wire [7:0] ea, eb, ez;
	wire [22:0] ma, mb, mz;
	
	assign {sa, ea, ma} = fa;
	assign {sb_pre, eb, mb} = fb; // Invert the sign of b if this is a subtraction
	assign sb = add_sub ? ~sb_pre : sb_pre;
	assign f_sum = {sz, ez, mz};
	
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
	// We also need to do a 2's compliment signed addition/subtraction, meaning we need another bit to avoid overflow
	wire [24:0] m_lo_long, m_hi_long;
	
	assign m_lo_long = {2'b01, m_lo};
	assign m_hi_long = {2'b01, m_hi};
	
	// Normalize the lower mantissa by shifting right by the difference in exponents.
	wire [24:0] m_lo_norm;
	wire [31:0] m_lo_norm_32b;
	
	right_shift_32b _m_lz_shift ( .in({m_lo_long, 7'b0}), .shift({24'b0, e_delta}), .out(m_lo_norm_32b) );
	assign m_lo_norm = m_lo_norm_32b[31:7]; // Truncate
	
	// FOR NOW, just add two values
	// todo : handle negative values (subtraction)
	
	wire [24:0] m_sum;
	wire m_sum_c_out;
	
	assign m_sub = s_hi ^ s_lo;
	ripple_carry_adder #( .BITS(25) ) _mantissa_add ( .a(m_hi_long), .b(m_sub ? ~m_lo_norm : m_lo_norm), .sum(m_sum), .c_in(m_sub), .c_out(m_sum_c_out) );
			
	// m_sum is now a positive 25-bit mantissa (in XX.XX... format) representing the result of the calculation.
	
	// We have to implicitly shift the 25-bit mantissa down by one (due to the carry from the sum), into X.XX... form.
	// However, due to the sum any number of those digits may be zero, and we need to re-normalize.
	// Assuming the mantissa is not all zero, we need to count the number of leading zeros, to know how many places to shift the exponent
	// We need to shift 1 + leading zeros, taking into account the full 25-bit mantissa (due to the hidden leading 1.XXX)
	// So, we pass a 32-bit constant with one left-padded '0' (+1) and padded right '1's
	
	wire is_zero;
	wire [4:0] leading_zeros;
	count_leading_zeros #( .BITS(5) ) _count_zeros ( .value({1'b0, m_sum, {6{1'b1}}}), .count(leading_zeros), .zero(is_zero) );
	
	// Now we can re-normalize the exponent.
	// The sum output was m_sum * 2^{e_hi}, with m_sum = XX.XXXX...
	// We need to add +1 (because of the implicit left shift by 1 to get X.XXX...)
	// And then -leading_zeros (because of each shift done by the leading zeros)
	// Thus, e_sum := e_hi + 1 - leading_zeros
	
	wire [7:0] leading_zeros_sign_extend, leading_zeros_compliment;
	wire [8:0] e_sum;
	
	assign leading_zeros_sign_extend = {{3{leading_zeros[4]}}, leading_zeros};
	signed_compliment #( .BITS(8) ) _lz_comp ( .in(leading_zeros_sign_extend), .out(leading_zeros_compliment) );
	ripple_carry_adder #( .BITS(8) ) _lz_add ( .a(e_hi), .b(leading_zeros_compliment), .sum(e_sum[7:0]), .c_in(1'b1), .c_out(e_sum[8]) );
	
	// Detect overflow + underflow via the top bit of the sum
	// todo: overflow and inf/-inf as required
	
	// Shift the mantissa by the required amount
	// todo: right shift
	wire [23:0] m_shifted;
	wire [31:0] m_shifted_32b;
	
	right_shift_32b _normalize_m ( .in({7'b0, m_sum_norm}), .shift({{27{1'b0}}, leading_zeros}), .out(m_shifted_32b) );
	assign m_shifted = m_shifted_32b[22:0]; // Truncate
	
	// Assign to the result fields, using the is_zero flag
	assign sz = m_sum_negative;
	assign ez = e_sum[7:0];
	assign mz = m_shifted;
	
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
		
		// Cases where delta_exp = 0
		decomposed_in <= 1'b1;
		sa <= 1'b0; ea <= 8'b0; ma <= 23'b0;
		sb <= 1'b0; eb <= 8'b0; mb <= 32'b0;
		
		for (i = 0; i < 10; i = i + 1) begin
			exponent = $urandom;
			sa <= 1'b0;
			sb <= 1'b0;
			ea <= exponent;
			eb <= exponent;
			ma <= $urandom;
			mb <= $urandom;
			#1 $display("Test fpu + | float + (equal exponent) | %h | %h | %h", a_in, b_in, sum);
		end
		
		//$finish;
	end
endmodule
