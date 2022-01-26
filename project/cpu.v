module cpu (input a, output b);
	assign b = a; // Enough to satisfy Quartus's warning about top level partition lacking logic

	wire [31:0] x, y;
	wire [63:0] z;
	booth_bit_pair_multiplier mul (x, y, z);
endmodule
