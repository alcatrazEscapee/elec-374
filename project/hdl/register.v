/**
 * A simple N-bit rising-edge clocked register
 * Q = Input, D = Output (Yes, that is accidentally backwards from what the standard is)
 */
module register #(
	parameter BITS = 32
) (
	input [BITS - 1:0] q,
	output reg [BITS - 1:0] d,
	input clk,
	input clr, // active-low, asynchronous clear
	input en // write enable
);
	always @(posedge clk, negedge clr) begin
		if (clr == 1'b0)
			d <= {BITS{1'b0}};
		else if (en == 1'b1)
			d <= q;
		else
			d <= d;
	end
endmodule


`timescale 1ns/100ps
module register_test;
	
	reg [31:0] q;
	wire [31:0] d;
	
	reg clk, clr, en;
	
	register r ( .q(q), .d(d), .clk(clk), .clr(clr), .en(en) );

	// Clock
	initial begin
		clk <= 1'b0;
		forever #5 clk = ~clk;
	end
	
	// Test
	initial begin
		#7 // Offset so we're in the middle of the positive clock signal
		
		// Verify async clear
		en <= 1'b1;
		clr <= 1'b0;
		q <= 134;
		#1 $display("Test | async clear 0 after 1ns | en=1, clr=0, q=134, d=0 | en=%d, clr=%d, q=%0d, d=%0d", en, clr, q, d);
		#9 $display("Test | async clear 0 after 10ns | en=1, clr=0, q=134, d=0 | en=%d, clr=%d, q=%0d, d=%0d", en, clr, q, d);
		
		clr <= 1'b1;
		q <= 57;
		#1 $display("Test | async clear 1 after 1ns | en=1, clr=1, q=57, d=0 | en=%d, clr=%d, q=%0d, d=%0d", en, clr, q, d);
		#9 $display("Test | async clear 1 after 10ns | en=1, clr=1, q=57, d=57 | en=%d, clr=%d, q=%0d, d=%0d", en, clr, q, d);
		
		clr <= 1'b0;
		#1 $display("Test | async clear 0 after 1ns | en=1, clr=0, q=57, d=0 | en=%d, clr=%d, q=%0d, d=%0d", en, clr, q, d);
		#9 $display("Test | async clear 0 after 10ns | en=1, clr=0, q=57, d=0 | en=%d, clr=%d, q=%0d, d=%0d", en, clr, q, d);
				
		// Verify write enable
		q <= 183;
		clr <= 1'b1;
		#1 $display("Test | write enable 1 after 1ns | en=1, clr=1, q=183, d=0 | en=%d, clr=%d, q=%0d, d=%0d", en, clr, q, d);
		#9 $display("Test | write enable 1 after 10ns | en=1, clr=1, q=183, d=183 | en=%d, clr=%d, q=%0d, d=%0d", en, clr, q, d);
		
		q <= 89;
		en <= 1'b0;
		#1 $display("Test | write enable 0 after 1ns | en=0, clr=1, q=89, d=183 | en=%d, clr=%d, q=%0d, d=%0d", en, clr, q, d);
		#9 $display("Test | write enable 0 after 10ns | en=0, clr=1, q=89, d=183 | en=%d, clr=%d, q=%0d, d=%0d", en, clr, q, d);
		
		q <= 555;
		en <= 1'b1;
		#1 $display("Test | write enable 0 after 1ns | en=1, clr=1, q=555, d=183 | en=%d, clr=%d, q=%0d, d=%0d", en, clr, q, d);
		#9 $display("Test | write enable 0 after 10ns | en=1, clr=1, q=555, d=555 | en=%d, clr=%d, q=%0d, d=%0d", en, clr, q, d);
		
		$finish;
	end
endmodule
