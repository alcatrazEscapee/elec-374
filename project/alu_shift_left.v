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
module alu_shift_left_test;
	reg [31:0] in;
	reg [5:0] shift;
	wire [31:0] out;

	alu_shift_left target ( .in(in), .shift(shift), .out(out) );

	initial begin
		in <= 32'b1101;
		shift <= 6'b11;
		#10
		in <= 32'b111000001101;
		shift <= 6'b1001;
		#10
		in <= 32'b1101;
		shift <= 6'b11;
	end
		
endmodule
