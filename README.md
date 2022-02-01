# CPU Design Project

![Automated Build and Test](https://github.com/alcatrazEscapee/elec-374/actions/workflows/test.yml/badge.svg)

Lorem Ipsum.

### Specification

#### Instruction Types

Type | Fields
---|---
R - Three Register         | `[5b - opcode][4b - rA][4b - rB][4b - rC][15b - Unused]`
I - Two Register Immediate | `[5b - opcode][4b - rA][4b - rB][19b ------ Constant C]`
B - Branch                 | `[5b - opcode][4b - rA][4b - C2][19b ------ Constant C]`
J - Jump / IO              | `[5b - opcode][4b - rA][23b ------------------- Unused]`
M - Misc / Special         | `[5b - opcode][27b ---------------------------- Unused]`

#### Instruction Table

Notes:

- The below instructions are instructions as interpreted by the hardware. The assembler may implement pseudoinstructions (such as `mov rA, rB`) which are implemented as alises to existing instructions (such as `add rA, rB, r0`).
- Some `R` type instructions use only a subset of the available registers, but unless otherwise noted:
  - `rA` is the first register, and is the register used to write to the register file.
  - `rB` is the left (`a`) input to the ALU
  - `rC` is the right (`c`) input to the ALU

Index | Opcode | Name | Assembly | RTN
---|---|---|---|---
0 | `00000` | Load | `ld rA, C(rB)` | `rA <- Memory[rB + C]`
1 | `00001` | Load Immediate | `ldi rA, C(rB)` | `rA <- rB + C`
2 | `00010` | Store | `st C, rA` | `Memory[rB + C] <- rA`
3 | `00011` | Add | `add rA, rB, rC` | `rA <- rB + rC`
4 | `00100` | Subtract | `sub rA, rB, rC` | `rA <- rB - rC`
5 | `00101` | Shift Right | `shr rA, rB, rC` | `rA <- rB >> rC`
6 | `00110` | Shift Left | `shl rA, rB, rC` | `rA <- rB << rC`
7 | `00111` | Rotate Right | `ror rA, rB, rC` | `rA <- (rB >> rC) or (rB << (32 - rB))`
8 | `01000` | Rotate Left | `rol rA, rB, rC` | `rA <- (rB << rC) or (rB >> (32 - rB))`
9 | `01001` | And | `and rA, rB, rC` | `rA <- rB & rC`
10 | `01010` | Or | `or rA, rB, rC` | `rA <- rB or rC`
11 | `01011` | Add Immediate | `addi rA, rB, C` | `rA <- rB + C`
12 | `01100` | And Immediate | `andi rA, rB, C` | `rA <- rB & C`
13 | `01101` | Or Immediate | `ori rA, rB, C` | `rA <- rB or C`
14 | `01110` | Multiply | `mul rB, rC` | `HI, LO <- rB * rC`
15 | `01111` | Divide | `div rB, rC` | `HI, LO <- rB / rC`
16 | `10000` | Negate | `neg rA, rB` | `rA <- -rB`
17 | `10001` | Not | `not rA, rB` | `rA <- ~rB`
18 | `10010` | Conditional Branch | `br<condition> rA, C` | `if condition(rA), PC <- PC - 4 + C`
19 | `10011` | Jump (Return) | `jr` | `PC <- r15`
20 | `10100` | Jump and Link (Call) | `jal rA` | `r15 <- PC - 4, PC <- rA`
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
`01` | Branch if negative | `rA < 0`

#### (Possible) Planned Instructions and Instruction Types

Floating point support:

- Floating point IEE-745, single precision standard.
- There is a seperate register file of floating point registers.
- Copies between the `RF` and `FF` units can be acomplished by either copy instructions, or cast instructions
- Floating point operations apply directly to floating point opcodes.

Type | Fields
---|---
R - Floating Point | `[5b - opcode][4b - FA][4b - FB][4b - FC][15b - FPU Opcode]`

Index | Opcode | Name | Assembly | RTN
---|---|---|---|---
27 | `11011` | Floating Point | Various | Various

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

### Instruction RTN

- Unless otherwise specified, `rX`, `rY`, `rZ` has the same meaning as `rA`, `rB`, and `rC` as above.

#### Instruction Fetch (Common to all instructions):

- T0 `PC <- PC + 4`, `MA <- PC`
- T1 `MD <- Memory[MA]`
- T2 `IR <- MD`

Three Register (`add`, `sub`, `shr`, `shl`, `ror`, `rol`, `and`, `or`): `op rX, rY, rZ`

- T3 `rX <- rY <op> rZ`

Two Register (`neg`, `not`): `op rX, rY`

- T3 `rX <- rY <op> r0`

Two Register Double (`mul`, `div`): `op rY, rZ`

- T3 `HI, LO <- rY <op> rZ`

Move Instructions (`mfhi`, `mflo`, `in`): `mov rX`

- T3 `rX <- <target>`

Output: `out rY`

- T3 `<output> <- rY`

Two Register Immediate (`ldi`, `addi`, `andi`, `ori`): `op rX, rY, C`

- T3 `rX <- rY <op> C`

Load: `ld rX, C(rY)`

- T3 `MA <- rY + C`
- T4 `MD <- Memory[MA]`
- T5 `rX <- MD`

Store: `st rX, C(rY)`

- T3 `MA <- rY + C`
- T4 `Memory[MA] <- MD`

Conditional Branch: `br<condition> rX, C`

- T3 `if condition(rX) PC <- PC - 4 + C`

Jump (Return): `jr`

- T3 `PC <- r15`

Jump And Link (Call): `jal rX`

- T3 `r15 <- PC + 4`, `PC <- rX`


### Testing

Testing is built on compiling the Verilog via command line, using the Altera ModelSim libraries. ModelSim is then invoked via command line to produce text output. A python script is used to verify the output and produce test results.

Requirements:

- `vsim` must be on your PATH (Default: `C:\altera\13.0sp1\modelsim_ase\win32aloem`)
- `make` and `python`

Setup:

- In each source file with a module `module foo`, create a `module foo_test` to run tests.
- In the test module, use a `$display("Test | <test name> | <expected value> | <actual value>");` to indicate the presence of expected/actual values.
- Finish the test with a `$finish;` statement.

Running:

- Running all tests: `make all`
- Running a specific test (the `foo` module): `make mod=foo`


#### Resources

- [HDL Bits - Verilog Practice](https://hdlbits.01xz.net/wiki/Main_Page)
- [Quartus II Testbench Tutorial](https://class.ece.uw.edu/271/peckol/doc/DE1-SoC-Board-Tutorials/ModelsimTutorials/QuartusII-Testbench-Tutorial.pdf)
  - [More Advanced Testbench Tutorial, in Verilog](http://www-classes.usc.edu/engr/ee-s/254/ee254l_lab_manual/Testbenches/handout_files/ee254_testbench.pdf)
- [HDL Testing on Github Actions](https://purisa.me/blog/testing-hdl-on-github/)
