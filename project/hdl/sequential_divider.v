/**
 * A N-bit sequential divider, which uses an internal register and clock signal.
 * Implements non-restoring division.
 */
module sequential_divider #(
	parameter BITS = 32
) (
	input [BITS - 1:0] a,
	input [BITS - 1:0] m,
	output [BITS - 1:0] q,
	output [BITS - 1:0] r,
	
	input start,
	input clk,
	input clr
);

	wire [BITS :0] a_in, a_out, a_shifted, m_extended, ma_sum;
	wire [BITS - 1:0] q_in, q_shifted;
	wire a_positive, a_negative, q0;
	
	register #( .BITS(BITS + 1) ) _ra ( .q(a_in), .d(a_out), .en(1'b1), .clk(clk), .clr(clr) );
	register #( .BITS(BITS) )     _rq ( .q(q_in), .d(q),     .en(1'b1), .clk(clk), .clr(clr) );
	
	// Step 1 (Division)
	// Shift A and Q left one binary position
	assign {a_shifted, q_shifted} = {a_out[BITS - 1:0], q, q0};
	
	// If A is > 0, subtract M from A, otherwise add M to A
	assign a_positive = ~a_shifted[BITS] && (| a_shifted);
	assign m_extended = {m[BITS - 1], m};
	
	ripple_carry_adder #( .BITS(BITS + 1) ) _ma_add ( .a(a_shifted), .b(a_positive ? ~m_extended : m_extended), .sum(ma_sum), .c_in(a_positive), .c_out() );
	
	// Set q0 = 1 if A >= 0, else 0
	assign a_negative = ma_sum[BITS];
	assign q0 = a_negative ? 1'b0 : 1'b1;
	
	assign a_in = start ? {(BITS + 1){1'b0}} : ma_sum;
	assign q_in = start ? a : q_shifted;
	
	// Step 2: If A < 0, add M to A
	assign a_final_negative = ma_sum[BITS];
	
	ripple_carry_adder # ( .BITS(BITS) ) _rem_add ( .a(ma_sum[BITS - 1:0]), .b(m), .sum(r), .c_in(1'b0), .c_out() );

endmodule


`timescale 1ns/100ps
module sequential_divider_test;

	reg [3:0] a, b;
	wire [3:0] q, r;
	
	reg start, clk, clr;
	
	integer i;
	
	sequential_divider #( .BITS(4) ) _div ( .a(a), .m(b), .q(q), .r(r), .start(start), .clk(clk), .clr(clr) );
	
	// Clock
	initial begin
		clr <= 1'b0;
		start <= 1'b0;
		clk <= 1'b1;
		forever #5 clk = ~clk;
	end
	
	initial begin
		#1 clr <= 1'b1;
		#10;
		
		a <= 8;
		b <= 3;
		start <= 1'b1;
		#10
		start <= 1'b0;
		#40
		$display("Test | divide %0d / %0d | %0d, %0d | %0d, %0d", a, b, a / b, a % b, q, r);
		
		//$finish;
	end
endmodule
