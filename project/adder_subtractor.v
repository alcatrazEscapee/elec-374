module adder_subtractor(
	input [31:0] a,
	input [31:0] b,
	output [31:0] sum,
	input sub, // 0 = Add, 1 = Subtract
	output c_out // Carry out (overflow detection)
);
	wire [31:0] b_in;
	assign b_in = b ^ {32{sub}};

	// Inner adder used by the adder/subtractor is a RCA
	ripple_carry_adder #( .BITS(32) ) rca ( .a(a), .b(b_in), .sum(sum), .c_in(sub), .c_out(c_out) );

endmodule


`timescale 1ns/100ps
module adder_subtractor_test;

	reg [31:0] a, b;
	reg c_in, sub;
	wire [31:0] sum;
	wire c_out;
	
	integer i;
	
	adder_subtractor target ( .a(a), .b(b), .sum(sum), .sub(sub), .c_out(c_out) );
	
	initial begin
		// Addition
		sub <= 1'b0;
		for (i = 0; i < 100; i = i + 1) begin
			a <= $random;
			b <= $random;
			#1 $display("Test | add %d + %d | %d | %d", a, b, a + b, sum);
		end
		
		// Subtraction
		sub <= 1'b1;
		for (i = 0; i < 100; i = i + 1) begin
			a <= $random;
			b <= $random;
			#1 $display("Test | sub %d - %d | %d | %d", a, b, a - b, sum);
		end
		
		$finish;
	end
endmodule