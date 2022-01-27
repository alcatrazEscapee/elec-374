vlib work
vlog +acc "register.v"
vsim -voptargs=+acc work.register_test
run 1000ns
