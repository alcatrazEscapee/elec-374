module fpu (	
	// CPU Control Signals
	input [3:0] rf_a_addr,
	input [3:0] rf_b_addr,
	input [3:0] rf_z_addr,
	
	// RF Interface
	input [31:0] ra, // To FPU
	output [31:0] rz, // To RF
	
	// FPU Control Signals
	input [11:0] select, // {fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf, fpu_mvfr, fpu_mvrf}
	output illegal,

	// ALU Interface (for integer multiplication)
	output [31:0] alu_a,
	output [31:0] alu_b,
	input [31:0] alu_hi,
	input [31:0] alu_lo,
	
	// Clock
	input clk,
	input clr
);
	// FPU Operations
	// 0 = mvrf = Move from Register to Float
	// 1 = mvfr = Move from Float to Register
	// 2 = crf  = Cast Register to Float
	// 3 = cfr  = Cast Float to Register
	// 4 = curf = Cast (Unsigned) Register to Float
	// 5 = cufr = Cast Float to (Unsigned) Register
	// 6 = fadd = Float Add
	// 7 = fsub = Float Subtract
	// 8 = fmul = Float Multiply
	// 9 = frc  = Float Reciprocal (Clocked, 8 cycles)
	// A = fgt  = Float Greater Than
	// B = feq  = Float Equals

	wire fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf, fpu_mvfr, fpu_mvrf;
	wire illegal_cfr;
	
	assign {fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf, fpu_mvfr, fpu_mvrf} = select;
	assign illegal = illegal_cfr;
	
	wire [31:0] fa, fb;
	reg [31:0] z;

	// FPU Register File (FF)
	wire fpu_rf_en;
	reg frc_write;
	
	assign fpu_rf_en = frc_write | fpu_frc | fpu_fmul | fpu_fsub | fpu_fadd | fpu_curf | fpu_crf | fpu_mvrf;
	assign rz = z;
	
	// FPU Register File
	register_file #( .WORDS(16), .BITS(32) ) _ff (
		.data_in(z),
		.addr_in(fpu_rf_en ? rf_z_addr : 4'b0),
		.addr_a(rf_a_addr),
		.addr_b(rf_b_addr),
		.data_a(fa),
		.data_b(fb),
		.clk(clk),
		.clr(clr)
	);
	
	// Internal control signals and wires
	reg x_en, y_en, r_en, t0_en, t1_en;
	
	reg [31:0] x_in, y_in, r_in, t0_in, t1_in, fmul_a_in, fmul_b_in, fadd_a_in, fadd_b_in;
	wire [31:0] x_out, y_out, r_out, t0_out, t1_out, y_const_out, x_negative_out;
	
	// Outputs
	wire [31:0] z_crf, z_cfr, z_fadd_sub, z_fmul, z_frc;
	wire z_fgt, z_feq;
	
	// Native Floating Point Operations
	cast_int_to_float _crf ( .in(ra), .out(z_crf), .is_signed(fpu_crf) );
	cast_float_to_int _cfr ( .in(fa), .out(z_cfr), .is_signed(fpu_cfr), .illegal(illegal_cfr) );
	
	float_adder_subtractor _fadd_sub ( .fa(fadd_a_in), .fb(fadd_b_in), .fz(z_fadd_sub), .add_sub(fpu_fsub) );
	float_multiplier _fmul ( .fa(fmul_a_in), .fb(fmul_b_in), .fz(z_fmul), .alu_a(alu_a), .alu_b(alu_b), .alu_product({alu_hi, alu_lo}) );
	
	float_compare _fc ( .fa(fa), .fb(fb), .gt(z_fgt), .eq(z_feq) );
	
	always @(*) begin
		case (select)
			12'b000000000001 : z = ra; // Move
			12'b000000000010 : z = fa;
			12'b000000000100 : z = z_crf; // Signed Casts
			12'b000000001000 : z = z_cfr;
			12'b000000010000 : z = z_crf; // Unsigned Casts
			12'b000000100000 : z = z_cfr;
			12'b000001000000 : z = z_fadd_sub; // Arithmetic
			12'b000010000000 : z = z_fadd_sub;
			12'b000100000000 : z = z_fmul;
			12'b001000000000 : z = z_frc;
			12'b010000000000 : z = {31'b0, z_fgt}; // Compare
			12'b100000000000 : z = {31'b0, z_feq};
			default          : z = 32'b0;
		endcase
	end
	
	/*
	
	Implement frc (Float Reciprocal)
	
	Uses an approximate algorithim based on the following paper:
	An Effective Floating-Point Reciprocal, Leonid Moroz; Volodymyr Samotyy; Oleh Horyachyy et. al.
	https://ieeexplore.ieee.org/document/8525803
	
	// C
	// fmaf(a, b, c) = a * b + c
	float reciprocal_2_f (float x) {
		int i = *(int*)&x;
		i = 0x7eb53567 - i;
		float y = *(float*)&i;
		y = 1.9395974f * y * fmaf(-x, y, 1.436142f);
		float r = fmaf(y, -x, 1.0f);
		y = fmaf(y, r, y);
		return y;
	}
	
	// RTN
	
	0 | X   <= IN; Y <- 0x7eb53567 - IN;
	1 | T1  <= -X * Y
	2 | T0  <= 1.9395974f * Y; T1 <- T1 + 1.436142f
	3 | Y   <= T0 * T1
	4 | T1  <= -X * Y
	5 | R   <= T1 + 1.0f
	6 | T0  <= Y * R
	7 | Out <= T0 + Y
	*/
	
	// Internal Registers
	
	register _x  ( .q(x_in),  .d(x_out),  .en(x_en),  .clk(clk), .clr(clr) );
	register _y  ( .q(y_in),  .d(y_out),  .en(y_en),  .clk(clk), .clr(clr) );
	register _r  ( .q(r_in),  .d(r_out),  .en(r_en),  .clk(clk), .clr(clr) );
	register _t0 ( .q(t0_in), .d(t0_out), .en(t0_en), .clk(clk), .clr(clr) );
	register _t1 ( .q(t1_in), .d(t1_out), .en(t1_en), .clk(clk), .clr(clr) );
	
	// Local step counter - counts 8 cycles and then nicely wraps around to zero
	wire [2:0] counter_out, counter_inc;
	
	ripple_carry_adder #( .BITS(3) ) _counter_inc ( .a(counter_out), .b(3'b1), .sum(counter_inc), .c_in(1'b0), .c_out() );
	register #( .BITS(3) ) _counter ( .q(counter_inc), .d(counter_out), .en(fpu_frc), .clk(clk), .clr(clr) );
	
	// Float Reciprocal
	ripple_carry_adder #( .BITS(32) ) _y_const_subtract ( .a(32'h7eb53567), .b(~fa), .sum(y_const_out), .c_in(1'b1), .c_out() );
	
	assign x_negative_out = {~x_out[31], x_out[30:0]};
	assign z_frc = y_out;
	
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
		
		frc_write = 1'b0;
	
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
					t1_in = z_fmul;
					fmul_a_in = x_negative_out;
					fmul_b_in = y_out;
				end
			4'h2 :
				begin
					t0_en = 1'b1;
					t0_in = z_fmul;
					fmul_a_in = 32'h3ff844ba; // 1.9395974f
					fmul_b_in = y_out;
					
					t1_en = 1'b1;
					t1_in = z_fadd_sub;
					fadd_a_in = t1_out;
					fadd_b_in = 32'h3fb7d380; // 1.436142f
				end
			4'h3 :
				begin
					y_en = 1'b1;
					y_in = z_fmul;
					fmul_a_in = t0_out;
					fmul_b_in = t1_out;
				end
			4'h4 :
				begin
					t1_en = 1'b1;
					t1_in = z_fmul;
					fmul_a_in = x_negative_out;
					fmul_b_in = y_out;
				end
			4'h5 :
				begin
					r_en = 1'b1;
					r_in = z_fadd_sub;
					fadd_a_in = t1_out;
					fadd_b_in = 32'h3f800000; // 1.0f
				end
			4'h6 :
				begin
					t0_en = 1'b1;
					t0_in = z_fmul;
					fmul_a_in = y_out;
					fmul_b_in = r_in;
				end
			4'h7 :
				begin
					// Output
					frc_write = 1'b1;
				end
		endcase
	end
	
