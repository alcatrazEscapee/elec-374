# CPU Design Project

Lorem Ipsum.

### Specification

#### Instruction Types

Type | Fields
---|---
R - Three Register         | `[5b - opcode][4b - RA][4b - RB][4b - RC][15b - Unused]`
I - Two Register Immediate | `[5b - opcode][4b - RA][4b - RB][19b ------ Constant C]`
B - Branch                 | `[5b - opcode][4b - RA][4b - C2][19b ------ Constant C]`
J - Jump / IO              | `[5b - opcode][4b - RA][23b ------------------- Unused]`
M - Misc / Special         | `[5b - opcode][27b ---------------------------- Unused]`

#### Instruction Table

Note: the below instructions are instructions as interpreted by the hardware. The assembler may implement pseudoinstructions (such as `mov rA, rB`) which are implemented as alises to existing instructions (such as `add rA, rB, r0`).

Index | Opcode | Name | Assembly | RTN
---|---|---|---|---
0 | `00000` | Load | `ld rA, C(rB)` | `rA <- Memory[rB + C]`
1 | `00001` | Load Immediate | `ldi rA, C(rB)` | `rA <- rB + C`
2 | `00010` | Store | `st C, rA` | `Memory[rB + C] <- rA`
3 | `00011` | Add | `add rA, rB, rC` | `rA <- rB + rC`
4 | `00100` | Subtract | `sub rA, rB, rC` | `rA <- rB - rC`
5 | `00101` | Shift Right | `shr rA, rB, rC` | `rA <- rB >> rC`
6 | `00110` | Shift Left | `shl rA, rB, rC` | `rA <- rB << rC`
7 | `00111` | Rotate Right | `ror rA, rB, rC` | `rA <- (rB >> rC) | (rB << (32 - rB))`
8 | `01000` | Rotate Left | `rol rA, rB, rC` | `rA <- (rB << rC) | (rB >> (32 - rB))`
9 | `01001` | And | `and rA, rB, rC` | `rA <- rB & rC`
10 | `01010` | Or | `or rA, rB, rC` | `rA <- rB | rC`
11 | `01011` | Add Immediate | `addi rA, rB, C` | `rA <- rB + C`
12 | `01100` | And Immediate | `andi rA, rB, C` | `rA <- rB & C`
13 | `01101` | Or Immediate | `ori rA, rB, C` | `rA <- rB | C`
14 | `01110` | Multiply | `mul rA, rB` | `HI, LO <- rA * rB`
15 | `01111` | Divide | `div rA, rB` | `HI, LO <- rA / rB`
16 | `10000` | Negate | `neg rA, rB` | `rA <- -rB`
17 | `10001` | Not | `not rA, rB` | `rA <- ~rB`
18 | `10010` | Conditional Branch | `br<condition> rA, C` | `if condition(rA), PC <- PC + 1 + C`
19 | `10011` | Jump (Return) | `jr` | `PC <- r15`
20 | `10100` | Jump and Link (Call) | `jal rA` | `r15 <- PC + 1, PC <- rA`
21 | `10101` | Input | `in rA` | `rA <- Input`
22 | `10110` | Output | `out rA` | `Output <- rA`
23 | `10111` | Move from HI | `mfhi rA` | `rA <- HI`
24 | `11000` | Move from LO | `mflo rA` | `rA <- LO`
25 | `11001` | Noop | `nop` | Noop
26 | `11010` | Halt | `halt` | Halt and Catch Fire
27 | `11011` | Unused 1 | `?` | Noop
28 | `11100` | Unused 2 | `?` | Noop
29 | `11101` | Unused 3 | `?` | Noop
30 | `11110` | Unused 4 | `?` | Noop
31 | `11111` | Unused 5 | `?` | Noop

Branch Instructions use the `C2` field to determine the type of condition:

`C2` | Condition | RTN
---|---|---
`00` | Branch if zero | `rA == 0`
`01` | Branch if nonzero | `rA != 0`
`10` | Branch if positive | `rA > 0`
`01` | Branch if negative | `rA < 0 

#### (Possible) Planned Instructions and Instruction Types

Type | Fields
---|---
R - Floating Point | `[5b - opcode][4b - FA][4b - FB][4b - FC][15b - FPU Opcode]`

Index | Opcode | Name | Assembly | RTN
---|---|---|---|---
27 | `11011` | XOR | `xor rA, rB, rC` | `rA <- rB ^ rC`
28 | `11100` | XNOR | `xnor rA, rB, rC` | `rA <- ~(rB ^ rC)`
29 | `11101` | NOR | `nor rA, rB, rC` | `rA <- ~(rB | rC)`
30 | `11110` | NAND | `nand rA, rB, rC` | `rA <- ~(rB & rC)`
31 | `11111` | Floating Point | Various | Various

Floating point operations use the `FPU Opcode` to determine their actual operation:

`FPU Opcode` | Name | Assembly | RTN
---|---|---|---
`000` | Copy Register to FPU | `mvrf fA, rB` | `fA <- rB`
`001` | Copy FPU to Register | `mvfr rA, fB` | `rA <- fB`
`010` | Cast Register to Float | `crf fA, rB` | `fA <- (float) rB`
`011` | Cast Float to Register | `cfr rA, fB` | `rA <- (int) fB`
`100` | Float Add | `fadd fA, fB, fC` | `fA <- fB + fC`
`101` | Float Subtract | `fsub fA, fB, fC` | `fA <- fB - fC`
`110` | Float Multiply | `fmul fA, fB, fC` | `fA <- fB * fC`


### Testing

Simple automated tests ran through python, invoking Altera ModelSim via command line.

- `vsim` must be on your PATH (Default: `C:\altera\13.0sp1\modelsim_ase\win32aloem`)

Setup:

- In a source file (`foo.v`) with the top level module (`module foo`), declare a test module `module foo_test`
- In the test module, use a `$display("Test | <test name> | <expected value> | <actual value>");` to indicate the presence of expected/actual values.
- Generate the test files `test/foo.do` and `test/foo.py`
  - Automatically: `python test/setup.py generate foo`

Running:

- Run `python -m unittest discover test -p '*.py'`

Example output:

```
$ python -m unittest discover test -p '*.py'
Running vsim < test/alu_shift_left.do
Reading C:/altera/13.0sp1/modelsim_ase/tcl/vsim/pref.tcl

vlog +acc "alu_shift_left.v"
# Model Technology ModelSim ALTERA vlog 10.1d Compiler 2012.11 Nov  2 2012
# -- Compiling module alu_shift_left
# -- Compiling module alu_shift_left_test
#
# Top level modules:
#       alu_shift_left_test
vsim -voptargs=+acc work.alu_shift_left_test
# vsim -voptargs=+acc work.alu_shift_left_test
# Loading work.alu_shift_left_test
# Loading work.alu_shift_left
run 100ns
#
# <EOF>

....
----------------------------------------------------------------------
Ran 4 tests in 0.000s

OK
```

#### Resources

- [HDL Bits - Verilog Practice](https://hdlbits.01xz.net/wiki/Main_Page)
- [Quartus II Testbench Tutorial](https://class.ece.uw.edu/271/peckol/doc/DE1-SoC-Board-Tutorials/ModelsimTutorials/QuartusII-Testbench-Tutorial.pdf)
  - [More Advanced Testbench Tutorial, in Verilog](http://www-classes.usc.edu/engr/ee-s/254/ee254l_lab_manual/Testbenches/handout_files/ee254_testbench.pdf)
