/**
 * The top-level module for the CPU, as implemented on the DE0 board
 * This contains all port and clock specific logic that is independent of the CPU spec.
 */
module system (

	// Inputs
	input [7:0] switches_in,
	input button_reset_in,
	input button_stop_in,

	// Outputs
	output [7:0] digit0_out,
	output [7:0] digit1_out,
	output [7:0] digit2_out,
	output [7:0] digit3_out,
	
	output running,
	
	// Control
	input clk_50mhz
);
	// Internal control signals
	wire clk, clr;

	// Clock Divider
	// DE0 Board has a 50 MHz clock available = 20 ns
	// Our Design has a fmax of ~ 18 MHz
	// Use a 4x Frequency divider, for a expected frequency of 12.5 MHz = 80 ns
	wire [1:0] state_in, state_out;
	
	// register #( .BITS(2) ) _freq_div ( .d(state_in), .q(state_out), .en(1'b1), .clk(clk_50mhz), .clr(clr) );
	// ripple_carry_adder #( .BITS(2) ) _freq_add ( .a(state_out), .b(2'b1), .sum(state_in), .c_in(1'b0), .c_out() );
	
	pll _freq_div ( .inclk0(clk_50mhz), .c0(clk) );
	
	//assign clk = clk_50mhz; // state_out[1]; // Top bit of the state is divide by four
	assign clr = ~button_reset_in; // Async clear is active low, Button is active high

	wire [31:0] output_out;
	wire is_halted;

	cpu _cpu (
		// Inputs
		.input_in({24'b0, switches_in}),
		.input_en(1'b1),
		
		// Control
		.clk(clk),
		.clr(clr),
		.halt(button_stop_in),
		
		// Outputs
		.output_out(output_out),
		.is_halted(is_halted)
	);
	
	assign running = ~is_halted; // Display the light when running
	
	// Outputs - Display the lower 4 hex digits of the output register
	seven_segment_display _out0 ( .digit(output_out[3:0]),   .display(digit0_out) );
	seven_segment_display _out1 ( .digit(output_out[7:4]),   .display(digit1_out) );
	seven_segment_display _out2 ( .digit(output_out[11:8]),  .display(digit2_out) );
	seven_segment_display _out3 ( .digit(output_out[15:12]), .display(digit3_out) );

endmodule

`timescale 1ns/100ps
module system_test;
	initial begin
		$finish;
	end
endmodule
