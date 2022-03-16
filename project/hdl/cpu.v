/**
 * cpu: top-level module for the CPU.
 */
module cpu (
	// I/O
	input [31:0] input_in,
	output [31:0] output_out,

	// Weird?
	input input_en,
	
	// Standard
	input clk,
	input clr,
	input halt,
	
	// Status
	output is_halted
);
	localparam MEMORY_WORDS = 512;
	localparam MEMORY_BITS = $clog2(MEMORY_WORDS);
	
	// === Status Signals ===
	// run indicates whether the CPU is running (1) or is halted (0)
	// (defined in inputs)

	// === Control Signals ===
	// foo_en = Enable signal for writing to foo
	// foo_in_bar = Enable signal for writing foo <= bar
	wire ir_en;
	wire pc_en, pc_increment, pc_in_alu, pc_in_rf_a;
	wire ma_en;
	wire memory_addr_in_pc, memory_addr_in_ma;
	wire alu_a_in_rf, alu_a_in_rf_non_zero, alu_a_in_pc;
	wire alu_b_in_rf, alu_b_in_constant;
	wire lo_en;
	wire hi_en;
	wire rf_en, rf_in_alu, rf_in_hi, rf_in_lo, rf_in_memory, rf_in_fpu, rf_in_input;
	wire output_en;
	wire memory_en;

	wire [11:0] alu_select;
	wire [9:0] fpu_select;
	wire fpu_mode; // 0 = ALU, 1 = FPU
	
	// === Datpath ===
	// Based on the 3-Bus Architecture
	// We can exclude the A, B, Y and Z registers
	// Memory has a built-in MD register (in inferred Quartus memory), so we exclude that as well
	wire [31:0] pc_out, ir_out, ma_out, hi_out, lo_out, rf_a_out, rf_b_out, alu_z_out, alu_lo_out, alu_hi_out, constant_c, input_out, fpu_bridge_alu_a, fpu_bridge_alu_b, fpu_rz_out;
	reg [31:0] pc_in, alu_a_in, alu_b_in, rf_in;

   reg branch_condition;

	// Memory Interface
	// We don't need memory_in because it's always hard-wired to rf_b_out
	// In T0, the PC is used to fetch memory address, in T4, the MA register is (for load + store instructions)
	wire [31:0] memory_out;
	reg [MEMORY_BITS - 1:0] memory_address;
	
	always @(*) begin
		case ({memory_addr_in_pc, memory_addr_in_ma})
			2'b01 : memory_address = ma_out[8:0];
			2'b10 : memory_address = pc_out[8:0];
			default : memory_address = 9'b0;
		endcase
	end

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
			3'b001 : pc_in = rf_a_out;
			3'b010 : pc_in = alu_z_out;
			3'b100 : pc_in = pc_plus_1;
			default : pc_in = 32'b0;
		endcase
	end

	// IR Decoding
	wire [4:0] ir_opcode;
	wire [3:0] ir_ra, ir_rb_or_c2, ir_rc;
	wire [18:0] ir_constant_c;
	wire [3:0] ir_fpu_opcode;

	assign ir_opcode     = ir_out[31:27];
	assign ir_ra         = ir_out[26:23];
	assign ir_rb_or_c2   = ir_out[22:19];
	assign ir_rc         = ir_out[18:15];
	assign ir_constant_c = ir_out[18:0];
	assign ir_fpu_opcode = ir_out[3:0];

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
			default : branch_condition = 1'b0;
		endcase
	end

	// ALU Inputs
	// Left input can be PC, rY, or driven by FPU
	// Right input can be rX, constant C, or driven by FPU
	// Control Signals: alu_a_in_rf, alu_a_in_pc, alu_b_in_rf, alu_b_in_constant
	always @(*) begin
		case ({fpu_mode, alu_a_in_rf_non_zero, alu_a_in_rf, alu_a_in_pc})
			4'b0001 : alu_a_in = pc_out;
			4'b0010 : alu_a_in = rf_a_out;
			4'b0100 : alu_a_in = rf_a_addr == 4'b0 ? 32'b0 : rf_a_out; // Used for ldi, since r0 indicates zero
			4'b1000 : alu_a_in = fpu_bridge_alu_a;
			default : alu_a_in = 32'b0;
		endcase

		case ({fpu_mode, alu_b_in_rf, alu_b_in_constant})
			3'b001 : alu_b_in = constant_c;
			3'b010 : alu_b_in = rf_b_out;
			3'b100 : alu_b_in = fpu_bridge_alu_b;
			default : alu_b_in = 32'b0;
		endcase
	end

	// RF Inputs
	// Input can by any of ALU Z, HI, LO, Memory, INPUT, or FPU
	assign rf_en = rf_in_alu | rf_in_hi | rf_in_lo | rf_in_memory | rf_in_input | rf_in_fpu;

	always @(*) begin
		case ({rf_in_input, rf_in_fpu, rf_in_alu, rf_in_hi, rf_in_lo, rf_in_memory})
			6'b000001 : rf_in = memory_out;
			6'b000010 : rf_in = lo_out;
			6'b000100 : rf_in = hi_out;
			6'b001000 : rf_in = alu_z_out;
			6'b010000 : rf_in = fpu_rz_out;
			6'b100000 : rf_in = input_out;
			default : rf_in = 32'b0;
		endcase
	end

	register_file #( .BITS(32), .WORDS(16) ) _rf (
		.data_in(rf_in),
		.addr_in(rf_z_addr),
		.addr_a(rf_a_addr),
		.addr_b(rf_b_addr),
		.data_a(rf_a_out),
		.data_b(rf_b_out),
		.clk(clk),
		.clr(clr),
		.en(rf_en)
	);

	register _pc  ( .d(pc_in),      .q(pc_out),     .en(pc_en),     .clk(clk), .clr(clr) );
	register _ir  ( .d(memory_out), .q(ir_out),     .en(ir_en),     .clk(clk), .clr(clr) ); // IR in = Memory
	register _ma  ( .d(alu_z_out),  .q(ma_out),     .en(ma_en),     .clk(clk), .clr(clr) ); // MA in = ALU out (T0 bypasses)
	register _hi  ( .d(alu_hi_out), .q(hi_out),     .en(hi_en),     .clk(clk), .clr(clr) ); // HI and LO in = ALU out
	register _lo  ( .d(alu_lo_out), .q(lo_out),     .en(lo_en),     .clk(clk), .clr(clr) );
	register _in  ( .d(input_in),   .q(input_out),  .en(input_en),  .clk(clk), .clr(clr) ); // IN and OUT
	register _out ( .d(rf_a_out),   .q(output_out), .en(output_en), .clk(clk), .clr(clr) );

	memory #( .BITS(32), .WORDS(MEMORY_WORDS) ) _memory (
		.address(memory_address),
		.data_in(rf_b_out), // Data to Memory = RF B Out
		.data_out(memory_out),
		.en(memory_en),
		.clk(clk)
	);

	alu _alu (
		.a(alu_a_in),
		.b(alu_b_in),
		.z(alu_z_out),
		.hi(alu_hi_out),
		.lo(alu_lo_out),
		.select(alu_select),
		.divide_by_zero(), // todo: exception handling
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
		.cast_out_of_bounds(), // todo: exception handling
		.cast_undefined(),
		.alu_a(fpu_bridge_alu_a),
		.alu_b(fpu_bridge_alu_b),
		.alu_hi(alu_hi_out),
		.alu_lo(alu_lo_out),
		.clk(clk),
		.clr(clr)
	);

	control_unit _control (
		// Inputs
		.opcode(ir_opcode),
		.fpu_opcode(ir_fpu_opcode),
		.branch_condition(branch_condition),

		// Control Signals
		.ir_en(ir_en),
		.pc_increment(pc_increment), .pc_in_alu(pc_in_alu), .pc_in_rf_a(pc_in_rf_a),
		.ma_en(ma_en),
		.memory_addr_in_ma(memory_addr_in_ma), .memory_addr_in_pc(memory_addr_in_pc),
		.alu_a_in_rf(alu_a_in_rf), .alu_a_in_rf_non_zero(alu_a_in_rf_non_zero), .alu_a_in_pc(alu_a_in_pc),
		.alu_b_in_rf(alu_b_in_rf), .alu_b_in_constant(alu_b_in_constant),
		.lo_en(lo_en), .hi_en(hi_en),
		.rf_in_alu(rf_in_alu), .rf_in_hi(rf_in_hi), .rf_in_lo(rf_in_lo), .rf_in_memory(rf_in_memory), .rf_in_fpu(rf_in_fpu), .rf_in_input(rf_in_input),
		.output_en(output_en),
		.memory_en(memory_en),

		.alu_select(alu_select),
		.fpu_select(fpu_select),
		.fpu_mode(fpu_mode), // 0 = ALU, 1 = FPU

		.clk(clk), .clr(clr), .halt(halt),
		.is_halted(is_halted)
	);

