
SHELL = /bin/bash
VPATH = hdl hdl/fpu generated

OUT  := out
HDL  := hdl
SRC  := src
ASM  := asm
WORK := work
TEST := test
SIMULATION := simulation/modelsim

VLIB := vlib
VLOG := vlog +acc
GCC  := gcc -std=c11
VSIM := vsim -voptargs=+acc work.%s_test\nrun 10000ns
ASSEMBLER := python assembler/main.py
MIF_ASM := $(ASM)/phase4_testbench.s

SOURCES  := $(shell find $(HDL) -name '*.v' -printf '%f ') pll.v
ASSEMBLY := $(shell find $(ASM) -name '*.s' -printf '%f ')

OUTPUTS  := $(SOURCES:%.v=$(WORK)/%/_primary.vhd)
TESTS    := $(SOURCES:%.v=%)
MEMORY   := $(ASSEMBLY:%.s=$(OUT)/%.mem)

VSIM_LOG := $(OUT)/vsim.log
FPU_OUT  := $(OUT)/fpu.o

.DEFAULT_GOAL = run

.PHONY : help
help :
	@echo "make asm         : Assembles all programs into .mem outputs"
	@echo "make all         : Runs all tests"
	@echo "make compile-all : A subset of 'make all', intended to be used by CI"
	@echo "make mod=foo     : Runs tests for the module 'foo'"
	@echo "make clean       : Cleans all build files"
	echo $(MEMORY)

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
	rm -f cpu.mif

.PHONY : compile-all
compile-all : $(WORK) $(OUTPUTS) $(MEMORY) $(FPU_OUT)
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
run : $(WORK) $(OUTPUTS) $(MEMORY) $(FPU_OUT)
	@mkdir -p $(OUT)
	-@if [ "$(mod)" = "" ]; then \
		echo "No module provided - try with make mod=foo" ; \
	else \
		printf "Simulating %s\n" $(mod) ; \
		printf "$(VSIM)" $(mod) | vsim > $(VSIM_LOG); \
		python test/setup.py $(VSIM_LOG); \
	fi

.PHONY : constants
constants : out/constants.o
	./out/constants.o

.PHONY : assembler
assembler :
	python assembler/test.py

$(OUT)/%.o : $(SRC)/%.c
	mkdir -p $(OUT)
	$(GCC) $< -lm -o $@

$(WORK) :
	$(VLIB) $(WORK)

$(OUTPUTS) : $(WORK)/%/_primary.vhd : %.v
	$(VLOG) "$<"

$(OUT)/%.mem : $(ASM)/%.s assembler/main.py
	mkdir -p $(OUT)
	$(ASSEMBLER) $< -o $@ -m ./cpu.mif
	mkdir -p $(SIMULATION)/$(OUT)
	cp $@ $(SIMULATION)/$@

cpu.mif : $(MIF_ASM) assembler/main.py
	$(ASSEMBLER) $< -m ./cpu.mif
