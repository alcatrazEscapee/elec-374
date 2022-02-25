/**
 * frc (Float Reciprocal)
 * 
 * Uses an approximate algorithim based on the following paper:
 * An Effective Floating-Point Reciprocal, Leonid Moroz; Volodymyr Samotyy; Oleh Horyachyy et. al.
 * https://ieeexplore.ieee.org/document/8525803
 * 
 * In order to acomplish this, this exerts fairly heavy control over the FPU, in particular using the add and multiply functions.
 * 
 * // C
 * // fmaf(a, b, c) = a * b + c
 * float reciprocal_2_f (float x) {
 * 	int i = *(int*)&x;
 * 	i = 0x7eb53567 - i;
 * 	float y = *(float*)&i;
 * 	y = 1.9395974f * y * fmaf(-x, y, 1.436142f);
 * 	float r = fmaf(y, -x, 1.0f);
 * 	y = fmaf(y, r, y);
 * 	return y;
 * }
 * 
 * // RTN
 * 
 * 0 | X   <= IN; Y <- 0x7eb53567 - IN;
 * 1 | T1  <= -X * Y
 * 2 | T0  <= 1.9395974f * Y; T1 <- T1 + 1.436142f
 * 3 | Y   <= T0 * T1
 * 4 | T1  <= -X * Y
 * 5 | R   <= T1 + 1.0f
 * 6 | T0  <= Y * R
 * 7 | Out <= T0 + Y
 */
module float_reciprocal (
	input [31:0] fa,
	input [31:0] fb,
	output [31:0] fz,
	
	// Interface with FPU Adder + Multiplier
	input [31:0] fadd_sub_out,
	input [31:0] fmul_out,
	
	output reg [31:0] fadd_a_in,
	output reg [31:0] fadd_b_in,
	output reg [31:0] fmul_a_in,
	output reg [31:0] fmul_b_in,
	
	input en,
	input clk,
	input clr
);
	// Internal control signals and wires
	reg x_en, y_en, r_en, t0_en, t1_en;
	
	reg [31:0] x_in, y_in, r_in, t0_in, t1_in;
	wire [31:0] x_out, y_out, r_out, t0_out, t1_out, y_const_out, x_negative_out;
	
	// Internal Registers
	
	register _x  ( .d(x_in),  .q(x_out),  .en(x_en),  .clk(clk), .clr(clr) );
	register _y  ( .d(y_in),  .q(y_out),  .en(y_en),  .clk(clk), .clr(clr) );
	register _r  ( .d(r_in),  .q(r_out),  .en(r_en),  .clk(clk), .clr(clr) );
	register _t0 ( .d(t0_in), .q(t0_out), .en(t0_en), .clk(clk), .clr(clr) );
	register _t1 ( .d(t1_in), .q(t1_out), .en(t1_en), .clk(clk), .clr(clr) );
	
	// Local step counter - counts 8 cycles and then nicely wraps around to zero
	wire [2:0] counter_out, counter_inc;
	
	ripple_carry_adder #( .BITS(3) ) _counter_inc ( .a(counter_out), .b(3'b1), .sum(counter_inc), .c_in(1'b0), .c_out() );
	register #( .BITS(3) ) _counter ( .d(counter_inc), .q(counter_out), .en(en), .clk(clk), .clr(clr) );
	
	// Float Reciprocal
	ripple_carry_adder #( .BITS(32) ) _y_const_subtract ( .a(32'h7eb53567), .b(~fa), .sum(y_const_out), .c_in(1'b1), .c_out() );
	
	assign x_negative_out = {~x_out[31], x_out[30:0]};
	assign fz = fadd_sub_out;

	// Control Logic
	always @(*) begin
		// Default values
		x_en = 1'b0;
		y_en = 1'b0;
		r_en = 1'b0;
		t0_en = 1'b0;
		t1_en = 1'b0;
		
		x_in = 32'b0;
		y_in = 32'b0;
		r_in = 32'b0;
		t0_in = 32'b0;
		t1_in = 32'b0;
		
		fadd_a_in = fa;
		fadd_b_in = fb;
		
		fmul_a_in = fa;
		fmul_b_in = fb;
		
		case (counter_out)
			4'h0 :
				begin
					x_en = 1'b1;
					x_in = fa;
					
					y_en = 1'b1;
					y_in = y_const_out;
				end
			4'h1 :
				begin
					t1_en = 1'b1;
					t1_in = fmul_out;
					fmul_a_in = x_negative_out;
					fmul_b_in = y_out;
				end
			4'h2 :
				begin
					t0_en = 1'b1;
					t0_in = fmul_out;
					fmul_a_in = 32'h3ff844ba; // 1.9395974f
					fmul_b_in = y_out;
					
					t1_en = 1'b1;
					t1_in = fadd_sub_out;
					fadd_a_in = t1_out;
					fadd_b_in = 32'h3fb7d380; // 1.436142f
				end
			4'h3 :
				begin
					y_en = 1'b1;
					y_in = fmul_out;
					fmul_a_in = t0_out;
					fmul_b_in = t1_out;
				end
			4'h4 :
				begin
					t1_en = 1'b1;
					t1_in = fmul_out;
					fmul_a_in = x_negative_out;
					fmul_b_in = y_out;
				end
			4'h5 :
				begin
					r_en = 1'b1;
					r_in = fadd_sub_out;
					fadd_a_in = t1_out;
					fadd_b_in = 32'h3f800000; // 1.0f
				end
			4'h6 :
				begin
					t0_en = 1'b1;
					t0_in = fmul_out;
					fmul_a_in = y_out;
					fmul_b_in = r_in;
				end
			4'h7 :
				begin
					// Final output is written in this step
					fadd_a_in = y_out;
					fadd_b_in = t0_out;
				end
		endcase
	end
