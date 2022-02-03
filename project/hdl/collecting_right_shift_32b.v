module collecting_right_shift_32b (
	input [31:0] in,
	input [31:0] shift,
	output [31:0] out,
	output collector
);
	wire [31:0] shift_1, shift_2, shift_4, shift_8, shift_16;
	wire collect_1, collect_2, collect_4, collect_8, collect_16;
	
	// The shift amount is a 32 bit (unsigned) value
	// If ANY of the upper 26 bits are 1, then the shift value is >= 32, and we immediately infer that the output must be 0
	wire shift_out_of_bounds;
	assign shift_out_of_bounds = | shift[31:5];
	
	assign shift_1 = shift[0] ? { 1'b0, in[31:1] } : in;
	assign shift_2 = shift[1] ? { 2'b0, shift_1[31:2] } : shift_1;
	assign shift_4 = shift[2] ? { 4'b0, shift_2[31:4] } : shift_2;
	assign shift_8 = shift[3] ? { 8'b0, shift_4[31:8] } : shift_4;
	assign shift_16 = shift[4] ? { 16'b0, shift_8[31:16] } : shift_8;
	assign out = shift_out_of_bounds ? 32'b0 : shift_16; // A shift of >=32 bits will always produce all zero output
	
	// Collect (or) the bits that were shifted off
	assign collect_1 = shift[0] ? in[0] : 1'b0;
	assign collect_2 = shift[1] ? | shift_1[1:0] : 1'b0;
	assign collect_4 = shift[2] ? | shift_2[3:0] : 1'b0;
	assign collect_8 = shift[3] ? | shift_4[7:0] : 1'b0;
	assign collect_16 = shift[4] ? | shift_8[15:0] : 1'b0;
	assign collector = collect_1 | collect_2 | collect_4 | collect_8 | collect_16 | (shift_out_of_bounds & (| in));
	
endmodule