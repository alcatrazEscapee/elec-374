module carry_lookahead_adder_4b(
	input [3:0] a,
	input [3:0] b,
	output [3:0] sum,
	input c_in,
	output c_out
);
	wire g0, g1, g2, g3, p0, p1, p2, p3, c0, c1, c2, c3;
	
	assign {g3, g2, g1, g0} = a & b; // gi = ai & bi
	assign {p3, p2, p1, p0} = a | b; // pi = ai | bi
	
	// Carry Lookahead
	assign c3 = g3 | (p3 & g2) | (p3 & p2 & g1) | (p3 & p2 & p1 & g0) | (p3 & p2 & p1 & p0 & c_in);
	assign c2 = g2 | (p2 & g1) | (p2 & p1 & g0) | (p2 & p1 & p0 & c_in);
	assign c1 = g1 | (p1 & g0) | (p1 & p2 & c_in);
	assign c0 = g0 | (p0 & c_in);
	
	// Sum + Carry
	assign sum = a ^ b ^ {c2, c1, c0, c_in};
	assign c_out = c3;

endmodule


`timescale 1ns/100ps
module carry_lookahead_adder_4b_test;
	
	reg [3:0] a, b;
	reg c_in;
	wire [4:0] sum;
	
	integer i, j;
	
	carry_lookahead_adder_4b cla ( .a(a), .b(b), .sum(sum[3:0]), .c_in(c_in), .c_out(sum[4]) );
	
	initial begin
		c_in <= 0;
		for (i = 0; i < 16; i = i + 1) begin
			for (j = 0; j < 16; j = j + 1) begin
				a <= i;
				b <= j;
				#1 $display("Test | add %0d + %0d | %0d | %0d", i, j, i + j, sum);
			end
		end
	end
endmodule
