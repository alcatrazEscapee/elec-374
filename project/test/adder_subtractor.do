vlog +acc "adder_subtractor.v"
vsim -voptargs=+acc work.adder_subtractor_test
run 1000ns
