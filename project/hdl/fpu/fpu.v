module fpu (
	// Basic Inputs / Outputs
	input [31:0] a,
	input [31:0] b,
	output reg [31:0] z,
	
	// FPU Control Signals
	input [9:0] select, // {fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf}
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

	wire fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf;
	wire illegal_cfr;
	
	assign {fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf} = select;
	assign illegal = illegal_cfr;
		
	// Inputs / Outputs
	wire [31:0] z_crf, z_cfr, z_fadd_sub, z_fmul, z_frc;
	wire [31:0] fadd_a_in, fadd_b_in, fmul_a_in, fmul_b_in;
	wire z_fgt, z_feq;
	
	// Floating Point Operations
	cast_int_to_float _crf ( .in(a), .out(z_crf), .is_signed(fpu_crf) );
	cast_float_to_int _cfr ( .in(a), .out(z_cfr), .is_signed(fpu_cfr), .illegal(illegal_cfr) );
	
	float_adder_subtractor _fadd_sub ( .fa(fadd_a_in), .fb(fadd_b_in), .fz(z_fadd_sub), .add_sub(fpu_fsub) );
	float_multiplier _fmul ( .fa(fmul_a_in), .fb(fmul_b_in), .fz(z_fmul), .alu_a(alu_a), .alu_b(alu_b), .alu_product({alu_hi, alu_lo}) );
	float_compare _fcmp ( .fa(a), .fb(b), .gt(z_fgt), .eq(z_feq) );

	float_reciprocal _frc (
		.fa(a), .fb(b), .fz(z_frc),
		.fadd_sub_out(z_fadd_sub), .fmul_out(z_fmul),
		.fadd_a_in(fadd_a_in), .fadd_b_in(fadd_b_in),
		.fmul_a_in(fmul_a_in), .fmul_b_in(fmul_b_in),
		.en(fpu_frc), .clk(clk), .clr(clr)
	);

	
	always @(*) begin
		case (select)
			10'b0000000001 : z = z_crf; // Signed Casts
			10'b0000000010 : z = z_cfr;
			10'b0000000100 : z = z_crf; // Unsigned Casts
			10'b0000001000 : z = z_cfr;
			10'b0000010000 : z = z_fadd_sub; // Arithmetic
			10'b0000100000 : z = z_fadd_sub;
			10'b0001000000 : z = z_fmul;
			10'b0010000000 : z = z_frc;
			10'b0100000000 : z = {31'b0, z_fgt}; // Compare
			10'b1000000000 : z = {31'b0, z_feq};
			default        : z = 32'b0;
		endcase
	end	
endmodule


