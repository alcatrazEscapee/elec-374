vlib work
vlog +acc "register_file.v"
vsim -voptargs=+acc work.register_file_test
run 1000ns
