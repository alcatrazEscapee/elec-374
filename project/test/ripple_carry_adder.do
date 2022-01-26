vlib work
vlog +acc "ripple_carry_adder.v"
vsim -voptargs=+acc work.ripple_carry_adder_test
run 3000ns
