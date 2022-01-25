vlog +acc "alu.v"
vsim -voptargs=+acc work.alu_test
run 100ns
