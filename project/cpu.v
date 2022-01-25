module cpu( input [37:0] dummy_in, output [31:0] dummy_out );
	// Top level module needs to contain some logic, and instantiate the design?
	alu_shift_left shl (.in (dummy_in[31:0]), .shift(dummy_in[37:32]), .out(dummy_out) );
endmodule
