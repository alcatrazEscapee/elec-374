module alu(
	input [31:0] a,
	input [31:0] b,
	input [11:0] select, // {alu_add, alu_sub, alu_shr, alu_shl, alu_ror, alu_rol, alu_and, alu_or, alu_mul, alu_div, alu_neg, alu_not}
	output reg [31:0] z, // Outputs for all other instructions
	output [31:0] hi, // Outputs for div, mul
	output [31:0] lo
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
	
	wire [31:0] z_add_sub, z_shift_right, z_shift_left, z_rotate_right, z_rotate_left, z_and, z_or, z_not, z_neg;
	
	// ALU Operations
	
	// Add / Subtract
	wire add_sub_c_out; // Carry out ?
	adder_subtractor add_sub ( .a(a), .b(b), .sum(z_add_sub), .sub(select[1]), .c_out(add_sub_c_out) );
	
	// Shift / Rotate
	// todo: shift right
	alu_shift_left shift_left ( .in(a), .shift(b), .out(z_shift_left) );
	// todo: rotate right
	// todo: rotate left
	
	assign z_and = a & b; // and
	assign z_or = a | b; // or
	
	// Multiplication
	booth_bit_pair_multiplier mul ( .multiplicand(a), .multiplier(b), .product({hi, lo}) );
	
	// Division
	// todo: divide (assign directly to hi, lo)
	
	signed_compliment #( .BITS(32) ) neg ( .in(b), .out(z_neg) ); // neg
	assign z_not = ~b; // not
	
	// Multiplex the outputs together
	
	always @(*) begin
		case (select)
			12'b000000000001 : z = z_add_sub;
			12'b000000000010 : z = z_add_sub;
			12'b000000000100 : z = z_shift_right;
			12'b000000001000 : z = z_shift_left;
			12'b000000010000 : z = z_rotate_right;
			12'b000000100000 : z = z_rotate_left;
			12'b000001000000 : z = z_and;
			12'b000010000000 : z = z_or;
			// No Multiply / Divide
			12'b010000000000 : z = z_neg;
			12'b100000000000 : z = z_not;
			default : z = 32'b0;
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
		
		select <= 12'b000000001000; // Shift Left
		#1 $display("Test | shift_left | 0000007c << 00000007 = 00003e00 | %h << %h = %h", a, b, z);
		
		select <= 12'b000001000000; // And
		#1 $display("Test | and | 0000007c & 00000007 = 00000004 | %h & %h = %h", a, b, z);
		
		select <= 12'b000010000000; // Or
		#1 $display("Test | or | 0000007c or 00000007 = 0000007f | %h or %h = %h", a, b, z);
		
		select <= 12'b000100000000; // Multiply
		#1 $display("Test | mul | 124 * 7 = (lo 868, hi 0) | %0d * %0d = (lo %0d, hi %0d)", a, b, lo, hi);

		select <= 12'b010000000000; // Negate
		#1 $display("Test | neg | -(7) = -7 | -(%0d) = %0d", b, sz);
		
		select <= 12'b100000000000; // Not
		#1 $display("Test | not | ~00000007 = fffffff8 | ~%h = %h", b, z);
		
		$finish;
	
	end

endmodule
