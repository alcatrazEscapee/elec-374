module cpu;

	// Control Signals
	wire ir_en;
	wire pc_increment, pc_in_alu, pc_in_rf_a;
	wire ma_in_pc, ma_in_alu;
	wire md_in_memory, md_in_rf_b;
	wire alu_a_in_rf, alu_a_in_pc;
	wire alu_b_in_rf, alu_b_in_constant;
	wire lo_en;
	wire hi_en;
	wire rf_in_alu, rf_in_hi, rf_in_lo, rf_in_md;
	
	wire [3:0] rf_a_addr;
	wire [3:0] rf_b_addr;
	wire [3:0] rf_z_addr;
	
	wire [11:0] alu_select;
	
	// Memory Interface
	wire [31:0] data_from_memory;
	wire [31:0] address_to_memory;
	wire [31:0] data_to_memory;
	
	// To Control Logic
	wire [31:0] ir_out;
	
	// Standard
	wire clk, clr;
	
	datapath _datapath (
		// Control Signals
		ir_en,
		pc_increment, pc_in_alu, pc_in_rf_a,
		ma_in_pc, ma_in_alu,
		md_in_memory, md_in_rf_b,
		alu_a_in_rf, alu_a_in_pc,
		alu_b_in_rf, alu_b_in_constant,
		lo_en,
		hi_en,
		rf_in_alu, rf_in_hi, rf_in_lo, rf_in_md,
		
		rf_a_addr,
		rf_b_addr,
		rf_z_addr,
		
		alu_select,
		
		// Memory Interface
		data_from_memory,
		address_to_memory,
		data_to_memory,
		
		// To Control Logic
		ir_out,
		
		// Standard
		clk, clr
	);

endmodule