`timescale 1ns/100ps
module fpu_test;

	// Control Signals
	reg ir_en;
	reg pc_increment, pc_in_alu, pc_in_rf_a;
	reg ma_in_pc, ma_in_alu;
	reg alu_a_in_rf, alu_a_in_pc;
	reg alu_b_in_rf, alu_b_in_constant;
	reg lo_en, hi_en;
	reg rf_in_alu, rf_in_hi, rf_in_lo, rf_in_memory, rf_in_fpu;
	reg memory_en;
		
	reg alu_not, alu_neg, alu_div, alu_mul, alu_or, alu_and, alu_rol, alu_ror, alu_shl, alu_shr, alu_sub, alu_add;
	reg fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf;
	reg fpu_mode;
	
	wire [31:0] ir_out;
	wire branch_condition;
	
	reg clk, clr;
	
	cpu _cpu (
		.ir_en(ir_en),
		.pc_increment(pc_increment), .pc_in_alu(pc_in_alu), .pc_in_rf_a(pc_in_rf_a),
		.ma_in_pc(ma_in_pc), .ma_in_alu(ma_in_alu),
		.alu_a_in_rf(alu_a_in_rf), .alu_a_in_pc(alu_a_in_pc),
		.alu_b_in_rf(alu_b_in_rf), .alu_b_in_constant(alu_b_in_constant),
		.lo_en(lo_en), .hi_en(hi_en),
		.rf_in_alu(rf_in_alu), .rf_in_hi(rf_in_hi), .rf_in_lo(rf_in_lo), .rf_in_memory(rf_in_memory), .rf_in_fpu(rf_in_fpu), .rf_in_input(1'b0),
		.input_en(1'b0), .output_en(1'b0),
		.alu_select({alu_not, alu_neg, alu_div, alu_mul, alu_or, alu_and, alu_rol, alu_ror, alu_shl, alu_shr, alu_sub, alu_add}),
		.fpu_select({fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf}),
		.fpu_mode(fpu_mode),
		.input_in(32'b0), .output_out(),
		.ir_out(ir_out), .clk(clk), .clr(clr),
		.memory_en(memory_en),
		.branch_condition(branch_condition)
	);
	
	task control_reset();
		// Clears all control signal inputs before each step
		begin
			ir_en <= 1'b0;
			pc_increment <= 1'b0; pc_in_alu <= 1'b0; pc_in_rf_a <= 1'b0;
			ma_in_pc <= 1'b0; ma_in_alu <= 1'b0;
			alu_a_in_rf <= 1'b0; alu_a_in_pc <= 1'b0;
			alu_b_in_rf <= 1'b0; alu_b_in_constant <= 1'b0;
			lo_en <= 1'b0; hi_en <= 1'b0;
			rf_in_alu <= 1'b0; rf_in_hi <= 1'b0; rf_in_lo <= 1'b0; rf_in_memory <= 1'b0; rf_in_fpu <= 1'b0;
			memory_en <= 1'b0;
			{alu_not, alu_neg, alu_div, alu_mul, alu_or, alu_and, alu_rol, alu_ror, alu_shl, alu_shr, alu_sub, alu_add} <= 12'b0;
			{fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf} <= 10'b0;
			fpu_mode <= 1'b0;
		end
	endtask
	
	/**
	 * Executes T0, T1, T2 steps (without testing)
	 */
	task next_instruction();
		begin
			control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1; // T0
			#10 control_reset(); // T1
			#10 control_reset(); ir_en <= 1'b1; // T2
			#10 control_reset();
		end
	endtask
		
	
	// Clock
	initial begin
		clk <= 1'b1;
		forever #5 clk <= ~clk;
	end

	initial begin
		// Zero all inputs
		control_reset();
		clr <= 1'b0;
		
		// Start
		#11 clr <= 1'b1;
		
		// Initialize Memory
		$display("Initializing Memory");
		$readmemh("out/fpu_testbench.mem", _cpu._memory.data);

		// Initialization
		
		// addi r1 r0 355
		
		next_instruction();
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5 $display("Test | addi r1 r0 355 @ T3 | a=0, b=355, z=355 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | addi r1 r0 355 @ End | r1=355 | r1=%0d", _cpu._rf.data[1]);
	
		// addi r2 r0 113
		
		// T0
		next_instruction();
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5 $display("Test | addi r2 r0 113 @ T3 | a=0, b=113, z=113 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | addi r2 r0 113 @ End | r2=113 | r2=%0d", _cpu._rf.data[2]);
		
		// ori r3 r0 0x4049
		
		// T0
		next_instruction();
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_or <= 1'b1;
		#5 $display("Test | ori r3 r0 0x4049 @ T3 | a=0, b=0x00004049, z=0x00004049 | a=%0d, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | ori r3 r0 0x4049 @ End | r3=0x00004049 | r3=0x%h", _cpu._rf.data[3]);
		
		// addi r4 r0 16
		
		// T0
		next_instruction();
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5 $display("Test | addi r4 r0 16 @ T3 | a=0, b=16, z=16 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | addi r4 r0 16 @ End | r4=16 | r4=%0d", _cpu._rf.data[4]);
		
		// shl r3 r3 r4
		
		// T0
		next_instruction();
		alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_shl <= 1'b1;
		#5 $display("Test | shl r3 r3 r4 @ T3 | a=0x00004049, b=16, z=0x40490000 | a=0x%h, b=%0d, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | shl r3 r3 r4 @ End | r3=0x40490000 | r3=0x%h", _cpu._rf.data[3]);
		
		// ori r3 r3 0x0fdb
		
		// T0
		next_instruction();
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_or <= 1'b1;
		#5 $display("Test | ori r3 r3 0x0fdb @ T3 | a=0x40490000, b=0x00000fdb, z=0x40490fdb | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | ori r3 r3 0x0fdb @ End | r3=0x40490fdb | r3=0x%h", _cpu._rf.data[3]);
		
		// ===============================================================
		//                     Floating Point Unit Tests
		// ===============================================================
		
		// crf f1 r1
		
		next_instruction();
		fpu_mode <= 1'b1; fpu_crf <= 1'b1; rf_in_fpu <= 1'b1;
		#5 $display("Test | crf f1 r1 @ T3 | a=0x00000163, z=0x43b18000 | a=0x%h, z=0x%h", _cpu._fpu.a, _cpu._fpu.z);
		#5 $display("Test | crf f1 r1 @ End | f1=0x43b18000 | f1=0x%h", _cpu._rf.data[1]);
		
		// curf f2 r2
		
		next_instruction();
		fpu_mode <= 1'b1; fpu_curf <= 1'b1; rf_in_fpu <= 1'b1;
		#5 $display("Test | curf f2 r2 @ T3 | a=0x00000071, z=0x42e20000 | a=0x%h, z=0x%h", _cpu._fpu.a, _cpu._fpu.z);
		#5 $display("Test | curf f2 r2 @ End | f2=0x42e20000 | f2=0x%h", _cpu._rf.data[2]);
		
		// fadd f4 f1 f3
		
		next_instruction();
		fpu_mode <= 1'b1; fpu_fadd <= 1'b1; rf_in_fpu <= 1'b1;
		#5 $display("Test | fadd f4 f1 f3 @ T3 | a=0x43b18000, b=0x40490fdb, z=0x43b31220 | a=0x%h, b=0x%h, z=0x%h", _cpu._fpu.a, _cpu._fpu.b, _cpu._fpu.z);
		#5 $display("Test | fadd f4 f1 f3 @ End | f4=0x43b31220 | f4=0x%h", _cpu._rf.data[4]);
	
		// frc f5 f2
	
		next_instruction();
		fpu_mode <= 1'b1; fpu_frc <= 1'b1; alu_mul <= 1'b1; rf_in_fpu <= 1'b1;
		#80; // +8 Cycles
		$display("Test | frc f5 f2 @ End | f5=0x3c10fa16 | f5=0x%h", _cpu._rf.data[5]);
		
		// fmul f5 f5 f1
		
		next_instruction();
		fpu_mode <= 1'b1; fpu_fmul <= 1'b1; alu_mul <= 1'b1; rf_in_fpu <= 1'b1;
		#5 $display("Test | fmul f5 f5 f1 @ T3 | a=0x3c10fa16, b=0x43b18000, z=0x40490acd | a=0x%h, b=0x%h, z=0x%h", _cpu._fpu.a, _cpu._fpu.b, _cpu._fpu.z);
		#5 $display("Test | fmul f5 f5 f1 @ End | f5=0x40490acd | f5=0x%h", _cpu._rf.data[5]);
		
		// fsub f6 f3 f5
		
		next_instruction();
		fpu_mode <= 1'b1; fpu_fsub <= 1'b1; rf_in_fpu <= 1'b1;
		#5 $display("Test | fsub f6 f3 f5 @ T3 | a=0x40490fdb, b=0x40490acd, z=0x39a1c000 | a=0x%h, b=0x%h, z=0x%h", _cpu._fpu.a, _cpu._fpu.b, _cpu._fpu.z);
		#5 $display("Test | fsub f6 f3 f5 @ End | f6=0x39a1c000 | f6=0x%h", _cpu._rf.data[6]);
		
		// feq r1 f3 f5
		
		next_instruction();
		fpu_mode <= 1'b1; fpu_feq <= 1'b1; rf_in_fpu <= 1'b1;
		#5 $display("Test | feq r1 f3 f5 @ T3 | a=0x40490fdb, b=0x40490acd, z=0 | a=0x%h, b=0x%h, z=%0b", _cpu._fpu.a, _cpu._fpu.b, _cpu._alu.z);
		#5 $display("Test | feq r1 f3 f5 @ End | r1=0 | r1=%0b", _cpu._rf.data[1]);
		
		// fgt r2 f6 f0
		
		next_instruction();
		fpu_mode <= 1'b1; fpu_fgt <= 1'b1; rf_in_fpu <= 1'b1;
		#5 $display("Test | fgt r2 f5 f0 @ T3 | a=0x39a1c000, b=0x00000000, z=0 | a=0x%h, b=0x%h, z=%0b", _cpu._fpu.a, _cpu._fpu.b, _cpu._alu.z);
		#5 $display("Test | fgt r2 f5 f0 @ End | r2=1 | r2=%0b", _cpu._rf.data[2]);
		
		// cfr r1 f6
		
		next_instruction();
		fpu_mode <= 1'b1; fpu_cfr <= 1'b1; rf_in_fpu <= 1'b1;
		#5 $display("Test | cfr r1 f6 @ T3 | a=0x39a1c000 | a=0x%h", _cpu._fpu.a);
		#5 $display("Test | cfr r1 f6 @ End | r1=0 | r1=%0b", _cpu._rf.data[1]);
		
		// cufr r1 f6
		
		next_instruction();
		fpu_mode <= 1'b1; fpu_cufr <= 1'b1; rf_in_fpu <= 1'b1;
		#5 $display("Test | cufr r1 f6 @ T3 | a=0x39a1c000 | a=0x%h", _cpu._fpu.a);
		#5 $display("Test | cufr r1 f6 @ End | r1=0 | r1=%0b", _cpu._rf.data[1]);
	
		$finish;
	end
endmodule
