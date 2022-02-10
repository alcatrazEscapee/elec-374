
# Create a 25 MHz clock = 40 ns
create_clock -period 40 -name clk [get_ports clk]

# Multicycle paths - long ALU operations (division and multiplication)
# todo: add registers at the end of the divider and multiplier, so we can target these effectively?
set_multicycle_path -setup -from * -to {register:_hi|d*} 16
set_multicycle_path -setup -from * -to {register:_lo|d*} 16

set_multicycle_path -hold -from * -to {register:_hi|d*} 15
set_multicycle_path -hold -from * -to {register:_lo|d*} 15