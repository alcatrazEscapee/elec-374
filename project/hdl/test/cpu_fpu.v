/**
 * Testbench for the CPU for all FPU instruction
 */
`timescale 1ns/100ps
module cpu_fpu_test;

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
	reg fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf, fpu_mvfr, fpu_mvrf;
	reg fpu_mode;
	
	wire [31:0] ir_out;
	wire branch_condition;
	
	reg clk, clr;
	
	cpu _dp (
		.ir_en(ir_en),
		.pc_increment(pc_increment), .pc_in_alu(pc_in_alu), .pc_in_rf_a(pc_in_rf_a),
		.ma_in_pc(ma_in_pc), .ma_in_alu(ma_in_alu),
		.alu_a_in_rf(alu_a_in_rf), .alu_a_in_pc(alu_a_in_pc),
		.alu_b_in_rf(alu_b_in_rf), .alu_b_in_constant(alu_b_in_constant),
		.lo_en(lo_en), .hi_en(hi_en),
		.rf_in_alu(rf_in_alu), .rf_in_hi(rf_in_hi), .rf_in_lo(rf_in_lo), .rf_in_memory(rf_in_memory), .rf_in_fpu(rf_in_fpu),
		.alu_select({alu_not, alu_neg, alu_div, alu_mul, alu_or, alu_and, alu_rol, alu_ror, alu_shl, alu_shr, alu_sub, alu_add}),
		.fpu_select({fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf, fpu_mvfr, fpu_mvrf}),
		.fpu_mode(fpu_mode),
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
			{fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf, fpu_mvfr, fpu_mvrf} <= 12'b0;
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
		$readmemh("out/fpu_testbench.mem", _dp._memory.data);

		// Initialization
		
		// addi r1 r0 355
		
		next_instruction();
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5 $display("Test | addi r1 r0 355 @ T3 | a=0, b=355, z=355 | a=%0d, b=%0d, z=%0d", _dp._alu.a, _dp._alu.b, _dp._alu.z);
		#5 $display("Test | addi r1 r0 355 @ End | r1=355 | r1=%0d", _dp._rf.data[1]);
	
		// addi r2 r0 113
		
		// T0
		next_instruction();
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5 $display("Test | addi r2 r0 113 @ T3 | a=0, b=113, z=113 | a=%0d, b=%0d, z=%0d", _dp._alu.a, _dp._alu.b, _dp._alu.z);
		#5 $display("Test | addi r2 r0 113 @ End | r2=113 | r2=%0d", _dp._rf.data[2]);
		
		// ori r3 r0 0x4049
		
		// T0
		next_instruction();
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_or <= 1'b1;
		#5 $display("Test | ori r3 r0 0x4049 @ T3 | a=0, b=0x00004049, z=0x00004049 | a=%0d, b=0x%h, z=0x%h", _dp._alu.a, _dp._alu.b, _dp._alu.z);
		#5 $display("Test | ori r3 r0 0x4049 @ End | r3=0x00004049 | r3=0x%h", _dp._rf.data[3]);
		
		// addi r4 r0 16
		
		// T0
		next_instruction();
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5 $display("Test | addi r4 r0 16 @ T3 | a=0, b=16, z=16 | a=%0d, b=%0d, z=%0d", _dp._alu.a, _dp._alu.b, _dp._alu.z);
		#5 $display("Test | addi r4 r0 16 @ End | r4=16 | r4=%0d", _dp._rf.data[4]);
		
		// shl r3 r3 r4
		
		// T0
		next_instruction();
		alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_shl <= 1'b1;
		#5 $display("Test | shl r3 r3 r4 @ T3 | a=0x00004049, b=16, z=0x40490000 | a=0x%h, b=%0d, z=0x%h", _dp._alu.a, _dp._alu.b, _dp._alu.z);
		#5 $display("Test | shl r3 r3 r4 @ End | r3=0x40490000 | r3=0x%h", _dp._rf.data[3]);
		
		// ori r3 r3 0x0fdb
		
		// T0
		next_instruction();
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_or <= 1'b1;
		#5 $display("Test | ori r3 r3 0x0fdb @ T3 | a=0x40490000, b=0x00000fdb, z=0x40490fdb | a=0x%h, b=0x%h, z=0x%h", _dp._alu.a, _dp._alu.b, _dp._alu.z);
		#5 $display("Test | ori r3 r3 0x0fdb @ End | r3=0x40490fdb | r3=0x%h", _dp._rf.data[3]);
		
		// ===============================================================
		//                     Floating Point Unit Tests
		// ===============================================================
		
		// crf f1 r1
		
		next_instruction();
		fpu_mode <= 1'b1; fpu_crf <= 1'b1;
		#5 $display("Test | crf f1 r1 @ T3 | a=0x00000163, z=0x43b18000 | a=0x%h, z=0x%h", _dp._fpu.ra, _dp._fpu.rz);
		#5 $display("Test | crf f1 r1 @ End | f3=0x43b18000 | f3=0x%h", _dp._fpu._ff.data[1]);
		
		// curf f2 r2
		
		next_instruction();
		fpu_mode <= 1'b1; fpu_curf <= 1'b1;
		#5 $display("Test | curf f2 r2 @ T3 | a=0x00000071, z=0x42e20000 | a=0x%h, z=0x%h", _dp._fpu.ra, _dp._fpu.rz);
		#5 $display("Test | curf f2 r2 @ End | f3=0x42e20000 | f3=0x%h", _dp._fpu._ff.data[2]);
		
		// mvrf f3 r3
		
		next_instruction();
		fpu_mode <= 1'b1; fpu_mvrf <= 1'b1;
		#5 $display("Test | curf f2 r2 @ T3 | a=0x40490fdb, z=0x40490fdb | a=0x%h, z=0x%h", _dp._fpu.ra, _dp._fpu.rz);
		#5 $display("Test | curf f2 r2 @ End | f3=0x40490fdb | f3=0x%h", _dp._fpu._ff.data[3]);
				
		// fadd f4 f1 f3 // 355 + pi
		
		next_instruction();
		fpu_mode <= 1'b1; fpu_fadd <= 1'b1;
		#5 $display("Test | fadd f4 f1 f3 @ T3 | a=0x43b18000, b=0x40490fdb, z=0x43b31220 | a=0x%h, b=0x%h, z=0x%h", _dp._fpu.fa, _dp._fpu.fb, _dp._fpu.rz);
		#5 $display("Test | fadd f4 f1 f3 @ End | f4=0x43b31220 | f4=0x%h", _dp._fpu._ff.data[4]);
	
		$finish;
	end
endmodule