endmodule


`timescale 10ps/1ps
module float_reciprocal_test;

	reg [31:0] fa;
	wire [31:0] fz;

	reg en, clk, clr;
	
	reg sa;
	reg [7:0] ea;
	reg [22:0] ma;
		
	integer i, exponent, sign, mantissa;
	
	// External interface, required to properly test
	wire [31:0] fadd_a_in, fadd_b_in, fmul_a_in, fmul_b_in, fadd_sub_out, fmul_out;
	wire [63:0] alu_a, alu_b;
	wire [63:0] alu_out;

	float_reciprocal _frc (
		.fa(fa), .fb(32'b0), .fz(fz),
		.fadd_sub_out(fadd_sub_out), .fmul_out(fmul_out),
		.fadd_a_in(fadd_a_in), .fadd_b_in(fadd_b_in),
		.fmul_a_in(fmul_a_in), .fmul_b_in(fmul_b_in),
		.en(en), .clk(clk), .clr(clr)
	);
	
	// Mock FPU Interface
	float_adder_subtractor _fadd_sub ( .fa(fadd_a_in), .fb(fadd_b_in), .fz(fadd_sub_out), .add_sub(1'b0) );
	float_multiplier _fmul ( .fa(fmul_a_in), .fb(fmul_b_in), .fz(fmul_out), .alu_a(alu_a[31:0]), .alu_b(alu_b[31:0]), .alu_product(alu_out) );

	// Mock ALU Interface
	assign alu_a[63:32] = 32'b0;
	assign alu_b[63:32] = 32'b0;
	assign alu_out = alu_a * alu_b;
	
	// Clock
	initial begin
		clk <= 1'b1;
		forever #2 clk = ~clk;
	end
	
	initial begin
		fa <= 32'b0;
		clr <= 1'b0;
		en <= 1'b0;
		#1
		clr <= 1'b1;
		#3
		en <= 1'b1;
		
		for (i = 0; i < 1000; i = i + 1) begin
			sa = $urandom;
			ea = 100 + ($urandom % 50);
			ma = $urandom;
			fa <= {sa, ea, ma};
			#32 $display("Test fpu r | fpu frc | %h | %h", fa, fz); // 8 clock cycles = 32 ticks
		end
		
		$finish;
	end
	
endmodule
