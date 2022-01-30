module left_shift_32b (
	input [31:0] in,
	input [31:0] shift,
	output [31:0] out
);
	wire [31:0] shift_1, shift_2, shift_4, shift_8, shift_16, shift_32;
	
	// The shift amount is a 32 bit (unsigned) value
	// If ANY of the upper 26 bits are 1, then the shift value is >= 32, and we immediately infer that the output must be 0
	wire shift_out_of_bounds;
	assign shift_out_of_bounds = | shift[31:5];
	
	assign shift_1 = shift[0] ? { in[30:0], 1'b0 } : in;
	assign shift_2 = shift[1] ? { shift_1[29:0], 2'b0 } : shift_1;
	assign shift_4 = shift[2] ? { shift_2[27:0], 4'b0 } : shift_2;
	assign shift_8 = shift[3] ? { shift_4[23:0], 8'b0 } : shift_4;
	assign shift_16 = shift[4] ? { shift_8[15:0], 16'b0 } : shift_8;
	assign out = shift_out_of_bounds ? 32'b0 : shift_16; // A shift of >=32 bits will always produce all zero output

endmodule


// Testbench
`timescale 1ns/100ps
module left_shift_32b_test;

	// Declare inputs and outputs to the DUT (Device Under Test), here called the 'target' module
	reg [31:0] in;
	reg [31:0] shift;
	wire [31:0] out;

	// Create the target module
	left_shift_32b target ( .in(in), .shift(shift), .out(out) );

	integer i;
	
	initial begin
		// Shift values between [0, 32]
		for (i = 0; i < 100; i = i + 1) begin
			in <= $random;
			shift <= $urandom % 32;
			#1 $display("Test | shift 0x%h << 0x%h | 0x%h | 0x%h", in, shift, in << shift, out);
		end
		
		// Shift values (generally) >32
		for (i = 0; i < 100; i = i + 1) begin
			in <= $random;
			shift <= $random;
			#1 $display("Test | shift_large 0x%h << 0x%h | 0x%h | 0x%h", in, shift, in << shift, out);
		end
		
		#1;
		$finish;
	end
endmodule
