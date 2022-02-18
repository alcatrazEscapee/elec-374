/**
 * A Full Adder, implementing 1-bit a + b + c_in = 2 * c_out + sum
 */
module full_adder(
	input a,
	input b,
	output sum,
	input c_in,
	output c_out
);

	assign sum = a ^ b ^ c_in;
	assign c_out = (a & b) | (a & c_in) | (b & c_in);

endmodule

`timescale 1ns/100ps
module full_adder_test;

	reg a, b, c_in;
	wire sum, c_out;
	
	full_adder target ( .a(a), .b(b), .sum(sum), .c_in(c_in), .c_out(c_out) );
	
	initial begin
		// All input combinations
		a <= 0; b <= 0; c_in <= 0; #1 $display("Test | add0 | 0 -> 0 + 0 = 0 -> 0 | %d -> %d + %d = %d -> %d", c_in, a, b, sum, c_out);
		a <= 1; b <= 0; c_in <= 0; #1 $display("Test | add1 | 0 -> 1 + 0 = 1 -> 0 | %d -> %d + %d = %d -> %d", c_in, a, b, sum, c_out);
		a <= 0; b <= 1; c_in <= 0; #1 $display("Test | add2 | 0 -> 0 + 1 = 1 -> 0 | %d -> %d + %d = %d -> %d", c_in, a, b, sum, c_out);
		a <= 1; b <= 1; c_in <= 0; #1 $display("Test | add3 | 0 -> 1 + 1 = 0 -> 1 | %d -> %d + %d = %d -> %d", c_in, a, b, sum, c_out);
		a <= 0; b <= 0; c_in <= 1; #1 $display("Test | add4 | 1 -> 0 + 0 = 1 -> 0 | %d -> %d + %d = %d -> %d", c_in, a, b, sum, c_out);
		a <= 1; b <= 0; c_in <= 1; #1 $display("Test | add5 | 1 -> 1 + 0 = 0 -> 1 | %d -> %d + %d = %d -> %d", c_in, a, b, sum, c_out);
		a <= 0; b <= 1; c_in <= 1; #1 $display("Test | add6 | 1 -> 0 + 1 = 0 -> 1 | %d -> %d + %d = %d -> %d", c_in, a, b, sum, c_out);
		a <= 1; b <= 1; c_in <= 1; #1 $display("Test | add7 | 1 -> 1 + 1 = 1 -> 1 | %d -> %d + %d = %d -> %d", c_in, a, b, sum, c_out);
		
		$finish;
	end
endmodule
