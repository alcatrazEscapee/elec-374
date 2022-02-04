module memory (
	input [8:0] address,
	input [31:0] data_in,
	output reg [31:0] data_out,
	input write_enable,
	input read_clk,
	input write_clk
);
	// Inferred by Quartus into built in memory
	reg [31:0] data [511:0];
	
	always @(posedge write_clk) begin
		if (write_enable)
			data[address] <= data_in;
	end
	
	always @(posedge read_clk) begin
		data_out <= data[address];
	end
endmodule

module memory_test;
	initial begin
		$finish;
	end
endmodule