endmodule


/**
 * Testbench
 * Simulates various instructions by manually wiring in the correct control signals
 */
`timescale 1ns/100ps
module cpu_test;

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
		$readmemh("out/phase3_testbench.mem", _cpu._memory.data);
		
		while (~is_halted) begin
			$display("PC = %0d, r0=%0h, r3=%h, r4=%0h, r7=%0h, ma=%h, rf_b=%0h, m[58]=%0h, addr=%0h, madr_ma=%b, men=%b", _cpu._pc.q, _cpu._rf.data[0], _cpu._rf.data[3], _cpu._rf.data[4], _cpu._rf.data[7], _cpu._ma.q, _cpu.rf_b_out, _cpu._memory.data[9'h66], _cpu.memory_address, _cpu.memory_addr_in_ma, _cpu.memory_en);
			#10;
		end
		
		$display("Test | r0  | r0  = 0x00000001 | r0  = 0x%h", _cpu._rf.data[0]);
		$display("Test | r1  | r1  = 0x0000019a | r1  = 0x%h", _cpu._rf.data[1]);
		$display("Test | r2  | r2  = 0x000000cd | r2  = 0x%h", _cpu._rf.data[2]);
		$display("Test | r3  | r3  = 0x00000001 | r3  = 0x%h", _cpu._rf.data[3]);
		$display("Test | r4  | r4  = 0x00000005 | r4  = 0x%h", _cpu._rf.data[4]);
		$display("Test | r5  | r5  = 0x0000001d | r5  = 0x%h", _cpu._rf.data[5]);
		$display("Test | r6  | r6  = 0x00000091 | r6  = 0x%h", _cpu._rf.data[6]);
		$display("Test | r7  | r7  = 0x00000000 | r7  = 0x%h", _cpu._rf.data[7]);
		$display("Test | r8  | r8  = 0x0000001f | r8  = 0x%h", _cpu._rf.data[8]);
		$display("Test | r9  | r9  = 0x00000077 | r9  = 0x%h", _cpu._rf.data[9]);
		$display("Test | r10 | r10 = 0x00000005 | r10 = 0x%h", _cpu._rf.data[10]);
		$display("Test | r11 | r11 = 0x0000001f | r11 = 0x%h", _cpu._rf.data[11]);
		$display("Test | r12 | r12 = 0x00000091 | r12 = 0x%h", _cpu._rf.data[12]);
		$display("Test | r13 | r13 = 0x00000000 | r13 = 0x%h", _cpu._rf.data[13]);
		$display("Test | r14 | r14 = 0x00000000 | r14 = 0x%h", _cpu._rf.data[14]);
		$display("Test | r15 | r15 = 0x00000028 | r15 = 0x%h", _cpu._rf.data[15]);
		
		$display("Test | Memory[0x58] | Memory[0x58] = 0x66 | Memory[0x58] = 0x%h", _cpu._memory.data[9'h66]);
		$display("Test | Memory[0x75] | Memory[0x75] = 0xcd | Memory[0x75] = 0x%h", _cpu._memory.data[9'h75]);
		
		$display("Test | HI, LO | HI = 0x00000004, LO = 0x00000005 | HI = 0x%h, LO = 0x%h", _cpu._hi.q, _cpu._lo.q);

		$finish;
	end
endmodule
