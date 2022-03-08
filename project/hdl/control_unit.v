module control_unit (
	// Inputs
	input [4:0] opcode,
	input [3:0] fpu_opcode,
	input branch_condition,

	// Control Signals
	output reg ir_en,
	output reg pc_increment, output reg pc_in_alu, output reg pc_in_rf_a,
	output reg ma_in_pc, output reg ma_in_alu,
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
	input halt
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
	reg step_next;
	
	register #( .BITS(6) ) _sc ( .d(step_next ? step_inc : 6'b0), .q(step_out), .en(1'b1), .clk(clk), .clr(clr) );
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
		ma_in_pc = 1'b0; ma_in_alu = 1'b0;
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
	
		case (step_out)
			6'b000000 :
				begin
					// T0
					pc_increment = 1'b1;
					ma_in_pc = 1'b1;
				end
			6'b000001 :
				begin
					// T1
					// Memory Read (Instruction)
				end
			6'b000010 :
				begin
					// T2
					ir_en = 1'b1;
				end
			6'b000011 :
				begin
					// T3
					control_t3();
				end
			6'b000100 : 
				begin
					// T4 / RC1
					if (opcode == 5'b00010) // Store
					begin
						memory_en = 1'b1;
						step_next = 1'b0;
					end
					else if (fpu_frc_mode) // FPU - Float Reciprocal - RC1
					begin
						fpu_frc = 1'b1;
						alu_mul = 1'b1;
					end
				end
			6'b000101 :
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
			6'b000110 :
				begin
					// FPU - Float Reciprocal - RC3
					if (fpu_frc_mode)
					begin
						fpu_frc = 1'b1;
						alu_mul = 1'b1;
					end
				end
			6'b000111 :
				begin
					// FPU - Float Reciprocal - RC4
					if (fpu_frc_mode)
					begin
						fpu_frc = 1'b1;
						alu_mul = 1'b1;
					end
				end
			6'b001000 :
				begin
					// FPU - Float Reciprocal - RC5
					if (fpu_frc_mode)
					begin
						fpu_frc = 1'b1;
					end
				end
			6'b001001 :
				begin
					// FPU - Float Reciprocal - RC6
					if (fpu_frc_mode)
					begin
						fpu_frc = 1'b1;
						alu_mul = 1'b1;
					end
				end
			6'b001010 :
				begin
					// FPU - Float Reciprocal - RC7
					if (fpu_frc_mode)
					begin
						fpu_frc = 1'b1;
						rf_in_fpu = 1'b1;
						step_next = 1'b0;
					end
				end
			6'b100011 :
				begin
					// Divide - DIV32
					if (opcode == 5'b01111) // Divide
					begin
						// Technically alu_div = 1 invokes the divider 32-cycle sequence again
						// However it doesn't actually make any difference in the long run - it can be restarted from the middle with no consequence.
						alu_div <= 1'b1;
						hi_en = 1'b1;
						lo_en = 1'b1;
						step_next = 1'b0;
					end
				end
			default : ;
		endcase
	end
	
	/**
	 * Invoke control signals for T3
	 */
	task control_t3();
		case (opcode)
			5'b00000 : // Load
				begin
					alu_a_in_rf = 1'b1;
					alu_b_in_constant = 1'b1;
					ma_in_alu = 1'b1;
					alu_add = 1'b1;
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
					ma_in_alu = 1'b1;
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
					rf_in_lo = 1'b0;
					step_next = 1'b0;
				end
			5'b11001 : // Noop
				begin
					step_next = 1'b0;
				end
			5'b11010 : // Halt
				begin
					// todo: actually implement the halting somehow
					step_next = 1'b0;
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
	initial begin
		$finish;
	end
endmodule

