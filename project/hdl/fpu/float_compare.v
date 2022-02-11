module float_compare (
	input [31:0] fa,
	input [31:0] fb,
	output gt,
	output eq
);
	wire sa, sb;
	wire [7:0] ea, eb;
	wire [22:0] ma, mb;
	
	assign {sa, ea, ma} = fa;
	assign {sb, eb, mb} = fb;
	
	wire sign_gt, exp_gt, mantissa_gt, is_nan;
	
	assign is_nan = sa == 32'h7fc00000 || sa == 32'hffc00000 || sb == 32'h7fc00000 || sb == 32'hffc00000;
	assign sign_gt = !sa && sb; // Positive > Negative
	
	greater_than_unsigned #( .BITS(8) ) _exp_gt ( .a(ea), .b(eb), .gt(exp_gt) );
	greater_than_unsigned #( .BITS(23) ) _mantissa_gt ( .a(ma), .b(mb), .gt(mantissa_gt) );
		
	assign eq = !is_nan && fa == fb;
	assign gt = !is_nan && (
		sign_gt ||
		(sa == sb && sa == 1'b0 && exp_gt) ||
		(sa == sb && sa == 1'b1 && ea != eb && !exp_gt) ||
		(sa == sb && ea == eb && mantissa_gt)
	);
	
endmodule


`timescale 1ns/100ps
module float_compare_test;

	reg sa, sb;
	reg [7:0] ea, eb;
	reg [22:0] ma, mb;
	
	wire [31:0] fa, fb;
	wire gt, eq;
	
	assign fa = {sa, ea, ma};
	assign fb = {sb, eb, mb};
	
	float_compare _fc ( .fa(fa), .fb(fb), .gt(gt), .eq(eq) );

	integer i;
	initial begin
		for (i = 0; i < 1000; i = i + 1) begin
			sa <= $urandom;
			sb <= $urandom;
			ea <= $urandom % 255;
			eb <= $urandom % 255;
			ma <= $urandom;
			mb <= $urandom;
			#1
			$display("Test fpu > | float greater than | %h | %h | %b", fa, fb, gt);
			$display("Test fpu = | float equal | %h | %h | %b", fa, fb, eq);
		end
		
		$finish;
	end
endmodule
