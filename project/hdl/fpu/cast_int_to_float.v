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
	wire round_overflow; // If the rounding overflowed into the leading bits, and the exponent needs to be bumped as a result.
	
	left_shift_32b _ls_mantissa ( .in(in_positive), .shift({27'b0, leading_zeros}), .out(shift_out) );
	
	// Exclude the top bit (implicit 1.xxx), and round to the nearest even
	round_to_nearest_even #( .BITS_IN(31), .BITS_OUT(23) ) _m_round ( .in(shift_out[30:0]), .out(mantissa), .overflow(round_overflow) );
	
	// The exponent is 31 - leading_zeros, stored in Excess-127, which means we need to compute 158 - leading_zeros
	// Note: -leading_zeros = (~leading_zeros + 1) -> 158 - leading_zeros = 159 + ~leading_zeros	
	// Include the carry in as +1, if the rounded mantissa resulted in a higher exponent (we don't need to shift the mantissa in this case, as it will only happen if the mantissa is now all zero)
	wire [7:0] exponent;
	wire exp_c_out;
	ripple_carry_adder #( .BITS(8) ) _rca_exp ( .a({8'b10011111}), .b({3'b111, ~leading_zeros}), .sum(exponent), .c_in(round_overflow), .c_out(exp_c_out) ); 
	
	// Special case if all_zero, just output the positive zero constant, otherwise output the calculated value
	assign out = is_zero ? 32'b0 : {is_negative, exponent, mantissa};

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
		is_signed <= 1'b1; #1 $display("Test fpu f | signed 0   | 00000000 | %h", out);
		
		in <= 32'hffffffff; #1 $display("Test fpu f | signed -1  | ffffffff | %h", out);
		in <= 32'h80000000; #1 $display("Test fpu f | signed min | 80000000 | %h", out);
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
		
		for (i = 0; i < 10; i = i + 1) begin
			in <= $random; #1 $display("Test fpu g | unsigned %0d | %h | %h", in, in, out);
		end
		
		$finish;
	end
endmodule

