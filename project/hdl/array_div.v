/**
 * array_div: n-bit array divider module. 
 * Width specified by `BITS` parameter; defaults to 32-bit.
 * Computes (n-bit) `dividend` / `divisor`.
 * Quotient stored in `quotient`; remainder in `remainder`.
 */
module array_div #(
	parameter BITS = 32
) (
	input [BITS - 1:0] dividend,
	input [BITS - 1:0] divisor,
	output [BITS - 1:0] quotient,
	output [BITS - 1:0] remainder
);

	// Signed complement stuff
	wire [BITS - 1:0] dividend_comp, divisor_comp, quotient_comp, remainder_comp, dividend_u, divisor_u, quotient_u, remainder_u;
	// q_pos indicates quotient should be positive, r_pos indicates remainder should be positive
	wire q_pos, r_pos;

	// Internal mode, sum, and b_out lines (between layers)
	wire [BITS - 1:-1] layer_mode_out;
	wire [BITS - 1:0] layer_sum [-1:BITS - 1];
	// layer_b_out is not really necessary. but keeping it true to the original circuit diagram
	wire [BITS - 1:0] layer_b_out [-1:BITS - 1];
	// Remainder sum
	wire [BITS - 1:0] r_sum;
	// Not needed, but it makes Quartus happy
	wire r_c_out;
	
	// Instantiate signed_compliment
	signed_compliment #( .BITS(BITS) ) sc_dividend ( .in(dividend), .out(dividend_comp) );
	signed_compliment #( .BITS(BITS) ) sc_divisor ( .in(divisor), .out(divisor_comp) );
	// Assign the correct (unsigned) versions of dividend/divisor
	assign dividend_u = dividend[BITS - 1] ? dividend_comp : dividend;
	assign divisor_u = divisor[BITS - 1] ? divisor_comp : divisor;
	// Expression derived from C division/remainder behaviour
	assign q_pos = ~(dividend[BITS - 1] ^ divisor[BITS - 1]);
	assign r_pos = ~dividend[BITS - 1];
	
	// Assign constant 1 to first layer's mode_in
	assign layer_mode_out[-1] = 1'b1;
	// a input to most significant 31 cellsin first layer are 0, followed by msb of dividend
	assign layer_sum[-1] = { {(BITS - 1){1'b0}}, dividend_u[BITS - 1] };
	// making the part-select explicit so there's no ambiguity
	assign layer_b_out[-1] = divisor_u;
	
	genvar layer, node;
	generate
		for (layer = 0; layer < BITS; layer = layer + 1) begin : gen_div_layer
			// Declare internal wires to carry mode_in/out and c_in/out between cells
			wire [BITS:0] mode_in;
			wire [BITS:0] carry_in;
			// Also declare sum, so we can manipulate before assigning to layer_sum
			wire [BITS - 1:0] sum;
			
			// Assign input mode for the first cell in layer
			assign mode_in[BITS] = layer_mode_out[layer - 1];
			// Assign last mode to last carry
			assign carry_in[0] = mode_in[0];
			
			div_cell dc [BITS - 1:0] (
					.a( layer_sum[layer-1] ),
					.b_in( layer_b_out[layer-1] ),
					.mode_in( mode_in[BITS:1] ),
					.mode_out( mode_in[BITS - 1:0] ),
					.c_in( carry_in[BITS - 1:0] ),
					.c_out( carry_in[BITS:1] ),
					.b_out( layer_b_out[layer] ),
					.sum( sum )
				);
			
			// Make assignments to set up next layer
			// This concatenation provides the shifting on all except the last layer
			assign layer_sum[layer] = layer == BITS - 1 ? sum : {sum[BITS - 2:0], dividend_u[(BITS - 2) - layer]};
			assign layer_mode_out[layer] = carry_in[BITS - 1];
			// Assign quotient here
			assign quotient_u[(BITS - 1) - layer] = carry_in[BITS - 1];
		end
	endgenerate
	
	// generate remainder
	ripple_carry_adder #( .BITS(BITS) ) _rca ( .a(layer_sum[BITS - 1]), .b(layer_b_out[BITS - 1]), .sum(r_sum), .c_in(1'b0), .c_out(r_c_out) );
	assign remainder_u = quotient_u[0] ? layer_sum[BITS - 1] : r_sum;
	
	// Handle complements of outputs now
	signed_compliment #( .BITS(BITS) ) sc_quotient ( .in(quotient_u), .out(quotient_comp) );
	signed_compliment #( .BITS(BITS) ) sc_remainder ( .in(remainder_u), .out(remainder_comp) );
	
	// Assign final outputs based on q_pos, r_pos
	assign quotient = q_pos ? quotient_u : quotient_comp;
	assign remainder = r_pos ? remainder_u : remainder_comp;
	
endmodule

/**
 * div_cell
 * Represents a single 'cell' in the division array.
 * This is essentially a full adder + XOR. Also, b_in -> b_out and mode_in -> mode_out
 * are just pass throughs. They maintain the 'structure' of the circuit in
 * Computer_Arithmetic slide 54, but provide no benefit over the alternative.
 */
module div_cell(
	input a,
	input b_in,
	output b_out,
	input mode_in,
	output mode_out,
	input c_in,
	output c_out,
	output sum
);
	
	// instantiate full adder
	full_adder _fa ( .a(b_in ^ mode_in), .b(a), .sum(sum), .c_in(c_in), .c_out(c_out) );
	
	// other assignments (for propagation)
	assign mode_out = mode_in;
	assign b_out = b_in;

endmodule

/**
 * Testbench
 * Lots of test cases because division is hard
 */
`timescale 1ns/100ps
module array_div_test;
	
	reg signed [31:0] a, b;
	wire signed [31:0] quotient, remainder;
	
	integer i;
	
	array_div #( .BITS(32) ) _div ( .dividend(a[31:0]), .divisor(b[31:0]), .quotient(quotient), .remainder(remainder) );
	
	initial begin
		// Regressions
		a <= 97;
		b <= 7;
		#1 $display("Test | divide %0d / %0d | %0d, %0d | %0d, %0d", a, b, a / b, a % b, quotient, remainder);
		
		for (i = 0; i < 100; i = i + 1) begin
			a <= $random % 1000000;
			b <= $random % 1000;
			if (b != 0)
				#1 $display("Test | divide %0d / %0d | %0d, %0d | %0d, %0d", a, b, a / b, a % b, quotient, remainder);
		end
		
		$finish;
	end
endmodule
