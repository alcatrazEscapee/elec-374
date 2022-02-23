
# Create a 25 MHz clock = 40 ns
create_clock -period 40 -name clk [get_ports clk]

# Multicycle paths - long ALU operations (division and multiplication)
# todo: divider has been sped up, multiplier is slow ish, but FPU multiply is the worst case rn
# set_multicycle_path -setup -from * -to {register:_hi|d*} 16
# set_multicycle_path -setup -from * -to {register:_lo|d*} 16

# set_multicycle_path -hold -from * -to {register:_hi|d*} 15
# set_multicycle_path -hold -from * -to {register:_lo|d*} 15