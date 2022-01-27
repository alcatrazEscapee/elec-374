module datapath(
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
	// Based on the 3-Bus Architecture
	// We can exclude the A, B, Y and Z registers
	wire [31:0] pc_out, ma_out, md_out, hi_out, lo_out, rf_a_out, rf_b_out, alu_z_out, alu_lo_out, alu_hi_out;
	reg [31:0] pc_in, ma_in, md_in, alu_a_in, alu_b_in, rf_in;
	wire pc_en, ma_en, md_en, rf_en;
	
	// Additional register connections
	
	// PC Increment Logic
	// Control Signals: pc_increment, pc_in_alu, pc_in_rf_a
	// Inputs: PC + 4, PC + C, rX
	wire [31:0] pc_plus_4;
	wire pc_cout;
	
	ripple_carry_adder _pc_adder ( .a(pc_out), .b(32'b100), .sum(pc_plus_4), .c_in(1'b0), .c_out(pc_cout) ); // PC + 4
	
	assign pc_en = pc_increment | pc_in_alu | pc_in_rf_a;
	
	always @(*) begin
		case ({pc_increment, pc_in_alu, pc_in_rf_a})
			3'b001 : pc_in <= rf_a_out;
			3'b010 : pc_in <= alu_z_out;
			3'b100 : pc_in <= pc_plus_4;
			default : pc_in <= 32'b0;
		endcase
	end
	
	// MA Register
	// Control Signals: ma_in_pc, ma_in_alu
	assign ma_en = ma_in_pc | ma_in_alu;
	assign address_to_memory = ma_out;
	
	always @(*) begin
		case ({ma_in_pc, ma_in_alu})
			2'b01 : ma_in <= alu_z_out;
			2'b10 : ma_in <= pc_out;
			default : ma_in <= 32'b0;
		endcase
	end
	
	// MD Register
	// Control Signals: md_in_memory, md_in_rf_b
	// Inputs: Memory[MA], rX
	assign md_en = md_in_memory | md_in_rf_b;
	assign data_to_memory = md_out;
	
	always @(*) begin
		case ({md_in_memory, md_in_rf_b})
			2'b01 : md_in <= rf_b_out;
			2'b10 : md_in <= data_from_memory;
			default : md_in <= 32'b0;
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
	// Input can by any of ALU Z, HI, LO, MD	
	assign rf_en = rf_in_alu | rf_in_hi | rf_in_lo | rf_in_md;
	
	always @(*) begin
		case ({rf_in_alu, rf_in_hi, rf_in_lo, rf_in_md})
			4'b0001 : rf_in <= md_out;
			4'b0010 : rf_in <= lo_out;
			4'b0100 : rf_in <= hi_out;
			4'b1000 : rf_in <= alu_z_out;
			default : rf_in <= 32'b0;
		endcase
	end
		
	register_file _r0_to_r15 (
		.write_data(rf_in),
		.write_addr(rf_en ? rf_z_addr : 4'b0), // When not enabled, writes go to r0 (noop)
		.read_addr_a(rf_a_addr),
		.read_addr_b(rf_b_addr),
		.data_a(rf_a_out),
		.data_b(rf_b_out),
		.clk(clk),
		.clr(clr)
	);
	
	register _pc ( .q(pc_in),      .d(pc_out), .en(pc_en), .clk(clk), .clr(clr) );
	register _ir ( .q(md_out),     .d(ir_out), .en(ir_en), .clk(clk), .clr(clr) ); // IR in = MDR out
	register _ma ( .q(ma_in),      .d(ma_out), .en(ma_en), .clk(clk), .clr(clr) );
	register _md ( .q(md_in),      .d(md_out), .en(md_en), .clk(clk), .clr(clr) );
	register _hi ( .q(alu_hi_out), .d(hi_out), .en(hi_en), .clk(clk), .clr(clr) ); // HI and LO in = ALU out
	register _lo ( .q(alu_lo_out), .d(lo_out), .en(lo_en), .clk(clk), .clr(clr) );
	
	alu _alu ( .a(alu_a_in), .b(alu_b_in), .z(alu_z_out), .hi(alu_hi_out), .lo(alu_lo_out), .select(alu_select) );
	
endmodule
