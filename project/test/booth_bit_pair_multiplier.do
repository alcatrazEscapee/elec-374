vlib work
vlog +acc -vlog01compat "booth_bit_pair_multiplier.v"
vsim -voptargs=+acc work.booth_bit_pair_multiplier_test
run 1000ns
