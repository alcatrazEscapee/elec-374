vlog +acc "full_adder.v"
vsim -voptargs=+acc work.full_adder_test
run 1000ns
