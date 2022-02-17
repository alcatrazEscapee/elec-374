/**
 * booth_bit_pair_multiplier: computes 64-bit product from two 32-bit values.
 * Computes `product` = `multiplicand` * `multiplier`.
 * Uses Booth bit-pair recoding to compute 16 partial products.
 * Combines partial products with a 7-level Wallace tree. The first 6 levels
 * are composed of carry-save adders, with the top-level being a carry-lookahead
 * adder.
 */
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
	
	// Wallace Tree (Carry-Save Adders + 1 Hiearchical Carry Lookahead Adder)
	// Input partial products are all either (left) sign extended or (right) zero padded to be 64-bit summands.
	// Quartus should be clever enough to eliminate the dead logic this creates (and in testing, it does, within statistically insignifigant LE counts)
	
	// Level 0
	wire [63:0] sum00, sum01, sum02, sum03, sum04, carry00, carry01, carry02, carry03, carry04, pass01;
	
	carry_save_adder #( .BITS(64) ) _csa00 ( .a({{31{pp0[32]}}, pp0        }), .b({{29{pp1[32]}},  pp1,  2'b0 }), .c({{27{pp2[32]}}, pp2,  4'b0 }), .sum(sum00), .carry(carry00) );
	carry_save_adder #( .BITS(64) ) _csa01 ( .a({{25{pp3[32]}}, pp3,  6'b0 }), .b({{23{pp4[32]}},  pp4,  8'b0 }), .c({{21{pp5[32]}}, pp5,  10'b0}), .sum(sum01), .carry(carry01) );
	carry_save_adder #( .BITS(64) ) _csa02 ( .a({{19{pp6[32]}}, pp6,  12'b0}), .b({{17{pp7[32]}},  pp7,  14'b0}), .c({{15{pp8[32]}}, pp8,  16'b0}), .sum(sum02), .carry(carry02) );
	carry_save_adder #( .BITS(64) ) _csa03 ( .a({{13{pp9[32]}}, pp9,  18'b0}), .b({{11{pp10[32]}}, pp10, 20'b0}), .c({{9{pp11[32]}}, pp11, 22'b0}), .sum(sum03), .carry(carry03) );
	carry_save_adder #( .BITS(64) ) _csa04 ( .a({{7{pp12[32]}}, pp12, 24'b0}), .b({{5{pp13[32]}},  pp13, 26'b0}), .c({{3{pp14[32]}}, pp14, 28'b0}), .sum(sum04), .carry(carry04) );
	
	assign pass01 = {{1{pp15[32]}}, pp15, 30'b0};
	
	// Level 1
	wire [63:0] sum10, sum11, sum12, carry10, carry11, carry12, pass10, pass11;
		
	carry_save_adder #( .BITS(64) ) _csa10 ( .a(sum00), .b({carry00[62:0], 1'b0}), .c(sum01), .sum(sum10), .carry(carry10) );
	carry_save_adder #( .BITS(64) ) _csa11 ( .a({carry01[62:0], 1'b0}), .b(sum02), .c({carry02[62:0], 1'b0}), .sum(sum11), .carry(carry11) );
	carry_save_adder #( .BITS(64) ) _csa12 ( .a(sum03), .b({carry03[62:0], 1'b0}), .c(sum04), .sum(sum12), .carry(carry12) );
	
	assign pass10 = {carry04[62:0], 1'b0};
	assign pass11 = pass01;
	
	// Level 2
	wire [63:0] sum20, sum21, carry20, carry21, pass20, pass21;
	
	carry_save_adder #( .BITS(64) ) _csa20 ( .a(sum10), .b({carry10[62:0], 1'b0}), .c(sum11), .sum(sum20), .carry(carry20) );
	carry_save_adder #( .BITS(64) ) _csa21 ( .a({carry11[62:0], 1'b0}), .b(sum12), .c({carry12[62:0], 1'b0}), .sum(sum21), .carry(carry21) );
	
	assign pass20 = pass10;
	assign pass21 = pass11;
	
	// Level 3
	wire [63:0] sum30, sum31, carry30, carry31;
	
	carry_save_adder #( .BITS(64) ) _csa30 ( .a(sum20), .b({carry20[62:0], 1'b0}), .c(sum21), .sum(sum30), .carry(carry30) );
	carry_save_adder #( .BITS(64) ) _csa31 ( .a({carry21[62:0], 1'b0}), .b(pass20), .c(pass21), .sum(sum31), .carry(carry31) );
	
	// Level 4
	wire [63:0] sum4, carry4, pass4;
	
	carry_save_adder #( .BITS(64) ) _csa4 ( .a(sum30), .b({carry30[62:0], 1'b0}), .c(sum31), .sum(sum4), .carry(carry4) );
	
	assign pass4 = {carry31[62:0], 1'b0};
	
	// Level 5
	
	wire [63:0] sum5, carry5;
	
	carry_save_adder #( .BITS(64) ) _csa5 ( .a(sum4), .b({carry4[62:0], 1'b0}), .c(pass4), .sum(sum5), .carry(carry5) );
		
	// Level 6 (Top Level), Carry Lookahead Adder
	
	wire cla_c_out;
	
	carry_lookahead_adder #( .BITS16(4) ) _cla6 ( .a(sum5), .b({carry5[62:0], 1'b0}), .sum(product), .c_in(1'b0), .c_out(cla_c_out) );
	
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

	wire [32:0] result_c, result_p; // Compliment of result
	reg [32:0] result;
	reg negative;
	
	assign result_p = result;
	signed_compliment #( .BITS(33) ) sc ( .in(result_p), .out(result_c) );
	
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
 * Testbench
 * Lots of test cases because multiplication is hard
 */
`timescale 1ns/100ps
module booth_bit_pair_multiplier_test;
	
	reg signed [63:0] a, b;
	wire signed [63:0] product;
	
	integer i;
	
	booth_bit_pair_multiplier _mul ( .multiplicand(a[31:0]), .multiplier(b[31:0]), .product(product) );
	
	assign ai = {{32{a[31]}}, a};
	assign bi = {{32{b[31]}}, b};
	
	initial begin
		// Regressions
		a <= 1062902654;
		b <= -309493541;
		#1 $display("Test | multiply regression %0d * %0d | %0d | %0d", a, b, a * b, product);
		
		for (i = 0; i < 1000; i = i + 1) begin
			a <= $random;
			b <= $random;
			#1 $display("Test | multiply %0d * %0d | %0d | %0d", a, b, a * b, product);
		end
		
		$finish;
	end

endmodule
