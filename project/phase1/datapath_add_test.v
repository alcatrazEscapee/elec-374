`timescale 1ns/100ps
module datapath_add_test;

	// Control Signals
	reg ir_en;
	reg pc_increment, pc_in_alu, pc_in_rf_a;
	reg ma_in_pc, ma_in_alu;
	reg md_in_memory, md_in_rf_b;
	reg alu_a_in_rf, alu_a_in_pc;
	reg alu_b_in_rf, alu_b_in_constant;
	reg lo_en, hi_en;
	reg rf_in_alu, rf_in_hi, rf_in_lo, rf_in_md;
	
	reg [3:0] rf_a_addr, rf_b_addr, rf_z_addr;
	
	reg [11:0] alu_select;
	reg [31:0] constant_c, data_from_memory;
	wire [31:0] address_to_memory, data_to_memory, ir_out;
	
	reg clk, clr;
	
	datapath _datapath (
		.ir_en(ir_en),
		.pc_increment(pc_increment), .pc_in_alu(pc_in_alu), .pc_in_rf_a(pc_in_rf_a),
		.ma_in_pc(ma_in_pc), .ma_in_alu(ma_in_alu),
		.md_in_memory(md_in_memory), .md_in_rf_b(md_in_rf_b),
		.alu_a_in_rf(alu_a_in_rf), .alu_a_in_pc(alu_a_in_pc),
		.alu_b_in_rf(alu_b_in_rf), .alu_b_in_constant(alu_b_in_constant),
		.lo_en(lo_en), .hi_en(hi_en),
		.rf_in_alu(rf_in_alu), .rf_in_hi(rf_in_hi), .rf_in_lo(rf_in_lo), .rf_in_md(rf_in_md),
		.rf_a_addr(rf_a_addr), .rf_b_addr(rf_b_addr), .rf_z_addr(rf_z_addr),
		.alu_select(alu_select), .constant_c(constant_c),
		.data_from_memory(data_from_memory), .data_to_memory(data_to_memory), .address_to_memory(address_to_memory),
		.ir_out(ir_out), .clk(clk), .clr(clr)
	);
	
	// Clock
	initial begin
		clk <= 1'b1;
		forever #5 clk <= ~clk;
	end
	
	// add r5, r2, r4
	initial begin
		// Zero all inputs
		ir_en <= 1'b0;
		pc_increment <= 1'b0; pc_in_alu <= 1'b0; pc_in_rf_a <= 1'b0;
		ma_in_pc <= 1'b0; ma_in_alu <= 1'b0;
		md_in_memory <= 1'b0; md_in_rf_b <= 1'b0;
		alu_a_in_rf <= 1'b0; alu_a_in_pc <= 1'b0;
		alu_b_in_rf <= 1'b0; alu_b_in_constant <= 1'b0;
		lo_en <= 1'b0; hi_en <= 1'b0;
		rf_in_alu <= 1'b0; rf_in_hi <= 1'b0; rf_in_lo <= 1'b0; rf_in_md <= 1'b0;
		rf_a_addr <= 4'b0; rf_b_addr <= 4'b0; rf_z_addr <= 4'b0;
		alu_select <= 11'b0; constant_c <= 32'b0;
		data_from_memory <= 32'b0;
		
		// Start
		clr <= 1'b1;
		#1
		
		// Load MD
		md_in_memory = 1'b1; data_from_memory <= 53;
		#10
		
		// Load r2
		md_in_memory = 1'b0; data_from_memory <= 0;
		rf_in_md <= 1'b1; rf_z_addr <= 4'b10; // r2 = 53
		#10
		
		// Load MD
		rf_in_md <= 1'b0; rf_z_addr <= 4'b0;
		md_in_memory = 1'b0; data_from_memory <= 28;
		#10
		
		// Load r4
		md_in_memory = 1'b0; data_from_memory <= 0;
		rf_in_md <= 1'b1; rf_z_addr <= 4'b100; // r4 = 28
		#10
		
		// Clear
		rf_in_md <= 1'b0; rf_z_addr <= 4'b0;
		#10
		
		// Simulate
		
		// T0
		pc_increment <= 1'b1; ma_in_pc <= 1'b1;
		#10
		
		// T1
		pc_increment <= 1'b0; ma_in_pc <= 1'b0;
		data_from_memory <= 32'b00011_0101_0010_0100_000000000000000;
		#10
		
		// T2
		data_from_memory <= 32'b0;
		ir_en <= 1'b1;
		#10
		
		// T3
		ir_en <= 1'b0;
		rf_z_addr <= 4'b0101; rf_a_addr <= 4'b0010; rf_b_addr <= 4'b0100; alu_a_in_rf <= 1'b1; alu_b_in_rf <= 1'b1; rf_in_alu <= 1'b1; alu_select <= 1'b0000000001;
		#10;
	end
endmodule
