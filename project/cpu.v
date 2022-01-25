module cpu();
	// Top level module needs to contain some logic, and instantiate all modules in the hiearchy?
	wire [31:0] a, b, z, hi, lo;
	
	alu _alu ( .a(a), .b(b), .z(z), .hi(hi), .lo(lo) );

endmodule
