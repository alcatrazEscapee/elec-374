module carry_lookahead_adder_16b(
	input [15:0] a,
	input [15:0] b,
	output [15:0] sum,
	input c_in,
	output c_out
);
	wire g0, g1, g2, g3, p0, p1, p2, p3, c0, c1, c2, c01, c02, c03;
		
	// Carry Lookahead
	assign c2 = g2 | (p2 & g1) | (p2 & p1 & g0) | (p2 & p1 & p0 & c_in);
	assign c1 = g1 | (p1 & g0) | (p1 & p0 & c_in);
	assign c0 = g0 | (p0 & c_in);
	
	// Sum + Carry
	carry_lookahead_adder_4b _cla0 ( .a(a[3:0]), .b(b[3:0]), .sum(sum[3:0]), .c_in(c_in), .c_out(c01), .p_out(p0), .g_out(g0) );
	carry_lookahead_adder_4b _cla1 ( .a(a[7:4]), .b(b[7:4]), .sum(sum[7:4]), .c_in(c0), .c_out(c02), .p_out(p1), .g_out(g1) );
	carry_lookahead_adder_4b _cla2 ( .a(a[11:8]), .b(b[11:8]), .sum(sum[11:8]), .c_in(c1), .c_out(c03), .p_out(p2), .g_out(g2) );
	carry_lookahead_adder_4b _cla3 ( .a(a[15:12]), .b(b[15:12]), .sum(sum[15:12]), .c_in(c2), .c_out(c_out), .p_out(p3), .g_out(g3) );

endmodule


`timescale 1ns/100ps
module carry_lookahead_adder_16b_test;
	
	reg [16:0] a, b;
	reg c_in;
	wire [16:0] sum;
	
	integer i;
	
	carry_lookahead_adder_16b cla ( .a(a[15:0]), .b(b[15:0]), .sum(sum[15:0]), .c_in(c_in), .c_out(sum[16]) );
	
	initial begin
		for (i = 0; i < 1000; i = i + 1) begin
			a <= $urandom % 65536;
			b <= $urandom % 65536;
			c_in <= $urandom;
			#1 $display("Test | add %0d + %0d + %0d | %0d | %0d", a, b, c_in, a + b + c_in, sum);
		end
		
		$finish;
	end
endmodule
