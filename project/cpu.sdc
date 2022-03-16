# DE0 Board has a 50 MHz clock available = 20 ns
# Our Design has a fmax of ~ 18 MHz
# Use a 4x Frequency divider, for a expected frequency of 12.5 MHz = 80 ns
create_clock -period 20 -name clk_50mhz [get_ports clk_50mhz]

# Automatically apply a generate clock on the output of phase-locked loops (PLLs) 
derive_pll_clocks

derive_clock_uncertainty

# Constrain the input I/O path
set_input_delay -clock {clk_50mhz} -max 3 [all_inputs] 
set_input_delay -clock {clk_50mhz} -min 2 [all_inputs] 
 
# Constrain the output I/O path 
set_output_delay -clock {clk_50mhz} 2 [all_outputs] 