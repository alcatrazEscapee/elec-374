`timescale 1ns/10ps

module alu_shift_left_test;
	reg [31:0] in;
	reg [5:0] shift;
	wire [31:0] out;

	alu_shift_left target ( .in(in), .shift(shift), .out(out) );

	initial begin
		in <= 32'b1101;
		shift <= 6'b11;
		#300
		in <= 32'b111000001101;
		shift <= 6'b1001;
	end
		
endmodule
