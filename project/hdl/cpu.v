/**
 * cpu: top-level module for the CPU.
 * Control signals (enables, datapath routing, RF addresses, ALU select, constants), memory interface, and IR logic are specified as input ports to this module, so the submodules aren't compiled away by Quartus.
 */
module cpu (
	// Control Signals
	// foo_en = Enable signal for writing to foo
	// foo_in_bar = Enable signal for writing foo <= bar
	input ir_en,
	input pc_increment, input pc_in_alu, input pc_in_rf_a,
	input ma_in_pc, input ma_in_alu,
	input alu_a_in_rf, input alu_a_in_pc,
	input alu_b_in_rf, input alu_b_in_constant,
	input lo_en,
	input hi_en,
	input rf_in_alu, input rf_in_hi, input rf_in_lo, input rf_in_memory, input rf_in_fpu, input rf_in_input,
	input input_en, output_en,
	input memory_en,

	input [11:0] alu_select,
	input [9:0] fpu_select,
	input fpu_mode, // 0 = ALU, 1 = FPU
	
	// I/O
	input [31:0] input_in,
	input [31:0] output_out,

	// To Control Logic
	output [31:0] ir_out,
	output reg branch_condition,
	
	// Standard
	input clk,
	input clr
);

	// Based on the 3-Bus Architecture
	// We can exclude the A, B, Y and Z registers
	// Memory has a built-in MD register (in inferred Quartus memory), so we exclude that as well
	wire [31:0] pc_out, ma_out, hi_out, lo_out, rf_a_out, rf_b_out, alu_z_out, alu_lo_out, alu_hi_out, constant_c, input_out, fpu_bridge_alu_a, fpu_bridge_alu_b, fpu_rz_out;
	reg [31:0] pc_in, ma_in, alu_a_in, alu_b_in, rf_in;

	wire pc_en, ma_en, rf_en;

	// Memory Interface
	// We don't need memory_in because it's always hard-wired to rf_b_out
	wire [31:0] memory_out;

	// Register File
	wire [3:0] rf_a_addr, rf_b_addr, rf_z_addr;

	// Additional register connections

	// PC Increment Logic
	// Control Signals: pc_increment, pc_in_alu, pc_in_rf_a
	// Inputs: PC + 1, PC + C, rX
	wire [31:0] pc_plus_1;
	wire pc_cout;

	ripple_carry_adder _pc_adder ( .a(pc_out), .b(32'b1), .sum(pc_plus_1), .c_in(1'b0), .c_out(pc_cout) ); // PC + 1

	assign pc_en = pc_increment | pc_in_alu | pc_in_rf_a;

	always @(*) begin
		case ({pc_increment, pc_in_alu, pc_in_rf_a})
			3'b001 : pc_in <= rf_a_out;
			3'b010 : pc_in <= alu_z_out;
			3'b100 : pc_in <= pc_plus_1;
			default : pc_in <= 32'b0;
		endcase
	end

	// IR Decoding
	wire [4:0] ir_opcode;
	wire [3:0] ir_ra, ir_rb_or_c2, ir_rc;
	wire [18:0] ir_constant_c;

	assign ir_opcode     = ir_out[31:27];
	assign ir_ra         = ir_out[26:23];
	assign ir_rb_or_c2   = ir_out[22:19];
	assign ir_rc         = ir_out[18:15];
	assign ir_constant_c = ir_out[18:0];

	// Sign extend the constant C to 32 bits
	assign constant_c = {{13{ir_constant_c[18]}}, ir_constant_c};

	// Map rA, rB, and rC wires to the register file write address, read address A and B, respectively
	// mul and div have two parameter registers in rA and rB, that need to map to address A and B
	// Branch, jr, jal, and out instructions use rA as a read register, not as a write one.
	// jal has rf_z_addr hard-wired to r15 (0xf)
	assign rf_z_addr = (ir_opcode == 5'b10100) ? 4'b1111 : ir_ra;
	assign rf_a_addr = (ir_opcode == 5'b10010 || ir_opcode == 5'b01110 || ir_opcode == 5'b01111 || ir_opcode == 5'b10011 || ir_opcode == 5'b10100 || ir_opcode == 5'b10110) ? ir_ra : ir_rb_or_c2;
	assign rf_b_addr = (ir_opcode == 5'b00010) ? ir_ra : (ir_opcode == 5'b01110 || ir_opcode == 5'b01111) ? ir_rb_or_c2 : ir_rc;

	// Evaluate the branch condition based on C2

	always @(*) begin
		case (ir_rb_or_c2[1:0])
			2'b00 : branch_condition = rf_a_out == 32'b0;
			2'b01 : branch_condition = rf_a_out != 32'b0;
			2'b10 : branch_condition = !rf_a_out[31] && (| rf_a_out[30:0]); // sign bit = 0 and any other bit != 0 => Positive
			2'b11 : branch_condition = rf_a_out[31]; // sign bit = 1 => Negative
		endcase
	end

	// MA Register
	// Control Signals: ma_in_pc, ma_in_alu
	assign ma_en = ma_in_pc | ma_in_alu;

	always @(*) begin
		case ({ma_in_pc, ma_in_alu})
			2'b01 : ma_in <= alu_z_out;
			2'b10 : ma_in <= pc_out;
			default : ma_in <= 32'b0;
		endcase
	end

	// ALU Inputs
	// Left input can be PC, rY, or driven by FPU
	// Right input can be rX, constant C, or driven by FPU
	// Control Signals: alu_a_in_rf, alu_a_in_pc, alu_b_in_rf, alu_b_in_constant
	always @(*) begin
		case ({fpu_mode, alu_a_in_rf, alu_a_in_pc})
			3'b001 : alu_a_in <= pc_out;
			3'b010 : alu_a_in <= rf_a_out;
			3'b100 : alu_a_in <= fpu_bridge_alu_a;
			default : alu_a_in <= 32'b0;
		endcase

		case ({fpu_mode, alu_b_in_rf, alu_b_in_constant})
			3'b001 : alu_b_in <= constant_c;
			3'b010 : alu_b_in <= rf_b_out;
			3'b100 : alu_b_in <= fpu_bridge_alu_b;
			default : alu_b_in <= 32'b0;
		endcase
	end

	// RF Inputs
	// Input can by any of ALU Z, HI, LO, Memory, INPUT, or FPU
	assign rf_en = rf_in_alu | rf_in_hi | rf_in_lo | rf_in_memory | rf_in_input | rf_in_fpu;

	always @(*) begin
		case ({rf_in_input, rf_in_fpu, rf_in_alu, rf_in_hi, rf_in_lo, rf_in_memory})
			6'b000001 : rf_in <= memory_out;
			6'b000010 : rf_in <= lo_out;
			6'b000100 : rf_in <= hi_out;
			6'b001000 : rf_in <= alu_z_out;
			6'b010000 : rf_in <= fpu_rz_out;
			6'b100000 : rf_in <= input_out;
			default : rf_in <= 32'b0;
		endcase
	end

	register_file #( .BITS(32), .WORDS(16) ) _rf (
		.data_in(rf_in),
		.addr_in(rf_en ? rf_z_addr : 4'b0), // R0 has a no-op write
		.addr_a(rf_a_addr),
		.addr_b(rf_b_addr),
		.data_a(rf_a_out),
		.data_b(rf_b_out),
		.clk(clk),
		.clr(clr)
	);

	// Floating Point Unit
	// Isolated from the rest of the processor as much as possible
	fpu _fpu (
		.a(rf_a_out),
		.b(rf_b_out),
		.z(fpu_rz_out),
		.select(fpu_select),
		.illegal(),
		.alu_a(fpu_bridge_alu_a),
		.alu_b(fpu_bridge_alu_b),
		.alu_hi(alu_hi_out),
		.alu_lo(alu_lo_out),
		.clk(clk),
		.clr(clr)
	);

	register _pc  ( .q(pc_in),      .d(pc_out),     .en(pc_en),     .clk(clk), .clr(clr) );
	register _ir  ( .q(memory_out), .d(ir_out),     .en(ir_en),     .clk(clk), .clr(clr) ); // IR in = Memory
	register _ma  ( .q(ma_in),      .d(ma_out),     .en(ma_en),     .clk(clk), .clr(clr) );
	register _hi  ( .q(alu_hi_out), .d(hi_out),     .en(hi_en),     .clk(clk), .clr(clr) ); // HI and LO in = ALU out
	register _lo  ( .q(alu_lo_out), .d(lo_out),     .en(lo_en),     .clk(clk), .clr(clr) );
	register _in  ( .q(input_in),   .d(input_out),  .en(input_en),  .clk(clk), .clr(clr) ); // IN and OUT
	register _out ( .q(rf_a_out),   .d(output_out), .en(output_en), .clk(clk), .clr(clr) );

	alu _alu ( .a(alu_a_in), .b(alu_b_in), .z(alu_z_out), .hi(alu_hi_out), .lo(alu_lo_out), .select(alu_select) );

	memory #( .BITS(32), .WORDS(512) ) _memory (
		.address(ma_out[8:0]),
		.data_in(rf_b_out), // Data to Memory = RF B Out
		.data_out(memory_out),
		.en(memory_en),
		.clk(clk)
	);

endmodule


/**
 * Testbench
 * Simulates various instructions by manually wiring in the correct control signals
 */
`timescale 1ns/100ps
module cpu_test;

	// Control Signals
	reg ir_en;
	reg pc_increment, pc_in_alu, pc_in_rf_a;
	reg ma_in_pc, ma_in_alu;
	reg alu_a_in_rf, alu_a_in_pc;
	reg alu_b_in_rf, alu_b_in_constant;
	reg lo_en, hi_en;
	reg rf_in_alu, rf_in_hi, rf_in_lo, rf_in_memory, rf_in_input;
	reg input_en, output_en;
	reg memory_en;

	reg alu_not, alu_neg, alu_div, alu_mul, alu_or, alu_and, alu_rol, alu_ror, alu_shl, alu_shr, alu_sub, alu_add;

	wire [31:0] ir_out;
	wire branch_condition;

	reg [31:0] input_in, output_out;

	reg clk, clr;

	cpu _cpu (
		.ir_en(ir_en),
		.pc_increment(pc_increment), .pc_in_alu(pc_in_alu), .pc_in_rf_a(pc_in_rf_a),
		.ma_in_pc(ma_in_pc), .ma_in_alu(ma_in_alu),
		.alu_a_in_rf(alu_a_in_rf), .alu_a_in_pc(alu_a_in_pc),
		.alu_b_in_rf(alu_b_in_rf), .alu_b_in_constant(alu_b_in_constant),
		.lo_en(lo_en), .hi_en(hi_en),
		.rf_in_alu(rf_in_alu), .rf_in_hi(rf_in_hi), .rf_in_lo(rf_in_lo), .rf_in_memory(rf_in_memory), .rf_in_fpu(1'b0), .rf_in_input(rf_in_input),
		.alu_select({alu_not, alu_neg, alu_div, alu_mul, alu_or, alu_and, alu_rol, alu_ror, alu_shl, alu_shr, alu_sub, alu_add}),
		.fpu_select(12'b0), .fpu_mode(1'b0), // Disable FPU
		.ir_out(ir_out), .clk(clk), .clr(clr),
		.input_en(input_en), .output_en(output_en),
		.memory_en(memory_en),
		.branch_condition(branch_condition),
		.input_in(input_in), .output_out(output_out)
	);

	/**
	 * Resets all control signals to zero
	 */
	task control_reset();
		begin
			ir_en <= 1'b0;
			pc_increment <= 1'b0; pc_in_alu <= 1'b0; pc_in_rf_a <= 1'b0;
			ma_in_pc <= 1'b0; ma_in_alu <= 1'b0;
			alu_a_in_rf <= 1'b0; alu_a_in_pc <= 1'b0;
			alu_b_in_rf <= 1'b0; alu_b_in_constant <= 1'b0;
			lo_en <= 1'b0; hi_en <= 1'b0;
			rf_in_alu <= 1'b0; rf_in_hi <= 1'b0; rf_in_lo <= 1'b0; rf_in_memory <= 1'b0; rf_in_input <= 1'b0;
			input_en <= 1'b0; output_en <= 1'b0;
			memory_en <= 1'b0;
			{alu_not, alu_neg, alu_div, alu_mul, alu_or, alu_and, alu_rol, alu_ror, alu_shl, alu_shr, alu_sub, alu_add} <= 12'b0;
		end
	endtask

	/**
	 * Computes and tests the T0, T1 and T2 steps.
	 */
	task next_instruction(input [31:0] pc, input [127:0] assembly, input [31:0] instruction);
		begin
			// T0
			control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1;
			#10 $display("Test | %s @ T0 | pc=%0d, ma=%0d | pc=%0d, ma=%0d", assembly, pc + 1, pc, _cpu._pc.d, _cpu._ma.d);

			// T1
			control_reset();
			#10 $display("Test | %s @ T1 | md=0x%h | md=0x%h", assembly, instruction, _cpu._memory.data_out);

			// T2
			control_reset(); ir_en <= 1'b1;
			#10 $display("Test | %s @ T2 | ir=0x%h | ir=0x%h", assembly, instruction, _cpu._ir.d);

			// T3
			control_reset();
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
		#10

		// Start
		#1
		clr <= 1'b1;

		// Initialize Memory
		$display("Initializing Memory");
		$readmemh("out/cpu_testbench.mem", _cpu._memory.data);

		// Initialize RF via two addi instructions

		// addi r2, r0, 53
		next_instruction(0, "addi r2 r0 53", 32'h59000035);
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5 $display("Test | addi r2 r0 53 @ <T3 | a=0, b=53, z=53 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | addi r2 r0 53 @ >T3 | r2=53 | r2=%0d", _cpu._rf.data[2]);

		// addi r4, r0, 28
		next_instruction(1, "addi r4 r0 28", 32'h5a00001c);
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5 $display("Test | addi r4 r0 28 @ <T3 | a=0, b=28, z=28 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | addi r4 r0 28 @ >T3 | r4=28 | r4=%0d", _cpu._rf.data[4]);

		// Initialize INPUT to something
		input_in <= 32'h55555555; input_en <= 1'b1;
		#10; $display("Test | init input | input_out=0x55555555 | input_out=0x%h", _cpu._in.d);
		control_reset();

		// ================== PHASE 1 ============================ //

		// and r5, r2, r4
		next_instruction(2, "and r5 r2 r4", 32'h4a920000);
		alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_and <= 1'b1;
		#5 $display("Test | and r5 r2 r4 @ <T3 | a=53, b=28, z=20 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | and r5 r2 r4 @ >T3 | r5=20 | r5=%0d", _cpu._rf.data[5]);

		// or r5, r2, r4
		next_instruction(3, "or r5 r2 r4", 32'h52920000);
		alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_or <= 1'b1;
		#5 $display("Test | or r5 r2 r4 @ <T3 | a=53, b=28, z=61 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | or r5 r2 r4 @ >T3 | r5=61 | r5=%0d", _cpu._rf.data[5]);

		// add r5, r2, r4
		next_instruction(4, "add r5 r2 r4", 32'h1a920000);
		alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5 $display("Test | add r5 r2 r4 @ <T3 | a=53, b=28, z=81 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | add r5 r2 r4 @ >T3 | r5=81 | r5=%0d", _cpu._rf.data[5]);

		// sub r5, r2, r4
		next_instruction(5, "sub r5 r2 r4", 32'h22920000);
		alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_sub <= 1'b1;
		#5 $display("Test | sub r5 r2 r4 @ <T3 | a=53, b=28, z=25 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | sub r5 r2 r4 @ >T3 | r5=25 | r5=%0d", _cpu._rf.data[5]);

		// shr r5, r2, r4
		next_instruction(6, "shr r5 r2 r4", 32'h2a920000);
		alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_shr <= 1'b1;
		#5 $display("Test | shr r5 r2 r4 @ <T3 | a=53, b=28, z=0 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | shr r5 r2 r4 @ >T3 | r5=0 | r5=%0d", _cpu._rf.data[5]);

		// shl r5, r2, r4
		next_instruction(7, "shl r5 r2 r4", 32'h32920000);
		alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_shl <= 1'b1;
		#5 $display("Test | shl r5 r2 r4 @ <T3 | a=53, b=28, z=1342177280 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | shl r5 r2 r4 @ >T3 | r5=1342177280 | r5=%0d", _cpu._rf.data[5]);

		// ror r5, r2, r4
		next_instruction(8, "ror r5 r2 r4", 32'h3a920000);
		alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_ror <= 1'b1;
		#5 $display("Test | ror r5 r2 r4 @ <T3 | a=53, b=28, z=848 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | ror r5 r2 r4 @ >T3 | r5=848 | r5=%0d", _cpu._rf.data[5]);

		// rol r5, r2, r4
		next_instruction(9, "rol r5 r2 r4", 32'h42920000);
		alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_rol <= 1'b1;
		#5 $display("Test | rol r5 r2 r4 @ <T3 | a=53, b=28, z=1342177283 | a=%0d, b=%0d, z=%0d", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5 $display("Test | rol r5 r2 r4 @ >T3 | r5=1342177283 | r5=%0d", _cpu._rf.data[5]);

		// mul r2, r4
		next_instruction(10, "mul r2 r4", 32'h71200000);
		alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; alu_mul <= 1'b1; hi_en <= 1'b1; lo_en <= 1'b1;
		#5 $display("Test | mul r2 r4 @ <T3 | a=53, b=28 | a=%0d, b=%0d", _cpu._alu.a, _cpu._alu.b);
		#5 $display("Test | mul r2 r4 @ >T3 | hi=0, lo=1484 | hi=%0d, lo=%0d", _cpu._hi.d, _cpu._lo.d);

		// div r2, r4
		next_instruction(11, "div r2 r4", 32'h79200000);
		alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; alu_div <= 1'b1; hi_en <= 1'b1; lo_en <= 1'b1;
		#5 $display("Test | div r2 r4 @ <T3 | a=53, b=28 | a=%0d, b=%0d", _cpu._alu.a, _cpu._alu.b);
		#5 $display("Test | div r2 r4 @ >T3 | hi=25, lo=1 | hi=%0d, lo=%0d", _cpu._hi.d, _cpu._lo.d);

		// neg r5, r2
		next_instruction(12, "neg r5 r2", 32'h82900000);
		alu_a_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_neg <= 1'b1;
		#5 $display("Test | neg r5 r2 @ <T3 | a=53, z=-53 | a=%0d, z=%0d", _cpu._alu.a, $signed(_cpu._alu.z));
		#5 $display("Test | neg r5 r2 @ >T3 | r5=-53 | r5=%0d", $signed(_cpu._rf.data[5]));

		// not r5, r2
		next_instruction(13, "not r5 r2", 32'h8a900000);
		alu_a_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_not <= 1'b1;
		#5 $display("Test | not r5 r2 @ <T3 | a=0x00000035, z=0xffffffca | a=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.z);
		#5 $display("Test | not r5 r2 @ >T3 | r5=0xffffffca | r5=0x%h", _cpu._rf.data[5]);

		// ===================== PHASE 2 =========================== //

		// ld r1, 85
		next_instruction(14, "ld r1 85", 32'h00800055);

		// T3
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; ma_in_alu <= 1'b1; alu_add <= 1'b1;
		#5; $display("Test | ld r1 85 @ <T3 | a=0x00000000, b=0x00000055, z=0x00000055 | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | ld r1 85 @ >T3 | ma=0x00000055 | ma=0x%h", _cpu._ma.d);

		// T4
		control_reset();
		#10; $display("Test | ld r1 85 @ T4 | md=0x0000000a | md=0x%h", _cpu._memory.data_out);

		// T5
		control_reset(); rf_in_memory <= 1'b1;
		#10; $display("Test | ld r1 85 @ T5 | r1=0x0000000a | r1=0x%h", _cpu._rf.data[1]);


		// ld r0, 35(r1)
		next_instruction(15, "ld r0 35(r1)", 32'h00080023);

		// T3
		ma_in_alu <= 1'b1; alu_add <= 1'b1; alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1;
		#5; $display("Test | ld r0 35(r1) @ <T3 | a=0x0000000a, b=0x00000023, z=0x0000002d | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | ld r0 35(r1) @ >T3 | ma=0x0000002d | ma=0x%h", _cpu._ma.d);

		// T4
		control_reset();
		#10; $display("Test | ld r0 35(r1) @ T4 | md=0xdeadbeef | md=0x%h", _cpu._memory.data_out);

		// T5
		control_reset(); rf_in_memory <= 1'b1;
		#10; $display("Test | ld r0 35(r1) @ T5 | r0=0xdeadbeef | r0=0x%h", _cpu._rf.data[0]);


		// ldi r1, 85
		next_instruction(16, "ldi r1 85", 32'h08800055);

		// T3
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5; $display("Test | ldi r1 85 @ <T3 | a=0x00000000, b=0x00000055, z=0x00000055 | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | ldi r1 85 @ >T3 | r1=0x00000055 | r1=0x%h", _cpu._rf.data[1]);


		// ldi r0, 35(r1)
		next_instruction(17, "ldi r0 35(r1)", 32'h08080023);

		// T3
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5; $display("Test | ldi r0 35(r1) @ <T3 | a=0x00000055, b=0x00000023, z=0x00000078 | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | ldi r0 35(r1) @ >T3 | r0=0x00000078 | r0=0x%h", _cpu._rf.data[0]);


		// st 90, r1
		next_instruction(18, "st 90 r1", 32'h1080005a);

		// T3
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; ma_in_alu <= 1'b1; alu_add <= 1'b1;
		#5; $display("Test | st 90 r1 @ <T3 | a=0x00000000, b=0x0000005a, z=0x0000005a | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | st 90 r1 @ >T3 | ma=0x0000005a | ma=0x%h", _cpu._ma.d);

		// T4
		control_reset(); memory_en <= 1'b1;
		#5; $display("Test | st 90 r1 @ <T4 | m_in=0x00000055 | m_in=0x%h", _cpu._memory.data_in);
		#5; $display("Test | st 90 r1 @ >T4 | m[90]=0x00000055 | m[90]=0x%h", _cpu._memory.data[90]);


		// st 90(r1), r1
		next_instruction(19, "st 90(r1) r1", 32'h1088005a);

		// T3
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; ma_in_alu <= 1'b1; alu_add <= 1'b1;
		#5; $display("Test | st 90(r1) r1 @ <T3 | a=0x00000055, b=0x0000005a, z=0x000000af | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | st 90(r1) r1 @ >T3 | ma=0x000000af | ma=0x%h", _cpu._ma.d);

		// T4
		control_reset(); memory_en <= 1'b1;
		#5; $display("Test | st 90(r1) r1 @ <T4 | m_in=0x00000055 | m_in=0x%h", _cpu._memory.data_in);
		#5; $display("Test | st 90(r1) r1 @ >T4 | m[175]=0x00000055 | m[175]=0x%h", _cpu._memory.data[175]);


		// addi r2, r1, -5
		next_instruction(20, "addi r2 r1 -5", 32'h590ffffb);

		// T3
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5; $display("Test | addi r2 r1 -5 @ <T3 | a=0x00000055, b=0xfffffffb, z=0x00000050 | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | addi r2 r1 -5 @ >T3 | r2=0x00000050 | r2=0x%h", _cpu._rf.data[2]);


		// andi r2, r1, 26
		next_instruction(21, "andi r2 r1 26", 32'h6108001a);

		// T3
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_and <= 1'b1;
		#5; $display("Test | andi r2 r1 26 @ <T3 | a=0x00000055, b=0x0000001a, z=0x00000010 | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | andi r2 r1 26 @ >T3 | r2=0x00000010 | r2=0x%h", _cpu._rf.data[2]);


		// ori r2, r1, 26
		next_instruction(22, "ori r2 r1 26", 32'h6908001a);

		// T3
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_or <= 1'b1;
		#5; $display("Test | ori r2 r1 26 @ <T3 | a=0x00000055, b=0x0000001a, z=0x0000005f | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | ori r2 r1 26 @ >T3 | r2=0x0000005f | r2=0x%h", _cpu._rf.data[2]);


		// brzr r2, 35
		next_instruction(23, "brzr r2 35", 32'h91000023);

		// T3
		// Condition is false, so expect pc to remain the same
		alu_a_in_pc <= 1'b1; alu_b_in_constant <= 1'b1; pc_in_alu <= branch_condition; alu_add <= 1'b1;
		#5; $display("Test | brzr r2 35 @ <T3 | a=0x00000018, b=0x00000023, z=0x0000003b | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | brzr r2 35 @ >T3 | br_cond=0x0, pc=0x00000018 | br_cond=0x%h, pc=0x%h", branch_condition, _cpu._pc.d);


		// brnz r2, 35
		next_instruction(24, "brnz r2 35", 32'h91080023);

		// T3
		// Condition is true, so expect pc to go up
		alu_a_in_pc <= 1'b1; alu_b_in_constant <= 1'b1; pc_in_alu <= branch_condition; alu_add <= 1'b1;
		#5; $display("Test | brnz r2 35 @ <T3 | a=0x00000019, b=0x00000023, z=0x0000003c | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | brnz r2 35 @ >T3 | br_cond=0x1, pc=0x0000003c | br_cond=0x%h, pc=0x%h", branch_condition, _cpu._pc.d);

		// Reset PC after last branch (brnz r2 -36 @ pc = 60 = 0x3c)
		next_instruction(60, "brnz r2 -36", 32'h910fffdc);
		alu_a_in_pc <= 1'b1; alu_b_in_constant <= 1'b1; pc_in_alu <= branch_condition; alu_add <= 1'b1;
		#5; $display("Test | brnz r2 -36 @ <T3 | a=0x0000003d, b=0xffffffdc, z=0x00000019 | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | brnz r2 -36 @ >T3 | br_cond=0x1, pc=0x00000019 | br_cond=0x%h, pc=0x%h", branch_condition, _cpu._pc.d);


		// brpl r2, 35
		next_instruction(25, "brpl r2 35", 32'h91100023);

		// T3
		// Condition is true, so expect pc to go up
		alu_a_in_pc <= 1'b1; alu_b_in_constant <= 1'b1; pc_in_alu <= branch_condition; alu_add <= 1'b1;
		#5; $display("Test | brpl r2 35 @ <T3 | a=0x0000001a, b=0x00000023, z=0x0000003d | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | brpl r2 35 @ >T3 | br_cond=0x1, pc=0x0000003d | br_cond=0x%h, pc=0x%h", branch_condition, _cpu._pc.d);

		// Reset PC after last branch (brpl r2 -36 @ pc = 61 = 0x3d)
		next_instruction(61, "brpl r2 -36", 32'h9117ffdc);
		alu_a_in_pc <= 1'b1; alu_b_in_constant <= 1'b1; pc_in_alu <= branch_condition; alu_add <= 1'b1;
		#5; $display("Test | brpl r2 -36 @ <T3 | a=0x0000003e, b=0xffffffdc, z=0x0000001a | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | brpl r2 -36 @ >T3 | br_cond=0x1, pc=0x0000001a | br_cond=0x%h, pc=0x%h", branch_condition, _cpu._pc.d);


		// brmi r2, 35
		next_instruction(26, "brmi r2 35", 32'h91180023);

		// T3
		// Condition is false, so expect pc to remain the same
		alu_a_in_pc <= 1'b1; alu_b_in_constant <= 1'b1; pc_in_alu <= branch_condition; alu_add <= 1'b1;
		#5; $display("Test | brmi r2 35 @ <T3 | a=0x0000001b, b=0x00000023, z=0x0000003e | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | brmi r2 35 @ >T3 | br_cond=0x0, pc=0x0000001b | br_cond=0x%h, pc=0x%h", branch_condition, _cpu._pc.d);


		// Non-test instruction, to set up r1 for next jr r1 (ldi r1, 62)
		next_instruction(27, "ldi r1, 62", 32'h0880003e);
		alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5; $display("Test | ldi r1 62 @ <T3 | a=0x00000000, b=0x0000003e, z=0x0000003e | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | ldi r1 62 @ >T3 | r1=0x0000003e | r1=0x%h", _cpu._rf.data[1]);

		// jal r1
		next_instruction(28, "jal r1", 32'ha0800000);

		// T3
		// Two things happen: PC <- rX, and r15 <- PC.
		// Latter step must go through alu, so if we don't set alu_b_in_x, default to 32'b0
		pc_in_rf_a <= 1'b1;
		alu_a_in_pc <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#5; $display("Test | jal r1 @ <T3 | a=0x0000001d, b=0x00000000, z=0x0000001d | a=0x%h, b=0x%h, z=0x%h", _cpu._alu.a, _cpu._alu.b, _cpu._alu.z);
		#5; $display("Test | jal r1 @ >T3 | r15=0x0000001d, rf_a_out=0x0000003e, pc=0x0000003e | r15=0x%h, rf_a_out=0x%h, pc=0x%h", _cpu._rf.data[15], _cpu.rf_a_out, _cpu._pc.d);


		// jr r15
		next_instruction(62, "jr r15", 32'h9f800000);

		// T3
		pc_in_rf_a <= 1'b1;
		#10; $display("Test | jr r15 @ T3 | rf_a_out=0x0000001d, pc=0x0000001d | rf_a_out=0x%h, pc=0x%h", _cpu.rf_a_out, _cpu._pc.d);


		// mfhi r2
		next_instruction(29, "mfhi r2", 32'hb9000000);

		// T3
		rf_in_hi <= 1'b1;
		#10; $display("Test | mfhi r2 @ T3 | r2=0x00000019 | r2=0x%h", _cpu._rf.data[2]);


		// mfhi r2
		next_instruction(30, "mflo r2", 32'hc1000000);

		// T3
		rf_in_lo <= 1'b1;
		#10; $display("Test | mflo r2 @ T3 | r2=0x00000001 | r2=0x%h", _cpu._rf.data[2]);


		// out r1
		next_instruction(31, "out r1", 32'hb0800000);

		// T3
		output_en <= 1'b1;
		#10; $display("Test | out r1 @ T3 | r1=0x0000003e, output_out=0x0000003e | r1=0x%h, output_out=0x%h", _cpu._rf.data[1], _cpu._out.d);


		// in r1
		next_instruction(32, "in r1", 32'ha8800000);

		// T3
		rf_in_input <= 1'b1;
		#5; $display("Test | in r1 @ <T3 | input_out=0x55555555 | input_out=0x%h", _cpu._in.d);
		#5; $display("Test | in r1 @ >T3 | r1=0x55555555 | r1=0x%h", _cpu._rf.data[1]);


		$finish;
	end
endmodule
