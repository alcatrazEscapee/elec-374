/**
 * A simple a > b check, which works with unsigned and Excess-N formats
 */
module greater_than_unsigned #(
	parameter BITS = 32
) (
	input [BITS - 1:0] a,
	input [BITS - 1:0] b,
	output reg gt
);
	// If a > b, the first bit position where a and b differ, will be a 1 in a
	// Otherwise, if there is no such bit position, then a == b
	wire [BITS - 1:0] differences = a ^ b;
		
	integer i;
	always @(*) begin
		gt = 1'b0; // Default value
		
		// Priority encoder
		// The result value will be the highest i s.t. differences[i] != 0
		// At such i, a > b is equivilant to having a[i] == 1
		for (i = 0; i < BITS; i = i + 1)
			if (differences[i])
				gt = a[i];
	end

endmodule

`timescale 1ns/100ps
module greater_than_unsigned_test;

	reg [4:0] a, b;
	wire gt;
	
	greater_than_unsigned #( .BITS(5) ) _gt ( .a(a), .b(b), .gt(gt) );
	
	integer i, j;
	initial begin
		for (i = 0; i < 32; i = i + 1) begin
			for (j = 0; j < 32; j = j + 1) begin
				a <= i;
				b <= j;
				#1 $display("Test | greater than %0d > %0d | %b | %b", a, b, a > b, gt);
			end
		end
		
		$finish;
	end
endmodule
