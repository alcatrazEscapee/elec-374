vlib work
vlog +acc "datapath.v"
vsim -voptargs=+acc work.datapath_test
run 1000ns
