/**
 * Counterpart of the ALU for all floating point operations
 * Selection between operations is done with the select signal, which is 1-hot encoded
 * Exposes a small interface to the ALU, as floating point multiplication uses the ALU multiplier internally.
 */
module fpu (
	// Basic Inputs / Outputs
	input [31:0] a,
	input [31:0] b,
	output reg [31:0] z,
	
	// FPU Control Signals
	input [9:0] select, // {fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf}

	// Exceptions
	output cast_out_of_bounds,
	output cast_undefined,

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
	// 0 = crf  = Cast Register to Float
	// 1 = cfr  = Cast Float to Register
	// 2 = curf = Cast (Unsigned) Register to Float
	// 3 = cufr = Cast Float to (Unsigned) Register
	// 4 = fadd = Float Add
	// 5 = fsub = Float Subtract
	// 6 = fmul = Float Multiply
	// 7 = frc  = Float Reciprocal (Clocked, 8 cycles)
	// 8 = fgt  = Float Greater Than
	// 9 = feq  = Float Equals

	wire fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf;
	assign {fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf} = select;

	// Inputs / Outputs
	wire [31:0] z_crf, z_cfr, z_fadd_sub, z_fmul, z_frc;
	wire [31:0] fadd_a_in, fadd_b_in, fmul_a_in, fmul_b_in;
	wire z_fgt, z_feq;
	
	// Floating Point Operations
	cast_int_to_float _crf ( .in(a), .out(z_crf), .is_signed(fpu_crf) );
	cast_float_to_int _cfr ( .in(a), .out(z_cfr), .is_signed(fpu_cfr), .cast_undefined(cast_undefined), .cast_out_of_bounds(cast_out_of_bounds) );
	
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
	
	reg clk, clr;
	
	cpu _cpu (
		.input_in(32'b0),
		.output_out(),
		.clk(clk),
		.clr(clr),
		.halt(1'b0)
	);
	
	// todo: remove
	task control_reset();
		begin end
	endtask
	
	/**
	 * Executes T0, T1, T2 steps
	 */
	task next_instruction(input [31:0] pc, input [127:0] assembly, input [31:0] instruction);
		begin
			#10 $display("Test | %0s @ T0 | pc=%0d, ma=%0d | pc=%0d, ma=%0d", assembly, pc + 1, pc, _cpu._pc.q, _cpu._ma.q); // T0
			#10 $display("Test | %0s @ T1 | md=0x%h | md=0x%h", assembly, instruction, _cpu._memory.data_out); // T1
			#10 $display("Test | %0s @ T2 | ir=0x%h | ir=0x%h", assembly, instruction, _cpu._ir.q); // T2
		end
	endtask
		
	
	// Clock
	initial begin
		clk <= 1'b1;
		forever #5 clk <= ~clk;
	end

	initial begin
		clr <= 1'b0;
		#11 clr <= 1'b1;
		
		// Initialize Memory
		$display("Initializing Memory");
		$readmemh("out/fpu_testbench.mem", _cpu._memory.data);

		// Initialization
				
		next_instruction(0, "addi r1 r0 355", 32'h58800163);
		#5 $display("Test | addi r1 r0 355 @ T3 | a=0, b=355, z=355 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | addi r1 r0 355 @ End | r1=355 | r1=%0d", _cpu._rf.data[1]);
	
		next_instruction(1, "addi r2 r0 113", 32'h59000071);
		#5 $display("Test | addi r2 r0 113 @ T3 | a=0, b=113, z=113 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | addi r2 r0 113 @ End | r2=113 | r2=%0d", _cpu._rf.data[2]);
				
		next_instruction(2, "ori r3 r0 0x4049", 32'h69804049);
		#5 $display("Test | ori r3 r0 0x4049 @ T3 | a=0, b=0x00004049, z=0x00004049 | a=%0d, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | ori r3 r0 0x4049 @ End | r3=0x00004049 | r3=0x%h", _cpu._rf.data[3]);
		
		next_instruction(3, "addi r4 r0 16", 32'h5a000010);
		#5 $display("Test | addi r4 r0 16 @ T3 | a=0, b=16, z=16 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | addi r4 r0 16 @ End | r4=16 | r4=%0d", _cpu._rf.data[4]);
		
		next_instruction(4, "shl r3 r3 r4", 32'h319a0000);
		#5 $display("Test | shl r3 r3 r4 @ T3 | a=0x00004049, b=16, z=0x40490000 | a=0x%h, b=%0d, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | shl r3 r3 r4 @ End | r3=0x40490000 | r3=0x%h", _cpu._rf.data[3]);
		
		next_instruction(5, "ori r3 r3 0x0fdb", 32'h69980fdb);
		#5 $display("Test | ori r3 r3 0x0fdb @ T3 | a=0x40490000, b=0x00000fdb, z=0x40490fdb | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | ori r3 r3 0x0fdb @ End | r3=0x40490fdb | r3=0x%h", _cpu._rf.data[3]);
		
		// ===============================================================
		//                     Floating Point Unit Tests
		// ===============================================================
				
		next_instruction(6, "crf f1 r1", 32'hd8880000);
		#5 $display("Test | crf f1 r1 @ T3 | a=0x00000163, z=0x43b18000 | a=0x%h, z=0x%h", _cpu._fpu.a, _cpu._fpu.z);
		#5 $display("Test | crf f1 r1 @ End | f1=0x43b18000 | f1=0x%h", _cpu._rf.data[1]);
				
		next_instruction(7, "curf f2 r2", 32'hd9100002);
		#5 $display("Test | curf f2 r2 @ T3 | a=0x00000071, z=0x42e20000 | a=0x%h, z=0x%h", _cpu._fpu.a, _cpu._fpu.z);
		#5 $display("Test | curf f2 r2 @ End | f2=0x42e20000 | f2=0x%h", _cpu._rf.data[2]);
				
		next_instruction(8, "fadd f4 f1 f3", 32'hda098004);
		#5 $display("Test | fadd f4 f1 f3 @ T3 | a=0x43b18000, b=0x40490fdb, z=0x43b31220 | a=0x%h, b=0x%h, z=0x%h", _cpu._fpu.a, _cpu._fpu.b, _cpu._fpu.z);
		#5 $display("Test | fadd f4 f1 f3 @ End | f4=0x43b31220 | f4=0x%h", _cpu._rf.data[4]);
		
		next_instruction(9, "frc f5 f2", 32'hda900007);
		#80; // +8 Cycles
		$display("Test | frc f5 f2 @ End | f5=0x3c10fa16 | f5=0x%h", _cpu._rf.data[5]);
				
		next_instruction(10, "fmul f5 f5 f1", 32'hdaa88006);
		#5 $display("Test | fmul f5 f5 f1 @ T3 | a=0x3c10fa16, b=0x43b18000, z=0x40490acd | a=0x%h, b=0x%h, z=0x%h", _cpu._fpu.a, _cpu._fpu.b, _cpu._fpu.z);
		#5 $display("Test | fmul f5 f5 f1 @ End | f5=0x40490acd | f5=0x%h", _cpu._rf.data[5]);
				
		next_instruction(11, "fsub f6 f3 f5", 32'hdb1a8005);
		#5 $display("Test | fsub f6 f3 f5 @ T3 | a=0x40490fdb, b=0x40490acd, z=0x39a1c000 | a=0x%h, b=0x%h, z=0x%h", _cpu._fpu.a, _cpu._fpu.b, _cpu._fpu.z);
		#5 $display("Test | fsub f6 f3 f5 @ End | f6=0x39a1c000 | f6=0x%h", _cpu._rf.data[6]);
		
		next_instruction(12, "feq r1 f3 f5", 32'hd89a8009);
		#5 $display("Test | feq r1 f3 f5 @ T3 | a=0x40490fdb, b=0x40490acd, z=0 | a=0x%h, b=0x%h, z=%0b", _cpu._fpu.a, _cpu._fpu.b, _cpu._alu.z);
		#5 $display("Test | feq r1 f3 f5 @ End | r1=0 | r1=%0b", _cpu._rf.data[1]);
				
		next_instruction(13, "fgt r2 f6 f0", 32'hd9300008);
		#5 $display("Test | fgt r2 f5 f0 @ T3 | a=0x39a1c000, b=0x00000000, z=0 | a=0x%h, b=0x%h, z=%0b", _cpu._fpu.a, _cpu._fpu.b, _cpu._alu.z);
		#5 $display("Test | fgt r2 f5 f0 @ End | r2=1 | r2=%0b", _cpu._rf.data[2]);
				
		next_instruction(14, "cfr r1 f6", 32'hd8b00001);
		#5 $display("Test | cfr r1 f6 @ T3 | a=0x39a1c000 | a=0x%h", _cpu._fpu.a);
		#5 $display("Test | cfr r1 f6 @ End | r1=0 | r1=%0b", _cpu._rf.data[1]);
				
		next_instruction(15, "cufr r1 f6", 32'hd8b00003);
		#5 $display("Test | cufr r1 f6 @ T3 | a=0x39a1c000 | a=0x%h", _cpu._fpu.a);
		#5 $display("Test | cufr r1 f6 @ End | r1=0 | r1=%0b", _cpu._rf.data[1]);
	
		$finish;
	end
endmodule
