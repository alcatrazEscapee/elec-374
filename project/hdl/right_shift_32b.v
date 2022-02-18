/**
 * A 32-bit right shift, using a Barrel Shifter design.
 * Can optionally support rotate as well
 */
module right_shift_32b (
	input [31:0] in,
	input [31:0] shift,
	output [31:0] out,
	input is_rotate
);
	wire [31:0] shift_1, shift_2, shift_4, shift_8, shift_16;
	
	// Shift amount is a 32-bit unsigned value
	// For shifts >= 32, any of the upper bits = 0 indicates the result is zero (this has no effect on rotates).
	wire is_zero;
	assign is_zero = !is_rotate && (| shift[31:5]);
	
	assign shift_1 = shift[0] ? { (is_rotate ? in[0] : 1'b0), in[31:1] } : in;
	assign shift_2 = shift[1] ? { (is_rotate ? shift_1[1:0] : 2'b0), shift_1[31:2] } : shift_1;
	assign shift_4 = shift[2] ? { (is_rotate ? shift_2[3:0] : 4'b0), shift_2[31:4] } : shift_2;
	assign shift_8 = shift[3] ? { (is_rotate ? shift_4[7:0] : 8'b0), shift_4[31:8] } : shift_4;
	assign shift_16 = shift[4] ? { (is_rotate ? shift_8[15:0] : 16'b0), shift_8[31:16] } : shift_8;
	assign out = is_zero ? 32'b0 : shift_16;

endmodule


// Testbench
`timescale 1ns/100ps
module right_shift_32b_test;

	reg [31:0] in;
	reg [31:0] shift;
	wire [31:0] out_shift, out_rotate;

	right_shift_32b _rs ( .in(in), .shift(shift), .out(out_shift), .is_rotate(1'b0) );
	right_shift_32b _rr ( .in(in), .shift(shift), .out(out_rotate), .is_rotate(1'b1) );

	integer i;
	
	initial begin
		// Shift values between [0, 32])
		for (i = 0; i < 100; i = i + 1) begin
			in <= $urandom;
			shift <= $urandom % 32;
			#1 $display("Test | right shift 0x%h >> %0d | 0x%h | 0x%h", in, shift, in >> shift, out_shift);
			#1 $display("Test | right rotate 0x%h >> %0d | 0x%h | 0x%h", in, shift, (in >> shift) | (in << (32 - shift)), out_rotate);
		end
		
		// Shift values (generally) >32
		for (i = 0; i < 100; i = i + 1) begin
			in <= $urandom;
			shift <= $urandom;
			#1 $display("Test | right shift large 0x%h >> %0d | 0x%h | 0x%h", in, shift, in >> shift, out_shift);
			#1 $display("Test | right rotate large 0x%h >> %0d | 0x%h | 0x%h", in, shift, (in >> (shift % 32)) | (in << (32 - (shift % 32))), out_rotate);
		end
		
		$finish;
	end
endmodule
