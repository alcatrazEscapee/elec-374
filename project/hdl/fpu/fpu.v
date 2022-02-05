module fpu (
	// RF Inputs
	input [31:0] ra,
	input [31:0] rb,
	// FF Inputs
	input [31:0] fa,
	input [31:0] fb,
	// Generic Output
	output reg [31:0] z,
	
	// Control Signals
	input [11:0] select, // {fpu_feq, fpu_fgt, fpu_fdiv, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf, fpu_mvfr, fpu_mvrf}
	output illegal,

	// ALU Interface (for mul/div)
	output [31:0] alu_a,
	output [31:0] alu_b,
	input [31:0] alu_hi,
	input [31:0] alu_lo
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
	// 9 = fdiv = Float Divide

	wire fpu_feq, fpu_fgt, fpu_fdiv, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf, fpu_mvfr, fpu_mvrf;
	wire illegal_cfr;
	
	assign {fpu_feq, fpu_fgt, fpu_fdiv, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf, fpu_mvfr, fpu_mvrf} = select;
	assign illegal = illegal_cfr;
	
	// Outputs
	wire [31:0] z_crf, z_cfr, z_fadd_sub, z_fmul, z_fdiv;
	wire z_fgt, z_feq;
	
	// FPU Operations
	
	cast_int_to_float _crf ( .in(ra), .out(z_crf), .is_signed(fpu_crf) );
	cast_float_to_int _cfr ( .in(fa), .out(z_cfr), .is_signed(fpu_cfr), .illegal(illegal_cfr) );
		
	float_adder_subtractor _fadd_sub ( .fa(fa), .fb(fb), .fz(z_fadd_sub), .add_sub(fpu_fsub) );
	
	// todo: multiply / divide
	
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
			12'b001000000000 : z = z_fdiv;
			12'b010000000000 : z = {31'b0, z_fgt}; // Compare
			12'b100000000000 : z = {31'b0, z_feq};
			default          : z = 32'b0;
		endcase
	end
endmodule


`timescale 1ns/100ps
module fpu_test;

	reg [31:0] ra, rb, fa, fb;
	reg [11:0] select;

	wire [31:0] z;

	wire [63:0] alu_a, alu_b;
	reg [63:0] alu_out;
	
	fpu _fpu (
		.ra(ra), .rb(rb),
		.fa(fa), .fb(fb),
		.z(z),
		.select(select),
		.alu_a(alu_a[31:0]), .alu_b(alu_b[31:0]),
		.alu_hi(alu_out[63:32]), .alu_lo(alu_out[31:0])
	);

	initial begin
		ra <= 32'b0; rb <= 32'b0; fa <= 32'b0; fb <= 32'b0;
		select <= 12'b0;
		
		// Move
		select <= 12'b000000000001; ra <= 32'h12345678;
		#1 $display("Test | fpu mvrf | z=0x12345678 | z=0x%h", z);
		
		select <= 12'b000000000010; ra <= 32'b0; fa <= 32'h87654321;
		#1 $display("Test | fpu mvfr | z=0x87654321 | z=0x%h", z);
		
		// Cast (Signed)
		select <= 12'b000000000100; ra <= 32'h00112233;
		#1 $display("Test fpu f | fpu crf | %h | %h", ra, z);
		
		select <= 12'b000000001000; fa <= 32'h12345678;
		#1 $display("Test fpu i | fpu cfr | %h | %h | %b", ra, z, _fpu.illegal_cfr);
		
		// Cast (Unsigned)
		select <= 12'b000000010000; ra <= 32'h33221100;
		#1 $display("Test fpu g | fpu curf | %h | %h", ra, z);
		
		select <= 12'b000000100000; ra <= 32'h12345678;
		#1 $display("Test fpu j | fpu cufr | %h | %h | %b", ra, z, _fpu.illegal_cfr);
				
		// Arithmetic
		
		select <= 12'b000001000000; fa <= 32'h12345678; fb <= 32'h87654321;
		#1 $display("Test fpu + | fpu fadd | %h | %h | %h", fa, fb, z);
		
		select <= 12'b000010000000;
		#1 $display("Test fpu - | fpu fsub | %h | %h | %h", fa, fb, z);
		
		// Compare
		
		select <= 12'b010000000000;
		#1 $display("Test fpu > | fpu fgt | %h | %h | %b", fa, fb, z);
		
		select <= 12'b100000000000;
		#1 $display("Test fpu = | fpu feq | %h | %h | %b", fa, fb, z);
	
		$finish;
	end
endmodule
