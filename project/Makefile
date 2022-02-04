
SHELL = /bin/bash
VPATH = hdl hdl/fpu

OUT  := out
HDL  := hdl
WORK := work
TEST := test
SIMULATION := simulation/modelsim

VLIB := vlib
VLOG := vlog +acc
VSIM := vsim -voptargs=+acc work.%s_test\nrun 10000ns

SOURCES  := $(shell find $(HDL) -name '*.v' -printf '%f ')
MEMORY   := $(shell find $(TEST) -name '*.mem')

OUTPUTS  := $(SOURCES:%.v=$(WORK)/%/_primary.vhd)
TESTS    := $(SOURCES:%.v=%)
MEMORY_OUTPUTS := $(MEMORY:%.mem=$(SIMULATION)/%.mem) 

VSIM_LOG := $(OUT)/vsim.log

.DEFAULT_GOAL = run

.PHONY : help
help :
	@echo "make modelsim    : Sets up requirements for ModelSim"
	@echo "make all         : Runs all tests"
	@echo "make compile-all : A subset of 'make all', intended to be used by CI"
	@echo "make mod=foo     : Runs tests for the module 'foo'"
	@echo "make clean       : Cleans all build files"

.PHONY : modelsim
modelsim : $(WORK) $(SIMULATION)/$(TEST) $(MEMORY_OUTPUTS)

.PHONY : clean
clean : clean-backups clean-outputs

.PHONY : clean-backups
clean-backups :
	find . -name '*.bak' -type f -delete

.PHONY : clean-outputs
clean-outputs :
	rm -rf db
	rm -rf incremental_db
	rm -rf out
	rm -rf output_files
	rm -rf simulation
	rm -rf work
	rm -f cpu_nativelink_simulation.rpt
	rm -f transcript

.PHONY : compile-all
compile-all : $(WORK) $(OUTPUTS)
	@mkdir -p $(OUT)
	@echo start > $(VSIM_LOG)
	-@for mod in $(TESTS) ; do \
		printf "Simulating %s...\n" $$mod ; \
		printf "$(VSIM)" $$mod | vsim >> $(VSIM_LOG) ; \
	done

.PHONY : all
all : compile-all
	@python test/setup.py $(VSIM_LOG)
	
.PHONY : run
run : $(WORK) $(OUTPUTS)
	@mkdir -p $(OUT)
	-@if [ "$(mod)" = "" ]; then \
		echo "No module provided - try with make mod=foo" ; \
	else \
		printf "Simulating %s\n" $(mod) ; \
		printf "$(VSIM)" $(mod) | vsim > $(VSIM_LOG); \
		python test/setup.py $(VSIM_LOG); \
	fi

$(WORK) :
	$(VLIB) $(WORK)

$(OUTPUTS) : $(WORK)/%/_primary.vhd : %.v
	$(VLOG) "$<"

$(SIMULATION)/$(TEST) :
	mkdir -p $(SIMULATION)/$(TEST)

$(SIMULATION)/%.mem : %.mem
	cp $< $@
