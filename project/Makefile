
SHELL = /bin/bash
VPATH = hdl hdl/fpu

OUT  := out
HDL  := hdl
CLIB := clib
WORK := work

VLIB := vlib
VLOG := vlog +acc
VSIM := vsim -voptargs=+acc work.%s_test\nrun 10000ns

FILES   := $(shell find $(HDL) -name '*.v')
SOURCES := $(shell find $(HDL) -name '*.v' -printf '%f ')
OUTPUTS := $(SOURCES:%.v=$(WORK)/%/_primary.vhd)
TESTS   := $(SOURCES:%.v=%)

VSIM_LOG := $(OUT)/vsim.log
REPORT   := reports/generated.md

.DEFAULT_GOAL = run

.PHONY : work
work :
	$(VLIB) $(WORK)

.PHONY: debug
debug:
	@echo $(OUTPUTS)

.PHONY : help
help :
	@echo "make work        : Sets up the ModelSim work library"
	@echo "make all         : Runs all tests"
	@echo "make compile-all : A subset of 'make all', intended to be used by CI"
	@echo "make mod=foo     : Runs tests for the module 'foo'"
	@echo "make clean       : Cleans all build files"

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

.PHONY : compile-all
compile-all : $(OUTPUTS)
	mkdir -p $(OUT)
	echo start > $(VSIM_LOG)
	for mod in $(TESTS) ; do \
		printf "Simulating %s...\n" $$mod ; \
		printf "$(VSIM)" $$mod | vsim >> $(VSIM_LOG) ; \
	done

.PHONY : all
all : compile-all
	@python test/setup.py $(VSIM_LOG)
	
.PHONY : run
run : $(OUTPUTS)
	@mkdir -p $(OUT)
	-@if [ "$(mod)" = "" ]; then \
		echo "No module provided - try with make mod=foo" ; \
	else \
		printf "Simulating %s\n" $(mod) ; \
		printf "$(VSIM)" $(mod) | vsim > $(VSIM_LOG); \
		python test/setup.py $(VSIM_LOG); \
	fi

.PHONY : report
report : $(FILES)
	mkdir -p reports 
	touch $(REPORT)
	printf "# Generated Report\n" > $(REPORT)
	for mod in $(FILES) ; do \
		printf "\n**File: %s**\n\n\`\`\`verilog\n" $$mod >> $(REPORT) ; \
		cat $$mod >> $(REPORT) ; \
		printf "\`\`\`\n" >> $(REPORT) ; \
	done

$(OUTPUTS) : $(WORK)/%/_primary.vhd : %.v
	$(VLOG) "$<"
