/**
 * Right shift/rotate barrel shifter
 * Works for arbitrary power-of-two bit lengths
 */
module right_shift #(
	parameter BITS = 32,
	parameter SHIFT_BITS = $clog2(BITS) + 1
) (
	input [BITS - 1:0] in,
	input [SHIFT_BITS - 1:0] shift,
	output [BITS - 1:0] out,
	
	input is_rotate, // If the shifted-off bits should be rotated back on the front
	output accumulate // If any of the shifted-off bits were '1', this flag is set
);
	localparam DEPTH = $clog2(BITS);

	wire [BITS - 1:0] shifts [DEPTH:0];
	wire [DEPTH - 1:0] accumulates;
	wire out_of_bounds;
	
	assign out_of_bounds = | shift[SHIFT_BITS - 1:DEPTH];
	assign accumulate = | (out_of_bounds ? in : accumulates);
	
	assign shifts[0] = in;
	assign out = out_of_bounds && !is_rotate ? {BITS{1'b0}} : shifts[DEPTH];
	
	genvar i;
	generate
		for (i = 0; i < DEPTH; i = i + 1) begin : gen_shift
			localparam WIDTH = 1 << i;
			assign shifts[i + 1] = shift[i] ? {(is_rotate ? shifts[i][WIDTH - 1:0] : {WIDTH{1'b0}}), shifts[i][BITS - 1:WIDTH]} : shifts[i];
			assign accumulates[i] = shift[i] ? (| shifts[i][WIDTH - 1:0]) : 1'b0;
		end
	endgenerate
endmodule


// Testbench
`timescale 1ns/100ps
module right_shift_test;

	reg [3:0] in;
	reg [2:0] shift;
	wire [3:0] out_shift, out_rotate;
	wire out_accumulate;

	right_shift #( .BITS(4) ) _ls ( .in(in), .shift(shift), .out(out_shift), .is_rotate(1'b0), .accumulate(out_accumulate) );
	right_shift #( .BITS(4) ) _lr ( .in(in), .shift(shift), .out(out_rotate), .is_rotate(1'b1), .accumulate() );

	integer i, j;
	
	initial begin
		for (i = 0; i < 16; i = i + 1) begin
			for (j = 0; j < 5; j = j + 1) begin
				in <= i;
				shift <= j;
				#1 $display("Test | right shift 0b%b >> %0d | 0b%b | 0b%b", in, shift, in >> shift, out_shift);
				#1 $display("Test | right shift (accumulate) 0b%b >>A %0d | %b | %b", in, shift, (in[3] & j > 3) | (in[2] & j > 2) | (in[1] & j > 1) | (in[0] & j > 0), out_accumulate);
				#1 $display("Test | right rotate 0b%b >>R %0d | 0b%b | 0b%b", in, shift, (in >> shift) | (in << (4 - shift)), out_rotate);
			end
		end
		
		$finish;
	end
endmodule
