
SHELL = /bin/bash
VPATH = hdl hdl/fpu

OUT  := out
HDL  := hdl
SRC  := src
WORK := work

VLIB := vlib
VLOG := vlog +acc
VSIM := vsim -voptargs=+acc work.%s_test\nrun 10000ns
GCC := gcc -std=c11

SOURCES := $(shell find $(HDL) -name '\*.v' -printf '%f ')
OUTPUTS := $(SOURCES:%.v=$(WORK)/%/_primary.vhd)
TESTS   := $(SOURCES:%.v=%)

VSIM_LOG := $(OUT)/vsim.log

.DEFAULT_GOAL = run

.PHONY: debug
debug:
	@echo $(OUTPUTS)

.PHONY : help
help :
	@echo "make all     : Runs all tests"
	@echo "make mod=foo : Runs tests for the module 'foo'"

.PHONY : all
all : $(OUTPUTS) $(OUT)/fpu.o
	@rm -rf $(VSIM_LOG)
	@mkdir -p $(OUT)
	-@for mod in $(TESTS) ; do \
		printf "Simulating %s...\n" $$mod ; \
		printf "$(VSIM)" $$mod | vsim >> $(VSIM_LOG) ; \
	done
	@python test/setup.py $(VSIM_LOG);
	
.PHONY : run
run : $(OUTPUTS) $(OUT)/fpu.o
	@mkdir -p $(OUT)
	-@if [ "$(mod)" = "" ]; then \
		echo "No module provided - try with make mod=foo" ; \
	else \
		printf "Simulating %s\n" $(mod) ; \
		printf "$(VSIM)" $(mod) | vsim > $(VSIM_LOG); \
		python test/setup.py $(VSIM_LOG); \
	fi

.PHONY : fpu
fpu : $(OUT)/fpu.o

$(OUT)/%.o : $(SRC)/%.c
	mkdir -p $(OUT)
	$(GCC) $< -o $@

$(OUTPUTS) : $(WORK)/%/_primary.vhd : %.v
	$(VLOG) "$<"

$(WORK) :
	$(VLIB) $(WORK)
