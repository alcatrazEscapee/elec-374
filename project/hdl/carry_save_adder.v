/**
 * carry_save_adder: n-bit carry-save adder.
 * Parameter `BITS` specifies width; defaults to 32.
 * Computes `sum` = `a` + `b` + `c`.
 * (n-bit) carry-in `c`, (n-bit) carry-out `carry`.
 * Implemented with n full_adder modules.
 */
module carry_save_adder #(
	parameter BITS = 32
) (
	input [BITS - 1:0] a,
	input [BITS - 1:0] b,
	input [BITS - 1:0] c,
	output [BITS - 1:0] sum,
	output [BITS - 1:0] carry
);

	genvar i;
	generate
		for (i = 0; i < BITS; i = i + 1) begin : gen_fa
			full_adder fa ( .a(a[i]), .b(b[i]), .sum(sum[i]), .c_in(c[i]), .c_out(carry[i]) );
		end
	endgenerate

endmodule


`timescale 1ns/100ps
module carry_save_adder_test;
	
	// 4-Bit RCA : Small enough to test all possible inputs exhaustively (16 * 16 * 16 = 4096 inputs)
	reg [4:0] a, b, c;
	wire [6:0] sum, carry; 
	
	carry_save_adder #( .BITS(5) ) csa ( .a(a), .b(b), .c(c), .sum(sum[4:0]), .carry(carry[4:0]) );
	
	assign sum[6:5] = 2'b0;
	assign carry[6:5] = 2'b0;

	integer i, j, k;
	
	initial begin
		for (i = 0; i < 16; i = i + 1) begin
			for (j = 0; j < 16; j = j + 1) begin
				for (k = 0; k < 16; k = k + 1) begin
					a <= i;
					b <= j;
					c <= k;
					#1 $display("Test | add %0d + %0d + %0d | %0d | %0d", a, b, c, i + j + k, (carry << 1) + sum);
				end
			end
		end
		
		$finish;
	end
endmodule
