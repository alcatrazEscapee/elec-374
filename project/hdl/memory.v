module memory #(
	parameter BITS = 32,
	parameter WORDS = 16,
	parameter ADDRESS_BITS = $clog2(WORDS)
) (
	input [ADDRESS_BITS - 1:0] address,
	input [BITS - 1:0] data_in,
	output reg [BITS - 1:0] data_out,
	
	input en,
	input clk
);
	// Inferred by Quartus into built in memory
	// Includes a register buffered output, so no MD register is required
	(* ram_init_file = "cpu.mif" *) reg [BITS - 1:0] data [WORDS - 1:0];
	
	always @(posedge clk) begin
		if (en)
			data[address] <= data_in;
		data_out <= data[address];
	end	
endmodule


`timescale 1ns/100ps
module memory_test;
	initial begin
		$finish;
	end
endmodule
