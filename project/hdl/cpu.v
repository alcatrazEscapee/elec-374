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
	input rf_in_alu, input rf_in_hi, input rf_in_lo, input rf_in_memory,
	input memory_en,

	input [11:0] alu_select,
	
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
	wire [31:0] pc_out, ma_out, hi_out, lo_out, rf_a_out, rf_b_out, alu_z_out, alu_lo_out, alu_hi_out, constant_c;
	reg [31:0] pc_in, ma_in, alu_a_in, alu_b_in, rf_in;
	
	wire pc_en, ma_en, rf_en;
	
	// Memory Interface
	wire [31:0] memory_out, memory_in;
	
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
	// Branch instructions use rA as a read register, not as a write one.
	assign rf_z_addr = ir_ra;
	assign rf_a_addr = ir_opcode == 5'b10010 ? ir_ra : ir_rb_or_c2;
	assign rf_b_addr = ir_rc;
	
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
	// Left input can be PC or rY
	// Right input can be rX or constant C
	// Control Signals: alu_a_in_rf, alu_a_in_pc, alu_b_in_rf, alu_b_in_constant
	always @(*) begin
		case ({alu_a_in_rf, alu_a_in_pc})
			2'b01 : alu_a_in <= pc_out;
			2'b10 : alu_a_in <= rf_a_out;
			default : alu_a_in <= 32'b0;
		endcase
		
		case ({alu_b_in_rf, alu_b_in_constant})
			2'b01 : alu_b_in <= constant_c;
			2'b10 : alu_b_in <= rf_b_out;
			default : alu_b_in <= 32'b0;
		endcase
	end
	
	// RF Inputs
	// Input can by any of ALU Z, HI, LO, Memory
	assign rf_en = rf_in_alu | rf_in_hi | rf_in_lo | rf_in_memory;
	
	always @(*) begin
		case ({rf_in_alu, rf_in_hi, rf_in_lo, rf_in_memory})
			4'b0001 : rf_in <= memory_out;
			4'b0010 : rf_in <= lo_out;
			4'b0100 : rf_in <= hi_out;
			4'b1000 : rf_in <= alu_z_out;
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
		.clk(clk)
	);
	
	register _pc ( .q(pc_in),      .d(pc_out), .en(pc_en), .clk(clk), .clr(clr) );
	register _ir ( .q(memory_out), .d(ir_out), .en(ir_en), .clk(clk), .clr(clr) ); // IR in = Memory
	register _ma ( .q(ma_in),      .d(ma_out), .en(ma_en), .clk(clk), .clr(clr) );
	register _hi ( .q(alu_hi_out), .d(hi_out), .en(hi_en), .clk(clk), .clr(clr) ); // HI and LO in = ALU out
	register _lo ( .q(alu_lo_out), .d(lo_out), .en(lo_en), .clk(clk), .clr(clr) );
	
	alu _alu ( .a(alu_a_in), .b(alu_b_in), .z(alu_z_out), .hi(alu_hi_out), .lo(alu_lo_out), .select(alu_select) );
	
	memory #( .BITS(32), .WORDS(512) ) _memory (
		.address(ma_out),
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
	reg rf_in_alu, rf_in_hi, rf_in_lo, rf_in_memory;
	reg memory_en;
		
	reg alu_not, alu_neg, alu_div, alu_mul, alu_or, alu_and, alu_rol, alu_ror, alu_shl, alu_shr, alu_sub, alu_add;
	
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
		.rf_in_alu(rf_in_alu), .rf_in_hi(rf_in_hi), .rf_in_lo(rf_in_lo), .rf_in_memory(rf_in_memory),
		.alu_select({alu_not, alu_neg, alu_div, alu_mul, alu_or, alu_and, alu_rol, alu_ror, alu_shl, alu_shr, alu_sub, alu_add}),
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
			rf_in_alu <= 1'b0; rf_in_hi <= 1'b0; rf_in_lo <= 1'b0; rf_in_memory <= 1'b0;
			memory_en <= 1'b0;
			{alu_not, alu_neg, alu_div, alu_mul, alu_or, alu_and, alu_rol, alu_ror, alu_shl, alu_shr, alu_sub, alu_add} <= 12'b0;
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
		$readmemh("out/cpu_testbench.mem", _dp._memory.data);
		
		// Initialize RF via two addi instructions
		// addi r2, r0, 53
		
		// T0
		pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10 $display("Test | addi r2 r0 53 @ T0 | pc=1, ma=0 | pc=%0d, ma=%0d", _dp._pc.d, _dp._ma.d);
		
		// T1
		control_reset();
		#10 $display("Test | addi r2 r0 53 @ T1 | md=0x59000035 | md=0x%h", _dp._memory.data_out);
		
		// T2
		control_reset(); ir_en <= 1'b1;
		#10 $display("Test | addi r2 r0 53 @ T2 | ir=0x59000035 | ir=0x%h", _dp._ir.d);
		
		// T3
		control_reset(); alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#10 $display("Test | addi r2 r0 53 @ T3 | a=0, b=53, z=53, r2=53 | a=%0d, b=%0d, z=%0d, r2=%0d", _dp._alu.a, _dp._alu.b, _dp._alu.z, _dp._rf.data[2]);
		
		// addi r4, r0, 28
		
		// T0
		control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10 $display("Test | addi r4 r0 28 @ T0 | pc=2, ma=1 | pc=%0d, ma=%0d", _dp._pc.d, _dp._ma.d);
		
		control_reset();
		#10 $display("Test | addi r4 r0 28 @ T1 | md=0x5a00001c | md=0x%h", _dp._memory.data_out);
		
		// T2
		control_reset(); ir_en <= 1'b1;
		#10 $display("Test | addi r4 r0 28 @ T2 | ir=0x5a00001c | ir=0x%h", _dp._ir.d);
		
		// T3
		control_reset(); alu_a_in_rf <= 1'b1; alu_b_in_constant <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#10 $display("Test | addi r4 r0 28 @ T3 | a=0, b=28, z=28, r4=28 | a=%0d, b=%0d, z=%0d, r4=%0d", _dp._alu.a, _dp._alu.b, _dp._alu.z, _dp._rf.data[4]);
				
		// and r5, r2, r4
		
		// T0
		control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10 $display("Test | and r5 r2 r4 @ T0 | pc=3, ma=2 | pc=%0d, ma=%0d", _dp._pc.d, _dp._ma.d);
		
		// T1
		control_reset();
		#10 $display("Test | and r5 r2 r4 @ T1 | md=0x4a920000 | md=0x%h", _dp._memory.data_out);
		
		// T2
		control_reset(); ir_en <= 1'b1;
		#10 $display("Test | and r5 r2 r4 @ T2 | ir=0x4a920000 | ir=0x%h", _dp._ir.d);
		
		// T3
		control_reset(); alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_and <= 1'b1;
		#10 $display("Test | and r5 r2 r4 @ T3 | a=53, b=28, z=20, r5=20 | a=%0d, b=%0d, z=%0d, r5=%0d", _dp._alu.a, _dp._alu.b, _dp._alu.z, _dp._rf.data[5]);
		
		// or r5, r2, r4
		
		// T0
		control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10 $display("Test | or r5 r2 r4 @ T0 | pc=4, ma=3 | pc=%0d, ma=%0d", _dp._pc.d, _dp._ma.d);
		
		// T1
		control_reset();
		#10 $display("Test | or r5 r2 r4 @ T1 | md=0x52920000 | md=0x%h", _dp._memory.data_out);
		
		// T2
		control_reset(); ir_en <= 1'b1;
		#10 $display("Test | or r5 r2 r4 @ T2 | ir=0x52920000 | ir=0x%h", _dp._ir.d);
		
		// T3
		control_reset(); alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_or <= 1'b1;
		#10 $display("Test | or r5 r2 r4 @ T3 | a=53, b=28, z=61, r5=61 | a=%0d, b=%0d, z=%0d, r5=%0d", _dp._alu.a, _dp._alu.b, _dp._alu.z, _dp._rf.data[5]);

		// add r5, r2, r4
		
		// T0
		control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10 $display("Test | add r5 r2 r4 @ T0 | pc=5, ma=4 | pc=%0d, ma=%0d", _dp._pc.d, _dp._ma.d);
		
		// T1
		control_reset();
		#10 $display("Test | add r5 r2 r4 @ T1 | md=0x1a920000 | md=0x%h", _dp._memory.data_out);
		
		// T2
		control_reset(); ir_en <= 1'b1;
		#10 $display("Test | add r5 r2 r4 @ T2 | ir=0x1a920000 | ir=0x%h", _dp._ir.d);
		
		// T3
		control_reset(); alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_add <= 1'b1;
		#10 $display("Test | add r5 r2 r4 @ T3 | a=53, b=28, z=81, r5=81 | a=%0d, b=%0d, z=%0d, r5=%0d", _dp._alu.a, _dp._alu.b, _dp._alu.z, _dp._rf.data[5]);
			
		// sub r5, r2, r4
		
		// T0
		control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10 $display("Test | sub r5 r2 r4 @ T0 | pc=6, ma=5 | pc=%0d, ma=%0d", _dp._pc.d, _dp._ma.d);
		
		// T1
		control_reset();
		#10 $display("Test | sub r5 r2 r4 @ T1 | md=0x22920000 | md=0x%h", _dp._memory.data_out);
		
		// T2
		control_reset(); ir_en <= 1'b1;
		#10 $display("Test | sub r5 r2 r4 @ T2 | ir=0x22920000 | ir=0x%h", _dp._ir.d);
		
		// T3
		control_reset(); alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_sub <= 1'b1;
		#10 $display("Test | sub r5 r2 r4 @ T3 | a=53, b=28, z=25, r5=25 | a=%0d, b=%0d, z=%0d, r5=%0d", _dp._alu.a, _dp._alu.b, _dp._alu.z, _dp._rf.data[5]);
		
		// shr r5, r2, r4
		
		// T0
		control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10 $display("Test | shr r5 r2 r4 @ T0 | pc=7, ma=6 | pc=%0d, ma=%0d", _dp._pc.d, _dp._ma.d);
		
		// T1
		control_reset();
		#10 $display("Test | shr r5 r2 r4 @ T1 | md=0x2a920000 | md=0x%h", _dp._memory.data_out);
		
		// T2
		control_reset(); ir_en <= 1'b1;
		#10 $display("Test | shr r5 r2 r4 @ T2 | ir=0x2a920000 | ir=0x%h", _dp._ir.d);
		
		// T3
		control_reset(); alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_shr <= 1'b1;
		#10 $display("Test | shr r5 r2 r4 @ T3 | a=53, b=28, z=0, r5=0 | a=%0d, b=%0d, z=%0d, r5=%0d", _dp._alu.a, _dp._alu.b, _dp._alu.z, _dp._rf.data[5]);
		
		
		// shl r5, r2, r4
		
		// T0
		control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10 $display("Test | shl r5 r2 r4 @ T0 | pc=8, ma=7 | pc=%0d, ma=%0d", _dp._pc.d, _dp._ma.d);
		
		// T1
		control_reset();
		#10 $display("Test | shl r5 r2 r4 @ T1 | md=0x32920000 | md=0x%h", _dp._memory.data_out);
		
		// T2
		control_reset(); ir_en <= 1'b1;
		#10 $display("Test | shl r5 r2 r4 @ T2 | ir=0x32920000 | ir=0x%h", _dp._ir.d);
		
		// T3
		control_reset(); alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_shl <= 1'b1;
		#10 $display("Test | shl r5 r2 r4 @ T3 | a=53, b=28, z=1342177280, r5=1342177280 | a=%0d, b=%0d, z=%0d, r5=%0d", _dp._alu.a, _dp._alu.b, _dp._alu.z, _dp._rf.data[5]);
		
		// ror r5, r2, r4
		
		// T0
		control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10 $display("Test | ror r5 r2 r4 @ T0 | pc=9, ma=8 | pc=%0d, ma=%0d", _dp._pc.d, _dp._ma.d);
		
		// T1
		control_reset();
		#10 $display("Test | ror r5 r2 r4 @ T1 | md=0x3a920000 | md=0x%h", _dp._memory.data_out);
		
		// T2
		control_reset(); ir_en <= 1'b1;
		#10 $display("Test | ror r5 r2 r4 @ T2 | ir=0x3a920000 | ir=0x%h", _dp._ir.d);
		
		// T3
		control_reset(); alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_ror <= 1'b1;
		#10 $display("Test | ror r5 r2 r4 @ T3 | a=53, b=28, z=848, r5=848 | a=%0d, b=%0d, z=%0d, r5=%0d", _dp._alu.a, _dp._alu.b, _dp._alu.z, _dp._rf.data[5]);
		
		// rol r5, r2, r4
		
		// T0
		control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10 $display("Test | rol r5 r2 r4 @ T0 | pc=10, ma=9 | pc=%0d, ma=%0d", _dp._pc.d, _dp._ma.d);
		
		// T1
		control_reset();
		#10 $display("Test | rol r5 r2 r4 @ T1 | md=0x42920000 | md=0x%h", _dp._memory.data_out);
		
		// T2
		control_reset(); ir_en <= 1'b1;
		#10 $display("Test | rol r5 r2 r4 @ T2 | ir=0x42920000 | ir=0x%h", _dp._ir.d);
		
		// T3
		control_reset(); alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_rol <= 1'b1;
		#10 $display("Test | rol r5 r2 r4 @ T3 | a=53, b=28, z=1342177283, r5=1342177283 | a=%0d, b=%0d, z=%0d, r5=%0d", _dp._alu.a, _dp._alu.b, _dp._alu.z, _dp._rf.data[5]);
		
		
		// mul r2, r4
		
		// T0
		control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10 $display("Test | mul r2 r4 @ T0 | pc=11, ma=10 | pc=%0d, ma=%0d", _dp._pc.d, _dp._ma.d);
		
		// T1
		control_reset();
		#10 $display("Test | mul r2 r4 @ T1 | md=0x70120000 | md=0x%h", _dp._memory.data_out);
		
		// T2
		control_reset(); ir_en <= 1'b1;
		#10 $display("Test | mul r2 r4 @ T2 | ir=0x70120000 | ir=0x%h", _dp._ir.d);
		
		// T3
		control_reset(); alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; alu_mul <= 1'b1; hi_en <= 1'b1; lo_en <= 1'b1;
		#10 $display("Test | mul r2 r4 @ T3 | a=53, b=28, hi=0, lo=1484 | a=%0d, b=%0d, hi=%0d, lo=%0d", _dp._alu.a, _dp._alu.b, _dp._hi.d, _dp._lo.d);
		
		
		// div r2, r4
		
		// T0
		control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10 $display("Test | div r2 r4 @ T0 | pc=12, ma=11 | pc=%0d, ma=%0d", _dp._pc.d, _dp._ma.d);
		
		// T1
		control_reset();
		#10 $display("Test | div r2 r4 @ T1 | md=0x78120000 | md=0x%h", _dp._memory.data_out);
		
		// T2
		control_reset(); ir_en <= 1'b1;
		#10 $display("Test | div r2 r4 @ T2 | ir=0x78120000 | ir=0x%h", _dp._ir.d);
		
		// T3
		control_reset(); alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; alu_div <= 1'b1; hi_en <= 1'b1; lo_en <= 1'b1;
		#10 $display("Test | div r2 r4 @ T3 | a=53, b=28, hi=25, lo=1 | a=%0d, b=%0d, hi=%0d, lo=%0d", _dp._alu.a, _dp._alu.b, _dp._hi.d, _dp._lo.d);
	
		// neg r5, r2
		
		// T0
		control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10 $display("Test | neg r5 r2 @ T0 | pc=13, ma=12 | pc=%0d, ma=%0d", _dp._pc.d, _dp._ma.d);
		
		// T1
		control_reset();
		#10 $display("Test | neg r5 r2 @ T1 | md=0x82900000 | md=0x%h", _dp._memory.data_out);
		
		// T2
		control_reset(); ir_en <= 1'b1;
		#10 $display("Test | neg r5 r2 @ T2 | ir=0x82900000 | ir=0x%h", _dp._ir.d);
		
		// T3
		control_reset(); alu_a_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_neg <= 1'b1;
		#10 $display("Test | neg r5 r2 @ T3 | a=53, z=-53, r5=-53 | a=%0d, z=%0d, r5=%0d", _dp._alu.a, $signed(_dp._alu.z), $signed(_dp._rf.data[5]));
		
		// not r5, r2
		
		// T0
		control_reset(); pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10 $display("Test | not r5 r2 @ T0 | pc=14, ma=13 | pc=%0d, ma=%0d", _dp._pc.d, _dp._ma.d);
		
		// T1
		control_reset();
		#10 $display("Test | not r5 r2 @ T1 | md=0x8a900000 | md=0x%h", _dp._memory.data_out);
		
		// T2
		control_reset(); ir_en <= 1'b1;
		#10 $display("Test | not r5 r2 @ T2 | ir=0x8a900000 | ir=0x%h", _dp._ir.d);
		
		// T3
		control_reset(); alu_a_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_not <= 1'b1;
		#10; $display("Test | not r5 r2 @ T3 | a=0x00000035, z=0xffffffca, r5=0xffffffca | a=0x%h, z=0x%h, r5=0x%h", _dp._alu.a, _dp._alu.z, _dp._rf.data[5]);
		
		$finish;
	end
endmodule
