module alu(
	input [31:0] a,
	input [31:0] b,
	input [3:0] select, // 12 -> 4 encoded signal
	output reg [31:0] z, // Outputs for all other instructions
	output [31:0] hi, // Outputs for div, mul
	output [31:0] lo
);

	// ALU Operations (by select code)
	// 0 = 0000 = Add
	// 1 = 0001 = Sub
	// 2 = 0010 = Shift Right
	// 3 = 0011 = Shift Left
	// 4 = 0100 = Rotate Right
	// 5 = 0101 = Rotate Left
	// 6 = 0110 = And
	// 7 = 0111 = Or
	// 8 = 1000 = Multiply
	// 9 = 1001 = Divide
	// A = 1010 = Negate
	// B = 1011 = Not
	
	wire [31:0] z_add_sub, z_shift_right, z_shift_left, z_rotate_right, z_rotate_left, z_and, z_or, z_not;
	
	// ALU Operations
	
	wire [31:0] add_sub_a; // The input to the adder: In add, sub, this will be a, but in neg, we force this to zero.
	wire add_sub_negate; // 1 = add/sub, 0 = neg (it's used as a mask)
	wire add_sub_select; // 1 = Addition, 0 = Subtraction
	wire add_sub_carry; // Carry out?
	
	// Three opcodes that use the adder/subtractor, and the desired select signals:
	// Op       | select | negate
	// add 0000 | 0      | 1
	// sub 0001 | 1      | 1
	// neg 1010 | 1      | 0
	assign add_sub_negate = ~select[3];
	assign add_sub_select = select[0] | select[3];
	
	assign add_sub_a = a & {32{add_sub_negate}};
	
	adder_subtractor add_sub ( .a(add_sub_a), .b(b), .sum(z_add_sub), .sub(add_sub_select), .c_out(add_sub_carry) );
	
	// todo: shift right
	alu_shift_left shift_left ( .in(a), .shift(b), .out(z_shift_left) );
	// todo: rotate right
	// todo: rotate left
	assign z_and = a & b;
	assign z_or = a | b;
	// todo: multiply (assign directly to hi, lo)
	// todo: divide (assign directly to hi, lo)
	assign z_not = ~a;
	
	// Multiplex the outputs together
	
	always @(*) begin
		case (select)
			4'b0000 : z = z_add_sub;
			4'b0001 : z = z_add_sub;
			4'b0010 : z = z_shift_right;
			4'b0011 : z = z_shift_left;
			4'b0100 : z = z_rotate_right;
			4'b0101 : z = z_rotate_left;
			4'b0110 : z = z_and;
			4'b0111 : z = z_or;
			// No Multiply / Divide
			4'b1010 : z = z_add_sub;
			4'b1011 : z = z_not;
			default : z = 32'b0;
		endcase
	end
	
endmodule


`timescale 1ns/100ps
module alu_test;

	reg [31:0] a, b;
	reg [3:0] select;
	wire [31:0] z, hi, lo;

	alu _alu ( .a(a), .b(b), .select(select), .z(z), .hi(hi), .lo(lo) );
	
	initial begin
	
		a <= 32'h7C; // 124
		b <= 32'h7; // 7
		
		select <= 4'h0; // Add
		#1 $display("Test | add | 124 + 7 = 131 | %0d + %0d = %0d", a, b, z);
		
		select <= 4'h1; // Subtract
		#1 $display("Test | add | 124 - 7 = 117 | %0d - %0d = %0d", a, b, z);
		
		select <= 4'h3; // Shift Left
		#1 $display("Test | shift_left | 0000007c << 00000007 = 00003e00 | %h << %h = %h", a, b, z);
		
		select <= 4'h6; // And
		#1 $display("Test | and | 0000007c & 00000007 = 00000004 | %h & %h = %h", a, b, z);
		
		select <= 4'h7; // Or
		#1 $display("Test | or | 0000007c or 00000007 = 0000007f | %h or %h = %h", a, b, z);

		select <= 4'hA; // Negate
		#1 $display("Test | neg | -7 = 4294967289 | -%0d = %0d", b, z);
		
		select <= 4'hB; // Not
		#1 $display("Test | not | ~0000007c = ffffff83 | ~%h = %h", a, z);
		
		$finish;
	
	end

endmodule
