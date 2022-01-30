module cast_int_to_float(
	input [31:0] in,
	output [31:0] out,
	input is_signed // 0 = unsigned, 1 = signed 2's compliment
);
	// If signed and negative, sign extend to 33b, and take the two's compliment
	wire [31:0] in_compliment, in_positive;
	wire is_negative = in[31] & is_signed; // Sign bit + 2's compliment
	
	signed_compliment #( .BITS(32) ) _in_compliment ( .in({in}), .out(in_compliment) );
	
	assign in_positive = is_negative ? in_compliment : in;
	
	// Input: n
	// 0b0...01?....?
	// Count leading zeros to determine the exponent
	wire [4:0] leading_zeros; // 5-bit count = max 31
	wire is_zero;
	
	// This counts the leading 32 bits, and sets a flag if they are zero
	count_leading_zeros #( .BITS(5) ) _clz ( .value(in_positive), .count(leading_zeros), .zero(is_zero) );

	// Left shift the leading zeros away
	wire [31:0] shift_out;
	wire [22:0] mantissa;
	wire round_up;
	
	left_shift_32b _ls_mantissa ( .in(in_positive), .shift({27'b0, leading_zeros}), .out(shift_out) );
	assign mantissa = shift_out[30:8]; // Top 23 bits of the shifted result, excluding the topmost bit (implicit 1.xxx)
	
	// Rounding is complicated
	// IEEE-754 rounds to nearest, but also rounds ties to even
	// A tie occurs when the lower bits of shift_out are exactly 1000...0
	// Rounding then needs to happen only if the lowest bit of the mantissa is 1 (aka, the truncated integer is odd)
	assign round_up = shift_out[7] & (
		(| shift_out[6:0]) | // Any lower bits are non-zero (this would break the tie)
		mantissa[0]); // Or the lowest bit of the mantissa is 1

	wire [22:0] mantissa_plus_one, rounded_mantissa;
	wire round_exponent_up;
	
	ripple_carry_adder #( .BITS(23) ) _rca_mround ( .a(mantissa), .b(23'b0), .sum(mantissa_plus_one), .c_in(1'b1), .c_out(round_exponent_up) );
	assign rounded_mantissa = round_up ? mantissa_plus_one : mantissa;
	
	// The exponent is 31 - leading_zeros, stored in Excess-127, which means we need to compute 158 - leading_zeros
	// Note: -leading_zeros = (~leading_zeros + 1) -> 158 - leading_zeros = 159 + ~leading_zeros	
	// Include the carry in as +1, if the rounded mantissa resulted in a higher exponent (we don't need to shift the mantissa in this case, as it will only happen if the mantissa is now all zero)
	wire [7:0] exponent;
	wire exp_c_out;
	ripple_carry_adder #( .BITS(8) ) _rca_exp ( .a({8'b10011111}), .b({3'b111, ~leading_zeros}), .sum(exponent), .c_in(round_exponent_up), .c_out(exp_c_out) ); 
	
	// Special case if all_zero, just output the positive zero constant, otherwise output the calculated value
	assign out = is_zero ? 32'b0 : {is_negative, exponent, rounded_mantissa};

endmodule


`timescale 1ns/100ps
module cast_int_to_float_test;

	reg [31:0] in;
	reg is_signed;
	wire [31:0] out;
	
	integer i;
	
	cast_int_to_float _itof ( .in(in), .out(out), .is_signed(is_signed) );
	
	initial begin
		
		// Regression Tests
		in <= 32'hC07BA280; is_signed <= 1'b0;
		#1 $display("Test fpu g | unsigned %0d | %h | %h", in, in, out);
		
		// Special Cases
		in <= 32'b0;
		
		is_signed <= 1'b0; #1 $display("Test fpu f | unsigned 0 | 00000000 | %h", out);
		is_signed <= 1'b1; #1 $display("Test fpu f | signed 0 | 00000000 | %h", out);
		
		in <= 32'hffffffff; #1 $display("Test fpu f | signed min | ffffffff | %h", out);
		in <= 32'h7fffffff; #1 $display("Test fpu f | signed max | 7fffffff | %h", out);
		
		// Generic + Random Tests
		for (i = 0; i < 1000; i = i + 1) begin
			in <= i; #1 $display("Test fpu f | signed %0d | %h | %h", i, i, out);
		end
		
		for (i = 0; i < 1000; i = i + 1) begin
			in <= $random; #1 $display("Test fpu f | signed %0d | %h | %h", in, in, out);
		end
		
		is_signed <= 1'b0;
		
		for (i = 0; i < 1000; i = i + 1) begin
			in <= i; #1 $display("Test fpu g | unsigned %0d | %h | %h", i, i, out);
		end
		
		for (i = 0; i < 1000; i = i + 1) begin
			in <= $random; #1 $display("Test fpu g | unsigned %0d | %h | %h", in, in, out);
		end
		
		$finish;
	end
endmodule

