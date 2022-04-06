/**
 * The top-level module for the CPU, as implemented on the DE0 board
 * This contains all port and clock specific logic that is independent of the CPU spec.
 */
module system (

	// Inputs
	input [7:0] switches_in,
	
	// Buttons are high (1) when unpressed, low (0) when pressed
	// Button 0 = Reset
	// Button 1 = Stop
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
	wire clk, clr, halt;

	// Clock Divider
	// DE0 Board has a 50 MHz clock available = 20 ns
	// Our Design has a fmax of ~ 18 MHz
	// Use a 4x Frequency divider, for a expected frequency of 12.5 MHz = 80 ns
	wire [1:0] state_in, state_out;

	// Note:
	// For some reason, when compiling via ModelSim command line, it cannot find the 'pll' module used here
	// So to run automated tests, we comment it out
	// When compiling for the board, the below line is swapped out
	assign clk = clk_50mhz; // ModelSim
	//pll _freq_div ( .inclk0(clk_50mhz), .c0(clk) ); // DE0 / Quartus
	
	assign clr = button_reset_in; // Both active low
	assign halt = ~button_stop_in; // Halt is active high

	wire [31:0] output_out;
	wire is_halted;

	cpu _cpu (
		// Inputs
		.input_in({24'b0, switches_in}),
		.input_en(1'b1),
		
		// Control
		.clk(clk),
		.clr(clr),
		.halt(halt),
		
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

`timescale 1ns/10ps
module system_test;

	wire [7:0] digit0, digit1, digit2, digit3;
	wire running;
	reg clk, clr;

	system _system (
		.switches_in(8'b10001000), // 0x88
		.button_reset_in(clr),
		.button_stop_in(1'b1),
		
		.digit0_out(digit0),
		.digit1_out(digit1),
		.digit2_out(digit2),
		.digit3_out(digit3),
		
		.running(running),
		.clk_50mhz(clk)
	);
		
	// Clock
	initial begin
		clk <= 1'b1;
		forever #1 clk <= ~clk;
	end
	
	initial begin
		// Initialize Memory
		$display("Initializing Memory");
		$readmemh("out/phase4_testbench.mem", _system._cpu._memory.data);
	
		clr <= 1'b0; // Press the reset button
		#2;
		clr <= 1'b1; // Release reset, program starts
		#2;
	
		while (running) #1;
		
		// Output the digits displayed on the 7-segments
		$display("Test | Digit 0 7-Segment | 10001000 | %0b", digit0); // 0
		$display("Test | Digit 1 7-Segment | 10010010 | %0b", digit1); // 0
		$display("Test | Digit 2 7-Segment | 11000000 | %0b", digit2); // 5
		$display("Test | Digit 3 7-Segment | 11000000 | %0b", digit3); // A
	
		$finish;
	end
endmodule
