# ELEC 374 Project Phase 2 Report

**Group 42**

- Alex O'Neill, 20043101, 16amon
- Jared McGrath, 20053313, 16jtm2

## 1. Design Overview

Our design was made entirely in Verilog, using no arithmetic operators (`+`, `-`, `/` or `*`), and also implementing some logical operators (left and right shifts and rotates) entirely from scratch. We also implemented various techniques for faster addition, including a Carry Lookahead Adder and Carry Save Adder, both of which are utilized in the Multiplier.

The structure of our design is based on the 3-bus architecture referenced in the lab reader. This allowed us to remove the now redundant `A`, `B`, `Y`, and `Z` registers, and greatly simplify interconnections between components of our datapath.

In addition to the specification in the Phase 1 and 2 documents, and the lab reader, we also implemented a IEEE-754 compliant floating point unit, which supports the following operations:

- Casts (both signed and unsigned) to and from integers.
- Floating point addition, subtraction, and multiplication, and recriprocal.

All of the modules we wrote have testbench modules included in the same module - for example, the `cpu` module has a `cpu_test` module both declared in the `cpu.v` file. We used a combination of a Makefile, and the ModelSim command line interface in order to run automatic tests. We use `$display()` calls to observe expected and actual outputs, and then report any differences by simulating the designs.

All our code is included in the attached `.zip` file. The module structure of the design is as follows:

- `cpu` : The top level module.
	- `register_file` : The general purpose register file for registers `r0` - `r15`
	- `register` : A simple register used for `PC`, `IR`, `MD`, `MA`, `HI` and `LO` registers.
	- `alu` : The ALU, containing all basic arithmetic and logic operations, some in sub-modules.
	- `fpu` : The Floating Point Unit, containing all floating point arithmetic operations. Interfaces with the ALU (in order to do floating point multiplication).
	- `memory` : The main instruction and data memory, written in Verilog and inferred by Quartus into built-in memory blocks.

## 2. Testbench Waveforms

We tested all the required instructions in a single test module (the `cpu_test` one), via simulating them sequentially as they pass through the cpu. For this, we used the assembly program (included with the project submission, in `cpu_testbench.s`), which we wrote a primitive assembler to compile to a `.mem` file, which was loaded with Verilog's `$readmemh()` for the purpose of our testbench. The compiled output of this program is visible in `cpu_testbench.mem`, which is included with our Verilog code.

// todo: view of the memory

// todo: tests for ALL the instructions
// Waveforms are already screenshoted, and are all consistient.

ld r1, 85
ld r0, 35(r1) // Loads from 35 + 10
ldi r1, 85
ldi r0, 35(r1)
st 90, r1
st 90(r1), r1
addi r2, r1, -5
andi r2, r1, 26
ori r2, r1, 26
brzr r2, 35
brnz r2, 35 // Will branch to 60, branches back after
brpl r2, 35 // Will branch to 61, branches back after
jump_back_2:
brmi r2, 35
jal r1 // Will jump to r1 = 62
mfhi r2
mflo r2
out r1
in r1
