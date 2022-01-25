module cpu (input a, output b);
	assign b = a; // Enough to satisfy Quartus's warning about top level partition lacking logic

endmodule
