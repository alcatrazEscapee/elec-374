module ripple_carry_adder_32b(
	input [31:0] a,
	input [31:0] b,
	output [31:0] sum,
	input c_in,
	output c_out
);
	// 32-bit Ripple Carry Adder (RCA)
	// The most basic adder, also the slowest, but hey!
	wire c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24, c25, c26, c27, c28, c29, c30, c31;

	full_adder a0 ( .a(a[0]), .b(b[0]), .sum(sum[0]), .c_in(c_in), .c_out(c1) );
	full_adder a1 ( .a(a[1]), .b(b[1]), .sum(sum[1]), .c_in(c1), .c_out(c2) );
	full_adder a2 ( .a(a[2]), .b(b[2]), .sum(sum[2]), .c_in(c2), .c_out(c3) );
	full_adder a3 ( .a(a[3]), .b(b[3]), .sum(sum[3]), .c_in(c3), .c_out(c4) );
	full_adder a4 ( .a(a[4]), .b(b[4]), .sum(sum[4]), .c_in(c4), .c_out(c5) );
	full_adder a5 ( .a(a[5]), .b(b[5]), .sum(sum[5]), .c_in(c5), .c_out(c6) );
	full_adder a6 ( .a(a[6]), .b(b[6]), .sum(sum[6]), .c_in(c6), .c_out(c7) );
	full_adder a7 ( .a(a[7]), .b(b[7]), .sum(sum[7]), .c_in(c7), .c_out(c8) );
	full_adder a8 ( .a(a[8]), .b(b[8]), .sum(sum[8]), .c_in(c8), .c_out(c9) );
	full_adder a9 ( .a(a[9]), .b(b[9]), .sum(sum[9]), .c_in(c9), .c_out(c10) );
	full_adder a10 ( .a(a[10]), .b(b[10]), .sum(sum[10]), .c_in(c10), .c_out(c11) );
	full_adder a11 ( .a(a[11]), .b(b[11]), .sum(sum[11]), .c_in(c11), .c_out(c12) );
	full_adder a12 ( .a(a[12]), .b(b[12]), .sum(sum[12]), .c_in(c12), .c_out(c13) );
	full_adder a13 ( .a(a[13]), .b(b[13]), .sum(sum[13]), .c_in(c13), .c_out(c14) );
	full_adder a14 ( .a(a[14]), .b(b[14]), .sum(sum[14]), .c_in(c14), .c_out(c15) );
	full_adder a15 ( .a(a[15]), .b(b[15]), .sum(sum[15]), .c_in(c15), .c_out(c16) );
	full_adder a16 ( .a(a[16]), .b(b[16]), .sum(sum[16]), .c_in(c16), .c_out(c17) );
	full_adder a17 ( .a(a[17]), .b(b[17]), .sum(sum[17]), .c_in(c17), .c_out(c18) );
	full_adder a18 ( .a(a[18]), .b(b[18]), .sum(sum[18]), .c_in(c18), .c_out(c19) );
	full_adder a19 ( .a(a[19]), .b(b[19]), .sum(sum[19]), .c_in(c19), .c_out(c20) );
	full_adder a20 ( .a(a[20]), .b(b[20]), .sum(sum[20]), .c_in(c20), .c_out(c21) );
	full_adder a21 ( .a(a[21]), .b(b[21]), .sum(sum[21]), .c_in(c21), .c_out(c22) );
	full_adder a22 ( .a(a[22]), .b(b[22]), .sum(sum[22]), .c_in(c22), .c_out(c23) );
	full_adder a23 ( .a(a[23]), .b(b[23]), .sum(sum[23]), .c_in(c23), .c_out(c24) );
	full_adder a24 ( .a(a[24]), .b(b[24]), .sum(sum[24]), .c_in(c24), .c_out(c25) );
	full_adder a25 ( .a(a[25]), .b(b[25]), .sum(sum[25]), .c_in(c25), .c_out(c26) );
	full_adder a26 ( .a(a[26]), .b(b[26]), .sum(sum[26]), .c_in(c26), .c_out(c27) );
	full_adder a27 ( .a(a[27]), .b(b[27]), .sum(sum[27]), .c_in(c27), .c_out(c28) );
	full_adder a28 ( .a(a[28]), .b(b[28]), .sum(sum[28]), .c_in(c28), .c_out(c29) );
	full_adder a29 ( .a(a[29]), .b(b[29]), .sum(sum[29]), .c_in(c29), .c_out(c30) );
	full_adder a30 ( .a(a[30]), .b(b[30]), .sum(sum[30]), .c_in(c30), .c_out(c31) );
	full_adder a31 ( .a(a[31]), .b(b[31]), .sum(sum[31]), .c_in(c31), .c_out(c_out) );


endmodule


`timescale 1ns/100ps
module ripple_carry_adder_32b_test;

	reg [31:0] a, b;
	reg c_in;
	wire [31:0] sum;
	wire c_out;
	
	integer i;
	
	ripple_carry_adder_32b target ( .a(a), .b(b), .sum(sum), .c_in(c_in), .c_out(c_out) );
	
	initial begin
		for (i = 0; i < 100; i = i + 1) begin
			a <= $random;
			b <= $random;
			c_in <= 0;
			#1 $display("Test | add %d + %d | %d | %d", a, b, a + b, sum);
		end
		
		// Test overflow
		a <= 32'hffffffff;
		b <= 32'b1;
		#1 $display("Test | add_with_overflow %d + %d | s = 0 c = 1 | s = %d c = %d ", a, b, sum, c_out);
		
		$finish;
	end
endmodule
