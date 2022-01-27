module cpu(
	// Control Signals
	input ir_en,
	input pc_increment, input pc_in_alu, input pc_in_rf_a,
	input ma_in_pc, input ma_in_alu,
	input md_in_memory, input md_in_rf_b,
	input alu_a_in_rf, input alu_a_in_pc,
	input alu_b_in_rf, input alu_b_in_constant,
	input lo_en,
	input hi_en,
	input rf_in_alu, input rf_in_hi, input rf_in_lo, input rf_in_md,
	
	input [3:0] rf_a_addr,
	input [3:0] rf_b_addr,
	input [3:0] rf_z_addr,
	
	input [11:0] alu_select, // {alu_add, alu_sub, alu_shr, alu_shl, alu_ror, alu_rol, alu_and, alu_or, alu_mul, alu_div, alu_neg, alu_not}
	input [31:0] constant_c, // Sign extended to 32-bit
	
	// Memory Interface
	input [31:0] data_from_memory,
	output [31:0] address_to_memory,
	output [31:0] data_to_memory,
	
	// To Control Logic
	input [31:0] ir_out,
	
	// Standard
	input clk,
	input clr
);

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

endmodule


module cpu_test;

	initial begin
		$finish;
	end
endmodule
