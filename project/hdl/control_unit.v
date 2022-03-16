module control_unit (
	// Inputs
	input [4:0] opcode,
	input [3:0] fpu_opcode,
	input branch_condition,

	// Control Signals
	output reg ir_en,
	output reg pc_increment, output reg pc_in_alu, output reg pc_in_rf_a,
	output reg ma_en,
	output reg memory_addr_in_pc, output reg memory_addr_in_ma,
	output reg alu_a_in_rf, output reg alu_a_in_pc,
	output reg alu_b_in_rf, output reg alu_b_in_constant,
	output reg lo_en,
	output reg hi_en,
	output reg rf_in_alu, output reg rf_in_hi, output reg rf_in_lo, output reg rf_in_memory, output reg rf_in_fpu, output reg rf_in_input,
	output reg output_en,
	output reg memory_en,

	output [11:0] alu_select,
	output [9:0] fpu_select,
	output reg fpu_mode, // 0 = ALU, 1 = FPU
	
	// Standard
	input clk,
	input clr,
	input halt,
	
	// Status
	output is_halted
);
	// Instruction Steps:
	// Most  : T0 T1 T2 T3
	// Store : T0 T1 T2 T3 T4
	// Load  : T0 T1 T2 T3 T4 T5
	// frc   : T0 T1 T2 R0 ... R7
	// div   : T0 T1 T2 DIV0 ... DIV31
	
	// Longest Instruction = div, therefor we need a 6-bit counter
	
	// Instruction Step Counter
	wire [5:0] step_out, step_inc;
	reg step_next, should_halt;
	
	register #( .BITS(1) ) _halt ( .d(1'b1), .q(is_halted), .en(halt | should_halt), .clk(clk), .clr(clr) );
	register #( .BITS(6) ) _sc  ( .d(step_next ? step_inc : 6'b0), .q(step_out), .en(~is_halted), .clk(clk), .clr(clr) );
	ripple_carry_adder #( .BITS(6) ) _sc_inc ( .a(step_out), .b(6'b1), .sum(step_inc), .c_in(1'b0), .c_out() );
	
	// Control Signals to ALU and FPU
	reg alu_not, alu_neg, alu_div, alu_mul, alu_or, alu_and, alu_rol, alu_ror, alu_shl, alu_shr, alu_sub, alu_add;
	reg fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf;
	
	reg fpu_frc_mode;
	
	assign alu_select = {alu_not, alu_neg, alu_div, alu_mul, alu_or, alu_and, alu_rol, alu_ror, alu_shl, alu_shr, alu_sub, alu_add};
	assign fpu_select = {fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf};
	
	always @(*) begin
		// Default values
		ir_en = 1'b0;
		pc_increment = 1'b0; pc_in_alu = 1'b0; pc_in_rf_a = 1'b0;
		ma_en = 1'b0;
		memory_addr_in_pc = 1'b0; memory_addr_in_ma = 1'b0;
		alu_a_in_rf = 1'b0; alu_a_in_pc = 1'b0;
		alu_b_in_rf = 1'b0; alu_b_in_constant = 1'b0;
		lo_en = 1'b0; hi_en = 1'b0;
		rf_in_alu = 1'b0; rf_in_hi = 1'b0; rf_in_lo = 1'b0; rf_in_memory = 1'b0; rf_in_input = 1'b0; rf_in_fpu = 1'b0;
		output_en = 1'b0;
		memory_en = 1'b0;
		{alu_not, alu_neg, alu_div, alu_mul, alu_or, alu_and, alu_rol, alu_ror, alu_shl, alu_shr, alu_sub, alu_add} = 12'b0;
		{fpu_feq, fpu_fgt, fpu_frc, fpu_fmul, fpu_fsub, fpu_fadd, fpu_cufr, fpu_curf, fpu_cfr, fpu_crf} = 10'b0;
		
		// fpu_mode determines ALU inputs for all FPU instructions
		// fpu_frc_mode is used for all steps R0..R7 of the float reciprocal function
		fpu_mode = opcode == 5'b11011;
		fpu_frc_mode = fpu_mode & (fpu_opcode == 4'b0111);
		
		// Set to 0 when the instruction is complete, and the next step should return to T0
		step_next = 1'b1;
		
		// Don't halt unless halt instr encountered
		should_halt = 1'b0;
		
		if (~is_halted)
		begin
			case (step_out)
				6'b000000 :
					begin
						// T1
						// Instruction Fetch, PC Increment
						pc_increment = 1'b1;
						memory_addr_in_pc = 1'b1;
					end
				6'b000001 :
					begin
						// T2
						ir_en = 1'b1;
					end
				6'b000010 :
					begin
						// T3
						control_t3();
					end
				6'b000011 : 
					begin
						// T4 / RC1
						if (opcode == 5'b00000) // Load
						begin
							memory_addr_in_ma = 1'b1;
						end
						else if (opcode == 5'b00010) // Store
						begin
							memory_addr_in_ma = 1'b1;
							memory_en = 1'b1;
							step_next = 1'b0;
						end
						else if (fpu_frc_mode) // FPU - Float Reciprocal - RC1
						begin
							fpu_frc = 1'b1;
							alu_mul = 1'b1;
						end
					end
				6'b000100 :
					begin
						// T5 / RC2
						if (opcode == 5'b00000) // Load
						begin
							rf_in_memory = 1'b1;
							step_next = 1'b0;
						end
						else if (fpu_frc_mode) // FPU - Float Reciprocal - RC2
						begin
							fpu_frc = 1'b1;
							alu_mul = 1'b1;
						end
					end
				6'b000101 :
					begin
						// FPU - Float Reciprocal - RC3
						if (fpu_frc_mode)
						begin
							fpu_frc = 1'b1;
							alu_mul = 1'b1;
						end
					end
				6'b000110 :
					begin
						// FPU - Float Reciprocal - RC4
						if (fpu_frc_mode)
						begin
							fpu_frc = 1'b1;
							alu_mul = 1'b1;
						end
					end
				6'b000111 :
					begin
						// FPU - Float Reciprocal - RC5
						if (fpu_frc_mode)
						begin
							fpu_frc = 1'b1;
						end
					end
				6'b001000 :
					begin
						// FPU - Float Reciprocal - RC6
						if (fpu_frc_mode)
						begin
							fpu_frc = 1'b1;
							alu_mul = 1'b1;
						end
					end
				6'b001001 :
					begin
						// FPU - Float Reciprocal - RC7
						if (fpu_frc_mode)
						begin
							fpu_frc = 1'b1;
							rf_in_fpu = 1'b1;
							step_next = 1'b0;
						end
					end
				6'b100010 :
					begin
						// Divide - DIV32
						if (opcode == 5'b01111) // Divide
						begin
							// Technically alu_div = 1 invokes the divider 32-cycle sequence again
							// However it doesn't actually make any difference in the long run - it can be restarted from the middle with no consequence.
							alu_div = 1'b1;
							hi_en = 1'b1;
							lo_en = 1'b1;
							step_next = 1'b0;
						end
					end
				default : ;
			endcase
		end
	end
	
	/**
	 * Invoke control signals for T3
	 */
	task control_t3();
		case (opcode)
			5'b00000 : // Load
				begin
					ma_en = 1'b1;
					alu_add = 1'b1;
					alu_a_in_rf = 1'b1;
					alu_b_in_constant = 1'b1;
				end
			5'b00001 : // Load Immediate (Add Immediate)
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_constant = 1'b1;
					rf_in_alu = 1'b1;
					alu_add = 1'b1;
					step_next = 1'b0;
				end
			5'b00010 : // Store
				begin
					ma_en = 1'b1;
					alu_add = 1'b1;
					alu_a_in_rf = 1'b1;
					alu_b_in_constant = 1'b1;
				end
			5'b00011 : // Add
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_rf = 1'b1;
					rf_in_alu = 1'b1;
					alu_add = 1'b1;
					step_next = 1'b0;
				end
			5'b00100 : // Subtract
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_rf = 1'b1;
					rf_in_alu = 1'b1;
					alu_sub = 1'b1;
					step_next = 1'b0;
				end
			5'b00101 : // Shift Right
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_rf = 1'b1;
					rf_in_alu = 1'b1;
					alu_shr = 1'b1;
					step_next = 1'b0;
				end
			5'b00110 : // Shift Left
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_rf = 1'b1;
					rf_in_alu = 1'b1;
					alu_shl = 1'b1;
					step_next = 1'b0;
				end
			5'b00111 : // Rotate Right
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_rf = 1'b1;
					rf_in_alu = 1'b1;
					alu_ror = 1'b1;
					step_next = 1'b0;
				end
			5'b01000 : // Rotate Left
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_rf = 1'b1;
					rf_in_alu = 1'b1;
					alu_rol = 1'b1;
					step_next = 1'b0;
				end
			5'b01001 : // And
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_rf = 1'b1;
					rf_in_alu = 1'b1;
					alu_and = 1'b1;
					step_next = 1'b0;
				end
			5'b01010 : // Or
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_rf = 1'b1;
					rf_in_alu = 1'b1;
					alu_or = 1'b1;
					step_next = 1'b0;
				end
			5'b01011 : // Add Immediate
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_constant = 1'b1;
					rf_in_alu = 1'b1;
					alu_add = 1'b1;
					step_next = 1'b0;
				end
			5'b01100 : // And Immediate
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_constant = 1'b1;
					rf_in_alu = 1'b1;
					alu_and = 1'b1;
					step_next = 1'b0;
				end
			5'b01101 : // Or Immediate
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_constant = 1'b1;
					rf_in_alu = 1'b1;
					alu_or = 1'b1;
					step_next = 1'b0;
				end
			5'b01110 : // Multiply
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_rf = 1'b1;
					alu_mul = 1'b1;
					hi_en = 1'b1;
					lo_en = 1'b1;
					step_next = 1'b0;
				end
			5'b01111 : // Divide
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_rf = 1'b1;
					alu_div = 1'b1;
				end
			5'b10000 : // Negate
				begin
					alu_a_in_rf = 1'b1;
					rf_in_alu = 1'b1;
					alu_neg = 1'b1;
					step_next = 1'b0;
				end
			5'b10001 : // Not
				begin
					alu_a_in_rf = 1'b1;
					rf_in_alu = 1'b1;
					alu_not = 1'b1;
					step_next = 1'b0;
				end
			5'b10010 : // Conditional (all branches)
				begin
					alu_a_in_pc = 1'b1;
					alu_b_in_constant = 1'b1;
					alu_add = 1'b1;
					// Something isn't working here. See testbench for first brzr
					pc_in_alu = branch_condition ? 1'b1 : 1'b0;
					step_next = 1'b0;
				end
			5'b10011 : // Jump (Return)
				begin
					pc_in_rf_a = 1'b1;
					step_next = 1'b0;
				end
			5'b10100 : // Jump and Link (Call)
				begin
					alu_a_in_pc = 1'b1;
					alu_add = 1'b1;
					rf_in_alu = 1'b1;
					pc_in_rf_a = 1'b1;
					step_next = 1'b0;
				end
			5'b10101 : // Input
				begin
					rf_in_input = 1'b1;
					step_next = 1'b0;
				end
			5'b10110 : // Output
				begin
					output_en = 1'b1;
					step_next = 1'b0;
				end
			5'b10111 : // Move from HI
				begin
					rf_in_hi = 1'b1;
					step_next = 1'b0;
				end
			5'b11000 : // Move from LO
				begin
					rf_in_lo = 1'b1;
					step_next = 1'b0;
				end
			5'b11001 : // Noop
				begin
					step_next = 1'b0;
				end
			5'b11010 : // Halt
				begin
					step_next = 1'b0;
					should_halt = 1'b1;
				end
			5'b11011 : // FPU Instruction (Various)
				begin
					control_t3_fpu();
				end
			default : ;
		endcase
	endtask
		
	/**
	 * Invoke control signals for T3, FPU Instructions
	 */
	task control_t3_fpu();
		case (fpu_opcode)
			4'b0000 : // Cast Register to Float
				begin
					fpu_crf = 1'b1;
					rf_in_fpu = 1'b1;
					step_next = 1'b0;
				end
			4'b0001 : // Cast Float to Register
				begin
					fpu_cfr = 1'b1;
					rf_in_fpu = 1'b1;
					step_next = 1'b0;
				end
			4'b0010 : // Cast Register to Float (Unsigned)
				begin
					fpu_curf = 1'b1;
					rf_in_fpu = 1'b1;
					step_next = 1'b0;
				end
			4'b0011 : // Cast Register to Float (Unsigned)
				begin
					fpu_cufr = 1'b1;
					rf_in_fpu = 1'b1;
					step_next = 1'b0;
				end
			4'b0100 : // Float Add
				begin
					fpu_fadd = 1'b1;
					rf_in_fpu = 1'b1;
					step_next = 1'b0;
				end
			4'b0101 : // Float Subtract
				begin
					fpu_fsub = 1'b1;
					rf_in_fpu = 1'b1;
					step_next = 1'b0;
				end
			4'b0110 : // Float Multiply
				begin
					fpu_fmul = 1'b1;
					alu_mul = 1'b1;
					rf_in_fpu = 1'b1;
					step_next = 1'b0;
				end
			4'b0111 : // Float Reciprocal (+8 Cycles R2..R8)
				begin
					fpu_frc = 1'b1;
				end
			4'b1000 : // Float Greater Than
				begin
					fpu_fgt = 1'b1;
					rf_in_fpu = 1'b1;
					step_next = 1'b0;
				end
			4'b1001 : // Float Equals
				begin
					fpu_feq = 1'b1;
					rf_in_fpu = 1'b1;
					step_next = 1'b0;
				end
			default : ;
		endcase
	endtask
	
endmodule


`timescale 1ns/100ps
module control_unit_test;

	reg [31:0] input_in;
	wire [31:0] output_out;
	reg clk, clr;
	wire is_halted;

	cpu _cpu (
		.input_in(input_in),
		.output_out(output_out),
		.clk(clk),
		.clr(clr),
		.halt(1'b0),
		.input_en(1'b1),
		.is_halted(is_halted)
	);

	/**
	 * Computes and tests the T1 and T2 steps.
	 */
	task next_instruction(input [31:0] pc, input [127:0] assembly, input [31:0] instruction);
		begin
			#10 $display("Test | %0s @ T1 | pc=%0d, md=0x%h | pc=%0d, md=0x%h", assembly, pc + 1, instruction, _cpu._pc.q, _cpu._memory.data_out); // T1
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
		$readmemh("out/cpu_testbench.mem", _cpu._memory.data);
		
		// Initialize RF via two addi instructions
		next_instruction(0, "addi r2 r0 53", 32'h59000035);
		#5 $display("Test | addi r2 r0 53 @ <T3 | a=0, b=53, z=53 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | addi r2 r0 53 @ >T3 | r2=53 | r2=%0d", _cpu._rf.data[2]);

		next_instruction(1, "addi r4 r0 28", 32'h5a00001c);
		#5 $display("Test | addi r4 r0 28 @ <T3 | a=0, b=28, z=28 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | addi r4 r0 28 @ >T3 | r4=28 | r4=%0d", _cpu._rf.data[4]);


		// ================== PHASE 1 ============================ //

		next_instruction(2, "and r5 r2 r4", 32'h4a920000);
		#5 $display("Test | and r5 r2 r4 @ <T3 | a=53, b=28, z=20 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | and r5 r2 r4 @ >T3 | r5=20 | r5=%0d", _cpu._rf.data[5]);

		next_instruction(3, "or r5 r2 r4", 32'h52920000);
		#5 $display("Test | or r5 r2 r4 @ <T3 | a=53, b=28, z=61 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | or r5 r2 r4 @ >T3 | r5=61 | r5=%0d", _cpu._rf.data[5]);

		next_instruction(4, "add r5 r2 r4", 32'h1a920000);
		#5 $display("Test | add r5 r2 r4 @ <T3 | a=53, b=28, z=81 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | add r5 r2 r4 @ >T3 | r5=81 | r5=%0d", _cpu._rf.data[5]);

		next_instruction(5, "sub r5 r2 r4", 32'h22920000);
		#5 $display("Test | sub r5 r2 r4 @ <T3 | a=53, b=28, z=25 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | sub r5 r2 r4 @ >T3 | r5=25 | r5=%0d", _cpu._rf.data[5]);

		next_instruction(6, "shr r5 r2 r4", 32'h2a920000);
		#5 $display("Test | shr r5 r2 r4 @ <T3 | a=53, b=28, z=0 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | shr r5 r2 r4 @ >T3 | r5=0 | r5=%0d", _cpu._rf.data[5]);

		next_instruction(7, "shl r5 r2 r4", 32'h32920000);
		#5 $display("Test | shl r5 r2 r4 @ <T3 | a=53, b=28, z=1342177280 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | shl r5 r2 r4 @ >T3 | r5=1342177280 | r5=%0d", _cpu._rf.data[5]);

		next_instruction(8, "ror r5 r2 r4", 32'h3a920000);
		#5 $display("Test | ror r5 r2 r4 @ <T3 | a=53, b=28, z=848 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | ror r5 r2 r4 @ >T3 | r5=848 | r5=%0d", _cpu._rf.data[5]);

		next_instruction(9, "rol r5 r2 r4", 32'h42920000);
		#5 $display("Test | rol r5 r2 r4 @ <T3 | a=53, b=28, z=1342177283 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | rol r5 r2 r4 @ >T3 | r5=1342177283 | r5=%0d", _cpu._rf.data[5]);

		next_instruction(10, "mul r2 r4", 32'h71200000);
		#5 $display("Test | mul r2 r4 @ <T3 | a=53, b=28 | a=%0d, b=%0d", _cpu._alu.a, _cpu._alu.b);
		#5 $display("Test | mul r2 r4 @ >T3 | hi=0, lo=1484 | hi=%0d, lo=%0d", _cpu._hi.q, _cpu._lo.q);

		next_instruction(11, "div r2 r4", 32'h79200000);
		#5 $display("Test | div r2 r4 @ DIV1 | a=53, b=28 | a=%0d, b=%0d", _cpu._alu.a, _cpu._alu.b);
		#320 // Wait for div to complete (32 cycles)
		#5 $display("Test | div r2 r4 @ >DIV32 | hi=25, lo=1 | hi=%0d, lo=%0d", _cpu._hi.q, _cpu._lo.q);
		
		next_instruction(12, "neg r5 r2", 32'h82900000);
		#5 $display("Test | neg r5 r2 @ <T3 | a=53, z=-53 | a=%0d, z=%0d", _cpu._alu.a, $signed(_cpu._alu.z));
		#5 $display("Test | neg r5 r2 @ >T3 | r5=-53 | r5=%0d", $signed(_cpu._rf.data[5]));

		next_instruction(13, "not r5 r2", 32'h8a900000);
		#5 $display("Test | not r5 r2 @ <T3 | a=0x00000035, z=0xffffffca | a=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.z);
		#5 $display("Test | not r5 r2 @ >T3 | r5=0xffffffca | r5=0x%h", _cpu._rf.data[5]);

		// ===================== PHASE 2 =========================== //

		next_instruction(14, "ld r1 85", 32'h00800055);
		#5; $display("Test | ld r1 85 @ <T3 | a=0x00000000, b=0x00000055, z=0x00000055 | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | ld r1 85 @ >T3 | ma=0x00000055 | ma=0x%h", _cpu._ma.q);
		#10; $display("Test | ld r1 85 @ T4 | md=0x0000000a | md=0x%h", _cpu._memory.data_out);
		#10; $display("Test | ld r1 85 @ T5 | r1=0x0000000a | r1=0x%h", _cpu._rf.data[1]);

		next_instruction(15, "ld r0 35(r1)", 32'h00080023);
		#5; $display("Test | ld r0 35(r1) @ <T3 | a=0x0000000a, b=0x00000023, z=0x0000002d | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | ld r0 35(r1) @ >T3 | ma=0x0000002d | ma=0x%h", _cpu._ma.q);
		#10; $display("Test | ld r0 35(r1) @ T4 | md=0xdeadbeef | md=0x%h", _cpu._memory.data_out);
		#10; $display("Test | ld r0 35(r1) @ T5 | r0=0xdeadbeef | r0=0x%h", _cpu._rf.data[0]);

		next_instruction(16, "ldi r1 85", 32'h08800055);
		#5; $display("Test | ldi r1 85 @ <T3 | a=0x00000000, b=0x00000055, z=0x00000055 | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | ldi r1 85 @ >T3 | r1=0x00000055 | r1=0x%h", _cpu._rf.data[1]);

		next_instruction(17, "ldi r0 35(r1)", 32'h08080023);
		#5; $display("Test | ldi r0 35(r1) @ <T3 | a=0x00000055, b=0x00000023, z=0x00000078 | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | ldi r0 35(r1) @ >T3 | r0=0x00000078 | r0=0x%h", _cpu._rf.data[0]);

		next_instruction(18, "st 90 r1", 32'h1080005a);
		#5; $display("Test | st 90 r1 @ <T3 | a=0x00000000, b=0x0000005a, z=0x0000005a | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | st 90 r1 @ >T3 | ma=0x0000005a | ma=0x%h", _cpu._ma.q);
		#5; $display("Test | st 90 r1 @ <T4 | m_in=0x00000055 | m_in=0x%h", _cpu._memory.data_in);
		#5; $display("Test | st 90 r1 @ >T4 | m[90]=0x00000055 | m[90]=0x%h", _cpu._memory.data[90]);

		next_instruction(19, "st 90(r1) r1", 32'h1088005a);
		#5; $display("Test | st 90(r1) r1 @ <T3 | a=0x00000055, b=0x0000005a, z=0x000000af | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | st 90(r1) r1 @ >T3 | ma=0x000000af | ma=0x%h", _cpu._ma.q);
		#5; $display("Test | st 90(r1) r1 @ <T4 | m_in=0x00000055 | m_in=0x%h", _cpu._memory.data_in);
		#5; $display("Test | st 90(r1) r1 @ >T4 | m[175]=0x00000055 | m[175]=0x%h", _cpu._memory.data[175]);

		next_instruction(20, "addi r2 r1 -5", 32'h590ffffb);
		#5; $display("Test | addi r2 r1 -5 @ <T3 | a=0x00000055, b=0xfffffffb, z=0x00000050 | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | addi r2 r1 -5 @ >T3 | r2=0x00000050 | r2=0x%h", _cpu._rf.data[2]);

		next_instruction(21, "andi r2 r1 26", 32'h6108001a);
		#5; $display("Test | andi r2 r1 26 @ <T3 | a=0x00000055, b=0x0000001a, z=0x00000010 | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | andi r2 r1 26 @ >T3 | r2=0x00000010 | r2=0x%h", _cpu._rf.data[2]);

		next_instruction(22, "ori r2 r1 26", 32'h6908001a);
		#5; $display("Test | ori r2 r1 26 @ <T3 | a=0x00000055, b=0x0000001a, z=0x0000005f | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | ori r2 r1 26 @ >T3 | r2=0x0000005f | r2=0x%h", _cpu._rf.data[2]);

		// brzr r2, 35
		next_instruction(23, "brzr r2 35", 32'h91000023);

		// T3
		// Condition is false, so expect pc to remain the same
		// alu_a_in_pc <= 1'b1; alu_b_in_constant <= 1'b1; pc_in_alu <= branch_condition; alu_add <= 1'b1;
		// TODO: This isn't working. branch_condition = 0, but pc_in_alu = 1
		#5; $display("Test | brzr r2 35 @ <T3 | a=0x00000018, b=0x00000023, z=0x0000003b | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | brzr r2 35 @ >T3 | br_cond=0x0, pc=0x00000018 | br_cond=0x%h, pc=0x%h", _cpu.branch_condition, _cpu._pc.q);


		// brnz r2, 35
		next_instruction(24, "brnz r2 35", 32'h91080023);

		// T3
		// Condition is true, so expect pc to go up
		// alu_a_in_pc <= 1'b1; alu_b_in_constant <= 1'b1; pc_in_alu <= branch_condition; alu_add <= 1'b1;
		#5; $display("Test | brnz r2 35 @ <T3 | a=0x00000019, b=0x00000023, z=0x0000003c | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | brnz r2 35 @ >T3 | br_cond=0x1, pc=0x0000003c | br_cond=0x%h, pc=0x%h", _cpu.branch_condition, _cpu._pc.q);

		// Reset PC after last branch (brnz r2 -36 @ pc = 60 = 0x3c)
		next_instruction(60, "brnz r2 -36", 32'h910fffdc);
		// alu_a_in_pc <= 1'b1; alu_b_in_constant <= 1'b1; pc_in_alu <= branch_condition; alu_add <= 1'b1;
		#5; $display("Test | brnz r2 -36 @ <T3 | a=0x0000003d, b=0xffffffdc, z=0x00000019 | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | brnz r2 -36 @ >T3 | br_cond=0x1, pc=0x00000019 | br_cond=0x%h, pc=0x%h", _cpu.branch_condition, _cpu._pc.q);


		// brpl r2, 35
		next_instruction(25, "brpl r2 35", 32'h91100023);

		// T3
		// Condition is true, so expect pc to go up
		// alu_a_in_pc <= 1'b1; alu_b_in_constant <= 1'b1; pc_in_alu <= branch_condition; alu_add <= 1'b1;
		#5; $display("Test | brpl r2 35 @ <T3 | a=0x0000001a, b=0x00000023, z=0x0000003d | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | brpl r2 35 @ >T3 | br_cond=0x1, pc=0x0000003d | br_cond=0x%h, pc=0x%h", _cpu.branch_condition, _cpu._pc.q);

		// Reset PC after last branch (brpl r2 -36 @ pc = 61 = 0x3d)
		next_instruction(61, "brpl r2 -36", 32'h9117ffdc);
		// alu_a_in_pc <= 1'b1; alu_b_in_constant <= 1'b1; pc_in_alu <= branch_condition; alu_add <= 1'b1;
		#5; $display("Test | brpl r2 -36 @ <T3 | a=0x0000003e, b=0xffffffdc, z=0x0000001a | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | brpl r2 -36 @ >T3 | br_cond=0x1, pc=0x0000001a | br_cond=0x%h, pc=0x%h", _cpu.branch_condition, _cpu._pc.q);


		// brmi r2, 35
		next_instruction(26, "brmi r2 35", 32'h91180023);

		// T3
		// Condition is false, so expect pc to remain the same
		// alu_a_in_pc <= 1'b1; alu_b_in_constant <= 1'b1; pc_in_alu <= branch_condition; alu_add <= 1'b1;
		#5; $display("Test | brmi r2 35 @ <T3 | a=0x0000001b, b=0x00000023, z=0x0000003e | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | brmi r2 35 @ >T3 | br_cond=0x0, pc=0x0000001b | br_cond=0x%h, pc=0x%h", _cpu.branch_condition, _cpu._pc.q);


		// Non-test instruction, to set up r1 for next jr r1 (ldi r1, 62)
		next_instruction(27, "ldi r1, 62", 32'h0880003e);
		// alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5; $display("Test | ldi r1 62 @ <T3 | a=0x00000000, b=0x0000003e, z=0x0000003e | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | ldi r1 62 @ >T3 | r1=0x0000003e | r1=0x%h", _cpu._rf.data[1]);

		// jal r1
		next_instruction(28, "jal r1", 32'ha0800000);

		// T3
		// Two things happen: PC <- rX, and r15 <- PC.
		// Latter step must go through alu, so if we don't set alu_b_in_x, default to 32'b0
		// pc_in_rf_a <= 1'b1;
		// alu_a_in_pc <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5; $display("Test | jal r1 @ <T3 | a=0x0000001d, b=0x00000000, z=0x0000001d | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | jal r1 @ >T3 | r15=0x0000001d, rf_a_out=0x0000003e, pc=0x0000003e | r15=0x%h, rf_a_out=0x%h, pc=0x%h", _cpu._rf.data[15], _cpu.rf_a_out, _cpu._pc.q);


		// jr r15
		next_instruction(62, "jr r15", 32'h9f800000);

		// T3
		// pc_in_rf_a <= 1'b1;
		#10; $display("Test | jr r15 @ T3 | rf_a_out=0x0000001d, pc=0x0000001d | rf_a_out=0x%h, pc=0x%h", _cpu.rf_a_out, _cpu._pc.q);


		// mfhi r2
		next_instruction(29, "mfhi r2", 32'hb9000000);

		// T3
		// rf_in_hi <= 1'b1;
		#10; $display("Test | mfhi r2 @ T3 | r2=0x00000019 | r2=0x%h", _cpu._rf.data[2]);


		// mfhi r2
		next_instruction(30, "mflo r2", 32'hc1000000);

		// T3
		// rf_in_lo <= 1'b1;
		#10; $display("Test | mflo r2 @ T3 | r2=0x00000001 | r2=0x%h", _cpu._rf.data[2]);


		// out r1
		next_instruction(31, "out r1", 32'hb0800000);

		// T3
		// output_en <= 1'b1;
		#10; $display("Test | out r1 @ T3 | r1=0x0000003e, output_out=0x0000003e | r1=0x%h, output_out=0x%h", _cpu._rf.data[1], _cpu._out.q);


		// in r1
		next_instruction(32, "in r1", 32'ha8800000);

		// T3
		// input_in <= 32'h55555555;
		// rf_in_input <= 1'b1;
		#5; $display("Test | in r1 @ <T3 | input_out=0x55555555 | input_out=0x%h", _cpu._in.d);
		#5; $display("Test | in r1 @ >T3 | r1=0x55555555 | r1=0x%h", _cpu._rf.data[1]);
		
		$finish;
	end
endmodule

