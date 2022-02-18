# ELEC 374 Project Phase 1 Report

**Group 42**

- Alex O'Neill, 20043101, 16amon
- Jared McGrath, 12345678, 16mickyd

## 1. Design Overview

Our design was made entirely in Verilog, using no arithmetic operators (`+`, `-`, `/` or `*`), and also implementing some logical operators (left and right shifts and rotates) entirely from scratch. We also implemented various techniques for faster addition, including a Carry Lookahead Adder and Carry Save Adder, both of which are utilized in the Multiplier.

The structure of our design is based on the 3-bus architecture referenced in the lab reader. This allowed us to remove the now redundant `A`, `B`, `Y`, and `Z` registers, and greatly simply interconnections between components of our datapath.

All of the modules we wrote have testbench modules included in the same module - for example, the `datapath` module has a `datapath_test` module both declared in the `datapath.v` file. We used a combination of a Makefile, and the ModelSim command line interface in order to run automatic tests. We use `$display()` calls to observe expected and actual outputs, and then report any differences by simulating the designs.

All our code is included in the attached `.zip` file. All verilog code is contained in the `hdl` folder. The module structure of the design is as follows:

- `cpu` : The top level module (empty, except for creating a `datapath` in Phase 1)
    - `datapath` : Contains all Phase 1 logic
	    - `alu` : The ALU, containing all ALU operations required for Phase 1 in various sub-modules.
		- `register_file` : The general purpose register file for registers `r0` - `r15`
		- `register` : A simple register used for `PC`, `IR`, `MD`, `MA`, `HI` and `LO` registers.

## 2. Testbench Waveforms

We tested all the required datapath instructions in a single test module (the `datapath_test` one), via simulating them sequentially as they pass through the datapath.
