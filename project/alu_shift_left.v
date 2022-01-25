module alu_shift_left (
	input [31:0] in,
	input [5:0] shift,
	output [31:0] out
);
	wire [31:0] shift_1, shift_2, shift_4, shift_8, shift_16, shift_32;
	
	assign shift_1 = shift[0] ? { in[30:0], 1'b0 } : in;
	assign shift_2 = shift[1] ? { shift_1[29:0], 2'b0 } : shift_1;
	assign shift_4 = shift[2] ? { shift_2[27:0], 4'b0 } : shift_2;
	assign shift_8 = shift[3] ? { shift_4[23:0], 8'b0 } : shift_4;
	assign shift_16 = shift[4] ? { shift_8[15:0], 16'b0 } : shift_8;
	assign out = shift[5] ? 32'b0 : shift_16; // A shift of >=32 bits will always produce all zero output

endmodule


// Testbench
`timescale 1ns/100ps
module alu_shift_left_test;

	// Declare inputs and outputs to the DUT (Device Under Test), here called the 'target' module
	reg [31:0] in;
	reg [5:0] shift;
	wire [31:0] out;

	// Create the target module
	alu_shift_left target ( .in(in), .shift(shift), .out(out) );

	initial begin
		in <= 32'h19;
		shift <= 6'h3;
		#1 $display("Test | shift1 | 25 << 3 = 200 | %d << %d = %d", in, shift, out);
		
		in <= 32'h2439EB;
		shift <= 6'hE;
		#1 $display("Test | shift2 | 2374123 << 14 = 242925568 | %d << %d = %d", in, shift, out);
		
		in <= 32'b1;
		shift <= 6'b011111;
		#1 $display("Test | shift3 | 1 << 31 = 2147483648 | %d << %d = %d", in, shift, out);
		
		in <= 32'b1;
		shift <= 6'b100000;
		#1 $display("Test | shift4 | 1 << 32 = 0 | %d << %d = %d", in, shift, out);
	end
		
endmodule
