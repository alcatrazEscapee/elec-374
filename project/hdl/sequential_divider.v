/**
 * A N-bit sequential signed divider, which uses an internal register and clock signal.
 * Implements non-restoring division after N cycles.
 * Computes, for a given a, m: a = m * q + r
 */
module sequential_divider #(
	parameter BITS = 32
) (
	input [BITS - 1:0] a,
	input [BITS - 1:0] m,
	output [BITS - 1:0] q,
	output [BITS - 1:0] r,
	
	output divide_by_zero,
	
	input start,
	input clk,
	input clr
);
	// Exceptions
	assign divide_by_zero = m == 0;

	// Internal non-restoring division implementation is N-1 bits, as we carry the sign bit outside the calculation
	localparam DIV_BITS = BITS - 1;
	
	// Convert input to 2's compliment, leaving in the range [0, 10...0]
	// The below non-restoring algorithim below is N-1 bits, which correctly handles N-1 bits, *and* a divisor of 10...0 (N bits)
	// However, it has two special cases that don't quite work: An N-bit divisor of exactly 10...0, and 10...0 / 1.
	wire [BITS - 1:0] a_compliment, m_compliment, q_compliment, r_compliment;
	wire [DIV_BITS - 1:0] a_unsigned, m_unsigned, q_unsigned, r_unsigned;
	
	wire a_sign, m_sign, q_sign, r_sign;
	
	assign a_sign = a[BITS - 1];
	assign m_sign = m[BITS - 1];
	
	signed_compliment #( .BITS(BITS) ) _ac ( .in(a), .out(a_compliment) );
	signed_compliment #( .BITS(BITS) ) _mc ( .in(m), .out(m_compliment) );
	
	assign a_unsigned = a_sign ? a_compliment[DIV_BITS - 1:0] : a[DIV_BITS - 1:0];
	assign m_unsigned = m_sign ? m_compliment[DIV_BITS - 1:0] : m[DIV_BITS - 1:0];
	
	// Assign the outputs to the correct sign adjusted value, based on the inputs' signs
	assign q_sign = a_sign ^ m_sign;
	assign r_sign = a_sign;
	
	// Handle special cases - these allow us to use a N-1 bit unsigned divider rather than an N-bit one
	// Interestingly enough, the 'sign bit', from a computer science perspective, is strictly less than one bit, from an information theory perspective.
	reg  [BITS - 1:0] q_adjusted, r_adjusted;
	always @(*) begin
		q_adjusted = q_unsigned;
		r_adjusted = r_unsigned;
		
		if (m_unsigned == 1) begin // Divisor = 1
			q_adjusted = {a_sign ? a_compliment[DIV_BITS] : a[DIV_BITS], a_unsigned};
			r_adjusted = {BITS{1'b0}};
		end
		else if (m_sign ? m_compliment[DIV_BITS] : m[DIV_BITS]) begin // Divisor = 10...0
			q_adjusted = a == m;
			r_adjusted = a == m ? {BITS{1'b0}} : {1'b0, a_unsigned};
		end
	end
	
	signed_compliment #( .BITS(BITS) ) _qc ( .in(q_adjusted), .out(q_compliment) );
	signed_compliment #( .BITS(BITS) ) _rc ( .in(r_adjusted), .out(r_compliment) );
	
	assign q = q_sign ? q_compliment : q_adjusted;
	assign r = r_sign ? r_compliment : r_adjusted;

	// Begin Non-Restoring Division
	// Using N-1 bits (DIV_BITS), signs have been handled

	wire [DIV_BITS:0] a_in, a_out, a_shifted, m_extended, ma_sum;
	wire [DIV_BITS - 1:0] q_out, q_in, q_shifted, mar_sum;
	wire a_positive, ma_negative, a_negative, q0;
	
	register #( .BITS(DIV_BITS + 1) ) _ra ( .q(a_in), .d(a_out), .en(1'b1), .clk(clk), .clr(clr) );
	register #( .BITS(DIV_BITS) )     _rq ( .q(q_in), .d(q_out), .en(1'b1), .clk(clk), .clr(clr) );
	
	// Step 1 (Division)
	// Shift A and Q left one binary position
	assign {a_shifted, q_shifted} = {a_out[DIV_BITS - 1:0], q_unsigned, q0};
	
	// If A is >= 0, subtract M from A, otherwise add M to A
	assign a_positive = ~a_out[DIV_BITS];
	assign m_extended = {1'b0, m_unsigned};
	
	ripple_carry_adder #( .BITS(DIV_BITS + 1) ) _ma_add ( .a(a_shifted), .b(a_positive ? ~m_extended : m_extended), .sum(ma_sum), .c_in(a_positive), .c_out() );
	
	// Set q0 = 1 if A > 0, else 0
	assign ma_negative = ma_sum[DIV_BITS];
	assign q0 = ma_negative ? 1'b0 : 1'b1;
	
	assign a_in = start ? {{(DIV_BITS){1'b0}}, a_sign & a_compliment[DIV_BITS]} : ma_sum;
	assign q_in = start ? a_unsigned : q_shifted;
	
	// Step 2: If A < 0, add M to A
	assign a_negative = a_out[DIV_BITS];
	
	ripple_carry_adder # ( .BITS(DIV_BITS) ) _rem_add ( .a(a_out[DIV_BITS - 1:0]), .b(m_unsigned), .sum(mar_sum), .c_in(1'b0), .c_out() );
	
	// Outputs
	assign q_unsigned = q_out;
	assign r_unsigned = a_negative ? mar_sum : a_out[DIV_BITS - 1:0];

endmodule


`timescale 100ps/10ps
module sequential_divider_test;

	reg signed [4:0] a, b;
	wire signed [4:0] q, r;
	wire divide_by_zero;
	
	reg start, clk, clr;
	
	integer i, j;
	
	sequential_divider #( .BITS(5) ) _div ( .a(a), .m(b), .q(q), .r(r), .start(start), .divide_by_zero(divide_by_zero), .clk(clk), .clr(clr) );
	
	task divide(input signed [4:0] num, input signed [4:0] div);
		begin
			a <= num;
			b <= div;
			start <= 1'b1;
			#10;
			start <= 1'b0;
			#40;
		end
	endtask
	
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
		
		// Test all cases (except div/0)
		for (i = 0; i < 32; i = i + 1) begin
			for (j = 1; j < 32; j = j + 1) begin
				divide(i, j);
				$display("Test | divide %0d / %0d | q=%0d, r=%0d | q=%0d, r=%0d", a, b, a / b, a % b, q, r);
			end
		end
		
		// Test div/0
		
		for (i = 0; i < 32; i = i + 1) begin
			divide(i, 0);
			$display("Test | divide error %0d / 0 | e=1 | e=%b", i, divide_by_zero);
		end
		
		$finish;
	end
endmodule
