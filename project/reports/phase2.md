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

### Testing ld r1, 85

The `ld` instruction has the following RTN:

- T0: `PC <- PC + 1`, `MA <- PC`
- T1: `MD <- Memory[MA]`
- T2: `IR <- MD`
- T3: `MA <- rY + C`
- T4: `MD <- Memory[MA]`
- T5: `rX <- MD`

The memory at address `85` was initialized to `0xa`.  In T3, `constant_c` is set to `0x55` = `85`, to calculate the memory address in `MA`. In T5, the `memory_out` signal containing the contents of `MD`, equal to `0xA` is loaded into the register file `r1` register.

![ld r1, 85](./phase2/ld_r1_85.png)

### Testing ld r0, 35(r1)

The memory at address `45` = `0xA + 35` was initialized to `0xdeadbeef`. In T3, `constant_c` is set to `0x23` = `35`. The value of `r1` is also mapped to the ALU 'a' input signal, resulting in the address `0x2D` loaded into `MA`. In T5, the `memory_out` signal containing the contents of `MD`, equal to `0xdeadbeef` is loaded into the register file `r0` register.

![ld r0, 35(r1)](./phase2/ld_r0_35_r1.png)

### Testing ldi r1, 85

The `ldi` instruction has the following RTN:

- T0: `PC <- PC + 1`, `MA <- PC`
- T1: `MD <- Memory[MA]`
- T2: `IR <- MD`
- T3: `rX <- rY + C`

In `T3`, the `constant_c` is set to `0x55` = `85`, and the ALU 'a' input is set to zero. As a result, `r1` is loaded with the value `85`.

![ldi r1, 85](./phase2/ldi_r1_85.png)

### Testing ldi r0, 35(r1)

In this case, the value of `r0` is set to the sum of `r1` (85, from the previous instruction), and 35 (the `constant_c` signal). In T3, both values are present in the ALU inputs, and loaded into `r0`.

![ldi r0, 35(r1)](./phase2/ldi_r0_35_r1.png)

### Testing st 90, r1

The `st` instruction has the following RTN:

- T0: `PC <- PC + 1`, `MA <- PC`
- T1: `MD <- Memory[MA]`
- T2: `IR <- MD`
- T3: `MA <- rY + C`
- T4: `Memory[MA] = rX` (Memory Write)

In T3, the `constant_c` signal is set to `0x5A` = `90`, and in T4, the `MA` output is loaded as `90`, due to the implicit presence of `r0`, despite the `r0` register having a non-zero value. In `T4`, the value of r1 is sent to the memory, and `85` is loaded at memory address `0x5A`.

![st 90, r1](./phase2/st_90_r1.png)

### Testing st 90(r1), r1

In this case, the `constant_c` signal is set to `0x5A`, and the 'a' input to the ALU is set to the value of `r1`, resulting in `MA` being loaded with `0xAF`. In `T4`, the value of r1 is sent to the memory, and `85` is loaded at memory address `0xAF`.

![st 90, 90(r1)](./phase2/st_90_r1_r1.png)

### Testing addi r2, r1, -5

The `addi` instruction has the same RTN as the `ldi` instruction:

- T0: `PC <- PC + 1`, `MA <- PC`
- T1: `MD <- Memory[MA]`
- T2: `IR <- MD`
- T3: `rX <- rY + C`

In `T3`, the value of r1 is present in the ALU 'a' input, and the sign-extended `constant_c` signal, `0xFFFFFFFB` = `-5` is present in the ALU 'b' input, and the sum `0x50` is loaded into the r2 register.

![addi r2, r1, -5](./phase2/addi_r2_r1_-5.png)

### Testing andi r2, r1, 26

The `andi` instruction has the following RTN:

- T0: `PC <- PC + 1`, `MA <- PC`
- T1: `MD <- Memory[MA]`
- T2: `IR <- MD`
- T3: `rX <- rY & C`

In `T3`, the value of r1 is present in the ALU 'a' input, and the sign-extended `constant_c` signal, `0x1A`, is present in the ALU 'b' input, and the bitwise and of the inputs, `0x10` is loaded into the r2 register.

![andi r2, r1, 26](./phase2/andi_r2_r1_26.png)

### Testing ori r2, r1, 26

The `ori` instruction has the following RTN:

- T0: `PC <- PC + 1`, `MA <- PC`
- T1: `MD <- Memory[MA]`
- T2: `IR <- MD`
- T3: `rX <- rY | C`

In `T3`, the value of r1 is present in the ALU 'a' input, and the sign-extended `constant_c` signal, `0x1A`, is present in the ALU 'b' input, and the bitwise and of the inputs, `0x5F` is loaded into the r2 register.

![ori r2, r1, 26](./phase2/ori_r2_r1_26.png)


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
