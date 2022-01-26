module booth_bit_pair_multiplier(
	input [31:0] multiplicand,
	input [31:0] multiplier,
	output [63:0] product
);
	// Booth Recoding
	// Bit n | Bit n-1 | Multiplier (ones, sign)
	// 0     | 0       | 0   (0, ?)
	// 0     | 1       | +1  (1, 1)
	// 1     | 0       | -1  (1, 0)
	// 1     | 1       | 0   (0, ?)
	// Bit -1 is implicitly 0
	
	wire [31:0] booth_ones, booth_signs;
	
	assign booth_ones = multiplier[31:0] ^ {multiplier[30:0], 1'b0}; // bit n != bit n-1
	assign booth_signs = {multiplier[30:0], 1'b0}; // bit n-1
	
	// Bit-Pair Recoding
	// Examine pairs of booth ones, and perform multiplications by -2, -1, 0, 1 or 2
	// This produces 16 partial products as opposed to 32
	wire [32:0] pp0, pp1, pp2, pp3, pp4, pp5, pp6, pp7, pp8, pp9, pp10, pp11, pp12, pp13, pp14, pp15;
	
	partial_product _pp0  ( booth_ones[1:0],   booth_signs[1:0],   multiplicand, pp0 );
	partial_product _pp1  ( booth_ones[3:2],   booth_signs[3:2],   multiplicand, pp1 );
	partial_product _pp2  ( booth_ones[5:4],   booth_signs[5:4],   multiplicand, pp2 );
	partial_product _pp3  ( booth_ones[7:6],   booth_signs[7:6],   multiplicand, pp3 );
	partial_product _pp4  ( booth_ones[9:8],   booth_signs[9:8],   multiplicand, pp4 );
	partial_product _pp5  ( booth_ones[11:10], booth_signs[11:10], multiplicand, pp5 );
	partial_product _pp6  ( booth_ones[13:12], booth_signs[13:12], multiplicand, pp6 );
	partial_product _pp7  ( booth_ones[15:14], booth_signs[15:14], multiplicand, pp7 );
	partial_product _pp8  ( booth_ones[17:16], booth_signs[17:16], multiplicand, pp8 );
	partial_product _pp9  ( booth_ones[19:18], booth_signs[19:18], multiplicand, pp9 );
	partial_product _pp10 ( booth_ones[21:20], booth_signs[21:20], multiplicand, pp10 );
	partial_product _pp11 ( booth_ones[23:22], booth_signs[23:22], multiplicand, pp11 );
	partial_product _pp12 ( booth_ones[25:24], booth_signs[25:24], multiplicand, pp12 );
	partial_product _pp13 ( booth_ones[27:26], booth_signs[27:26], multiplicand, pp13 );
	partial_product _pp14 ( booth_ones[29:28], booth_signs[29:28], multiplicand, pp14 );
	partial_product _pp15 ( booth_ones[31:30], booth_signs[31:30], multiplicand, pp15 );
	
	// Sums of partial products
	// Build a balanced binary tree of adders
	// The first level adders need to both sign extend (left), and zero-pad (right) their inputs
	// in order to match their level within the multiplication
	
	wire [63:0] sum00, sum01, sum02, sum03, sum04, sum05, sum06, sum07;
	
	adder64 _a00 ( {{31{pp0[32]}},  pp0        }, {{29{pp1[32]}}, pp1,  2'b0},  sum00 );
	adder64 _a01 ( {{27{pp2[32]}},  pp2,  4'b0 }, {{25{pp3[32]}}, pp3,  6'b0},  sum01 );
	adder64 _a02 ( {{23{pp4[32]}},  pp4,  8'b0 }, {{21{pp5[32]}}, pp5,  10'b0}, sum02 );
	adder64 _a03 ( {{19{pp6[32]}},  pp6,  12'b0}, {{17{pp7[32]}}, pp7,  14'b0}, sum03 );
	adder64 _a04 ( {{15{pp8[32]}},  pp8,  16'b0}, {{13{pp9[32]}}, pp9,  18'b0}, sum04 );
	adder64 _a05 ( {{11{pp10[32]}}, pp10, 20'b0}, {{9{pp11[32]}}, pp11, 22'b0}, sum05 );
	adder64 _a06 ( {{7{pp12[32]}},  pp12, 24'b0}, {{5{pp13[32]}}, pp13, 26'b0}, sum06 );
	adder64 _a07 ( {{3{pp14[32]}},  pp14, 28'b0}, {{1{pp15[32]}}, pp15, 30'b0}, sum07 );
	
	wire [63:0] sum10, sum11, sum12, sum13;
	
	adder64 _a10 ( sum00, sum01, sum10 );
	adder64 _a11 ( sum02, sum03, sum11 );
	adder64 _a12 ( sum04, sum05, sum12 );
	adder64 _a13 ( sum06, sum07, sum13 );
	
	wire [63:0] sum20, sum21;
	
	adder64 _a20 ( sum10, sum11, sum20 );
	adder64 _a21 ( sum12, sum13, sum21 );
	
	// Final adder outputs to the product output of the multiplier
	adder64 _a30 ( sum20, sum21, product );
	
endmodule

/**
 * Partial product calculator, using the booth encoded ones and signs
 * Computes a 33-bit partial product due to the maximum range of bit-pair encoding.
 */
module partial_product(
	input [1:0] booth_ones,
	input [1:0] booth_signs,
	input [31:0] multiplicand,
	output [32:0] product
);

	wire [32:0] result_c; // Compliment of result
	reg [32:0] result;
	reg negative;
	
	negate33 _negate ( result, result_c );
	
	// Product selects between the compliment and result value, based on the negative flag
	assign product = negative ? result_c : result;

	always @(*) begin
	
		// Choose cases based on the booth ones + signs
		// Multiply by +/- 2: Shift left by one
		// Multiply by +/- 1: Sign extend by one
		// Otherwise: set to zero	
		casez ({booth_ones, booth_signs})
			4'b00?? : //  0  0 ->  0
				begin
					result = 33'b0;
					negative = 1'b0;
				end
			4'b100? : // -1  0 -> -2
				begin
					result = {multiplicand, 1'b0};
					negative = 1'b1;
				end
			4'b101? : // +1  0 -> +2
				begin
					result = {multiplicand, 1'b0};
					negative = 1'b0;
				end
			4'b01?0 : //  0 -1 -> -1
				begin
					result = {multiplicand[31], multiplicand};
					negative = 1'b1;
				end
			4'b01?1 : //  0 +1 -> +1
				begin
					result = {multiplicand[31], multiplicand};
					negative = 1'b0;
				end
			// 4'b1100   -1 -1 -> Booth recoding will not have adjacent equal signs
			4'b1101 : // -1 +1 -> -1
				begin
					result = {multiplicand[31], multiplicand};
					negative = 1'b1;
				end
			4'b1110 : // +1 -1 -> +1
				begin
					result = {multiplicand[31], multiplicand};
					negative = 1'b0;
				end
			// 4'b1111 : +1 +1 -> Booth recoding will not have adjacent equal signs
			default :
				begin
					result = 33'b0;
					negative = 1'b0;
				end
		endcase
	end

endmodule


/**
 * 33-bit 2's Compliment Negation
 */
module negate33(
	input [32:0] in,
	output [32:0] out
);
	// Negation = Invert all bits and add one
	// Addition is performed with a single carry chain, similar to a RCA if b = 0
	wire [32:0] carry;
	
	assign carry[0] = 1'b1; // c_in = 0
	assign carry[32:1] = (~in[31:0]) & carry[31:0]; // carry chain, ci+1 = xi & ci
	assign out = (~in) ^ carry; // summation, s = xi ^ ci
endmodule


/**
 * 64-bit Adder, used specifically for the multiplication summation
 * Implemented as a 64-bit RCA from two 32-bit RCAs, but could in theory be built from any 32-bit RCA
 * Does not implement c_in or c_out
 */
module adder64(
	input [63:0] a,
	input [63:0] b,
	output [63:0] sum
);
	wire c_32, c_64;

	ripple_carry_adder_32b lo ( .a(a[31:0]), .b(b[31:0]), .sum(sum[31:0]), .c_in(1'b0), .c_out(c_32) );
	ripple_carry_adder_32b hi ( .a(a[63:32]), .b(b[63:32]), .sum(sum[63:32]), .c_in(c_32), .c_out(c_64) );

endmodule



/**
 * Testbench
 * Lots of test cases because multiplication is hard
 */
`timescale 1ns/100ps
module booth_bit_pair_multiplier_test;
	
	reg signed [63:0] a, b;
	wire signed [63:0] product;
	
	integer i;
	
	booth_bit_pair_multiplier mul ( a[31:0], b[31:0], product );
	
	initial begin
		// a <= 1062902654;
		// b <= -309493541;
		// #1 $display("Test | multiply %0d * %0d | %0d | %0d", a, b, a * b, product);
		
		for (i = 0; i < 1000; i = i + 1) begin
			a <= $random;
			b <= $random;
			#1 $display("Test | multiply %0d * %0d | %0d | %0d", a, b, a * b, product);
		end
		
		$finish;
	end

endmodule
