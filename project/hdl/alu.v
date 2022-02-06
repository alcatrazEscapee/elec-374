module alu(
	input [31:0] a,
	input [31:0] b,
	input [11:0] select, // {alu_not, alu_neg, alu_div, alu_mul, alu_or, alu_and, alu_rol, alu_ror, alu_shl, alu_shr, alu_sub, alu_add}
	output reg [31:0] z, // Outputs for all other instructions
	output reg [31:0] hi, // Outputs for div, mul
	output reg [31:0] lo
);
	// ALU Operations (by select index)
	// 0 = Add
	// 1 = Sub
	// 2 = Shift Right
	// 3 = Shift Left
	// 4 = Rotate Right
	// 5 = Rotate Left
	// 6 = And
	// 7 = Or
	// 8 = Multiply
	// 9 = Divide
	// A = Negate
	// B = Not
	
	wire [31:0] z_add_sub, z_shift_right, z_shift_left, z_and, z_or, z_not;
	// pre-MUX outputs for mul/div
	wire [31:0] hi_mul, lo_mul, hi_div, lo_div;
		
	// ALU Operations
	
	// Add / Subtract / Negate
	carry_lookahead_adder #( .BITS16(2) ) _cla (
		.a(select[10] ? 32'b0 : a),
		.b(select[10] ? ~a : (select[1] ? ~b : b)),
		.sum(z_add_sub), .c_in(select[1] | select[10]), .c_out()
	);
	
	// Shift / Rotate
	right_shift_32b _shr ( .in(a), .shift(b), .out(z_shift_right), .is_rotate(select[4]) );
	left_shift_32b  _shl ( .in(a), .shift(b), .out(z_shift_left), .is_rotate(select[5]) );
	
	assign z_and = a & b; // and
	assign z_or = a | b; // or
	
	// Multiplication
	booth_bit_pair_multiplier mul ( .multiplicand(a), .multiplier(b), .product({hi_mul, lo_mul}) );
	
	// Division
	array_div #( .BITS(32) ) div ( .dividend(a), .divisor(b), .quotient(lo_div), .remainder(hi_div) );

	assign z_not = ~a; // not
	
	// Multiplex the outputs together
	always @(*) begin
		case (select)
			12'b000000000001 : z = z_add_sub;
			12'b000000000010 : z = z_add_sub;
			12'b000000000100 : z = z_shift_right;
			12'b000000001000 : z = z_shift_left;
			12'b000000010000 : z = z_shift_right;
			12'b000000100000 : z = z_shift_left;
			12'b000001000000 : z = z_and;
			12'b000010000000 : z = z_or;
			12'b010000000000 : z = z_add_sub;
			12'b100000000000 : z = z_not;
			default          : z = 32'b0;
		endcase
		
		case (select)
			12'b000100000000 : {hi, lo} = {hi_mul, lo_mul};
			12'b001000000000 : {hi, lo} = {hi_div, lo_div};
			default          : {hi, lo} <= 64'b0;
		endcase
	end
endmodule


`timescale 1ns/100ps
module alu_test;

	reg [31:0] a, b;
	reg [11:0] select;
	wire [31:0] z, hi, lo;
	wire signed [31:0] sz;
	
	assign sz = z; // For reading signed outputs

	alu _alu ( .a(a), .b(b), .select(select), .z(z), .hi(hi), .lo(lo) );
	
	initial begin
	
		a <= 32'h7C; // 124
		b <= 32'h7; // 7
		
		select <= 12'b000000000001; // Add
		#1 $display("Test | add | 124 + 7 = 131 | %0d + %0d = %0d", a, b, z);
		
		select <= 12'b000000000010; // Subtract
		#1 $display("Test | sub | 124 - 7 = 117 | %0d - %0d = %0d", a, b, z);
		
		select <= 12'b000000000100; // Shift Right
		#1 $display("Test | shift right | 0000007c >> 00000007 = 00000000 | %h >> %h = %h", a, b, z);
		
		select <= 12'b000000001000; // Shift Left
		#1 $display("Test | shift left | 0000007c << 00000007 = 00003e00 | %h << %h = %h", a, b, z);
		
		select <= 12'b000000010000; // Rotate Right
		#1 $display("Test | rotate right | 0000007c >>R 00000007 = f8000000 | %h >>R %h = %h", a, b, z);
		
		select <= 12'b000000100000; // Rotate Left
		#1 $display("Test | rotate left | 0000007c R<< 00000007 = 00003e00 | %h R<< %h = %h", a, b, z);
		
		select <= 12'b000001000000; // And
		#1 $display("Test | and | 0000007c & 00000007 = 00000004 | %h & %h = %h", a, b, z);
		
		select <= 12'b000010000000; // Or
		#1 $display("Test | or | 0000007c or 00000007 = 0000007f | %h or %h = %h", a, b, z);
		
		select <= 12'b000100000000; // Multiply
		#1 $display("Test | mul | 124 * 7 = (lo 868, hi 0) | %0d * %0d = (lo %0d, hi %0d)", a, b, lo, hi);
		
		select <= 12'b001000000000; // Divide
		#1 $display("Test | div | 124 / 7 = (lo 17, hi 5) | %0d / %0d = (lo %0d, hi %0d)", a, b, lo, hi);

		select <= 12'b010000000000; // Negate
		#1 $display("Test | neg | -(124) = -124 | -(%0d) = %0d", a, sz);
		
		select <= 12'b100000000000; // Not
		#1 $display("Test | not | ~0000007c = ffffff83 | ~%h = %h", a, z);
		
		$finish;
	
	end

endmodule