endmodule


`timescale 1ns/100ps
module fpu_test;

	reg [31:0] ra, rb, fa, fb;
	reg [11:0] select;
	wire illegal;

	wire [31:0] z;

	wire [63:0] alu_a, alu_b;
	wire [63:0] alu_out;
	
	reg clk, clr;
	
	reg sa, sb;
	reg [7:0] ea, eb;
	reg [22:0] ma, mb;
	reg decomposed_in; // If the input should be mapped to {s, e, m} or the direct 32-bit input
	
	wire [31:0] a_in, b_in, result;
	
	integer i, exponent, sign, mantissa;

	assign a_in = decomposed_in ? {sa, ea, ma} : fa;
	assign b_in = decomposed_in ? {sb, eb, mb} : fb;
	
	fpu _fpu (
		.ra(ra), .rb(rb),
		.fa(a_in), .fb(b_in),
		.z(z),
		.select(select),
		.illegal(illegal),
		.alu_a(alu_a[31:0]), .alu_b(alu_b[31:0]),
		.alu_hi(alu_out[63:32]), .alu_lo(alu_out[31:0]),
		.clk(clk), .clr(clr)
	);
	
	// Mock ALU Interface
	assign alu_a[63:32] = 32'b0;
	assign alu_b[63:32] = 32'b0;
	assign alu_out = alu_a * alu_b;
	
	// Clock
	initial begin
		clr <= 1'b0;
		clk <= 1'b0;
		forever #1 clk = ~clk;
	end

	initial begin
		ra <= 32'b0; rb <= 32'b0; fa <= 32'b0; fb <= 32'b0;
		select <= 12'b0;
		decomposed_in <= 1'b0;
		
		#2
		clr <= 1'b1;
		
		// Move
		select <= 12'b000000000001; ra <= 32'h12345678;
		#2 $display("Test | fpu mvrf | z=0x12345678 | z=0x%h", z);
		
		select <= 12'b000000000010; ra <= 32'b0; fa <= 32'h87654321;
		#2 $display("Test | fpu mvfr | z=0x87654321 | z=0x%h", z);
		
		// Cast (Signed)
		select <= 12'b000000000100; ra <= 32'h00112233;
		#2 $display("Test fpu f | fpu crf | %h | %h", ra, z);
		
		select <= 12'b000000001000; fa <= 32'h12345678;
		#2 $display("Test fpu i | fpu cfr | %h | %h | %b", ra, z, _fpu.illegal_cfr);
		
		// Cast (Unsigned)
		select <= 12'b000000010000; ra <= 32'h33221100;
		#2 $display("Test fpu g | fpu curf | %h | %h", ra, z);
		
		select <= 12'b000000100000; ra <= 32'h12345678;
		#2 $display("Test fpu j | fpu cufr | %h | %h | %b", ra, z, _fpu.illegal_cfr);
				
		// Arithmetic
		
		select <= 12'b000001000000; fa <= 32'h12345678; fb <= 32'h87654321;
		#2 $display("Test fpu + | fpu fadd | %h | %h | %h", fa, fb, z);
		
		select <= 12'b000010000000;
		#2 $display("Test fpu - | fpu fsub | %h | %h | %h", fa, fb, z);
		
		select <= 12'b000100000000;
		#2 $display("Test fpu * | fpu fmul | %h | %h | %h", fa, fb, z);
		
		// Compare
		
		select <= 12'b010000000000;
		#2 $display("Test fpu > | fpu fgt | %h | %h | %0b", fa, fb, z);
		
		select <= 12'b100000000000;
		#2 $display("Test fpu = | fpu feq | %h | %h | %0b", fa, fb, z);
		
		// Complex / Approximate Operations (frc)
		
		select <= 12'b001000000000;
		decomposed_in <= 1'b1;
		
		for (i = 0; i < 400; i = i + 1) begin
			sa <= $urandom;
			ea <= 100 + ($urandom % 50);
			ma <= $urandom;
			#16 $display("Test fpu r | fpu frc | %h | %h", a_in, z);
		end
		
		$finish;
	end
endmodule
