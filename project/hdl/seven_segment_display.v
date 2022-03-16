/**
 * A 7-Segment Display Port for the DE0
 * Not clocked, always updates with the current value of the port.
 */
module seven_segment_display (
	input [3:0] digit,
	output reg [7:0] display
);
	always @(*) begin
		case (digit)
			4'b0000 : display = 8'b11000000; 
			4'b0001 : display = 8'b11111001;		
			4'b0010 : display = 8'b10100100; 
			4'b0011 : display = 8'b10110000; 
			4'b0100 : display = 8'b10011001; 
			4'b0101 : display = 8'b10010010; 
			4'b0110 : display = 8'b10000010; 
			4'b0111 : display = 8'b11111000; 
			4'b1000 : display = 8'b10000000; 
			4'b1001 : display = 8'b10010000; 
			4'b1010 : display = 8'b10001000; 
			4'b1011 : display = 8'b10000011; 
			4'b1100 : display = 8'b11000110; 
			4'b1101 : display = 8'b10100001; 
			4'b1110 : display = 8'b10000110;
			4'b1111 : display = 8'b10001110;
		endcase
	end
endmodule


`timescale 1ns/100ps
module seven_segment_display_test;
	initial begin
		$finish;
	end
endmodule