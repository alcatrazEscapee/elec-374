# CPU Design Project: Heart of Gold (HoG)

![Automated Build and Test](https://github.com/alcatrazEscapee/elec-374/actions/workflows/test.yml/badge.svg)

### Specification

#### Instruction Types

| Type                       | Fields                                                   |
| -------------------------- | -------------------------------------------------------- |
| R - Three Register         | `[5b - opcode][4b - rA][4b - rB][4b - rC][15b - Unused]` |
| I - Two Register Immediate | `[5b - opcode][4b - rA][4b - rB][19b ------ Constant C]` |
| B - Branch                 | `[5b - opcode][4b - rA][4b - C2][19b ------ Constant C]` |
| J - Jump / IO              | `[5b - opcode][4b - rA][23b ------------------- Unused]` |
| M - Misc / Special         | `[5b - opcode][27b ---------------------------- Unused]` |

#### Instruction Table

Notes:

- The below instructions are instructions as interpreted by the hardware. The assembler may implement pseudo-instructions (such as `mov rA, rB`) which are implemented as aliases to existing instructions (such as `add rA, rB, r0`).
- Some `R` type instructions use only a subset of the available registers, but unless otherwise noted:
  - `rA` is the first register, and is the register used to write to the register file.
  - `rB` is the left (`a`) input to the ALU
  - `rC` is the right (`c`) input to the ALU

| Index | Opcode  | Name                     | Assembly              | RTN                                     |
| ----- | ------- | ------------------------ | --------------------- | --------------------------------------- |
| 0     | `00000` | Load                     | `ld rA, C(rB)`        | `rA <- Memory[rB + C]`                  |
| 1     | `00001` | Load Immediate           | `ldi rA, C(rB)`       | `rA <- rB + C`                          |
| 2     | `00010` | Store                    | `st C(rB), rA`        | `Memory[rB + C] <- rA`                  |
| 3     | `00011` | Add                      | `add rA, rB, rC`      | `rA <- rB + rC`                         |
| 4     | `00100` | Subtract                 | `sub rA, rB, rC`      | `rA <- rB - rC`                         |
| 5     | `00101` | Shift Right              | `shr rA, rB, rC`      | `rA <- rB >> rC`                        |
| 6     | `00110` | Shift Left               | `shl rA, rB, rC`      | `rA <- rB << rC`                        |
| 7     | `00111` | Rotate Right             | `ror rA, rB, rC`      | `rA <- (rB >> rC) or (rB << (32 - rB))` |
| 8     | `01000` | Rotate Left              | `rol rA, rB, rC`      | `rA <- (rB << rC) or (rB >> (32 - rB))` |
| 9     | `01001` | And                      | `and rA, rB, rC`      | `rA <- rB & rC`                         |
| 10    | `01010` | Or                       | `or rA, rB, rC`       | `rA <- rB or rC`                        |
| 11    | `01011` | Add Immediate            | `addi rA, rB, C`      | `rA <- rB + C`                          |
| 12    | `01100` | And Immediate            | `andi rA, rB, C`      | `rA <- rB & C`                          |
| 13    | `01101` | Or Immediate             | `ori rA, rB, C`       | `rA <- rB or C`                         |
| 14    | `01110` | Multiply                 | `mul rB, rC`          | `HI, LO <- rB * rC`                     |
| 15    | `01111` | Divide                   | `div rB, rC`          | `HI, LO <- rB / rC`                     |
| 16    | `10000` | Negate                   | `neg rA, rB`          | `rA <- -rB`                             |
| 17    | `10001` | Not                      | `not rA, rB`          | `rA <- ~rB`                             |
| 18    | `10010` | Conditional Branch       | `br<condition> rA, C` | `if condition(rA), PC <- PC + C`        |
| 19    | `10011` | Jump (Return)            | `jr rA`               | `PC <- rA`                              |
| 20    | `10100` | Jump and Link (Call)     | `jal rA`              | `rA <- PC + 1, PC <- rA`                |
| 21    | `10101` | Input                    | `in rA`               | `rA <- Input`                           |
| 22    | `10110` | Output                   | `out rA`              | `Output <- rA`                          |
| 23    | `10111` | Move from HI             | `mfhi rA`             | `rA <- HI`                              |
| 24    | `11000` | Move from LO             | `mflo rA`             | `rA <- LO`                              |
| 25    | `11001` | Noop                     | `nop`                 | Noop                                    |
| 26    | `11010` | Halt                     | `halt`                | Halt and Catch Fire                     |
| 27    | `11011` | Floating Point Operation | Various               | Various                                 |
| 28    | `11100` | Unused 2                 | `?`                   | Noop                                    |
| 29    | `11101` | Unused 3                 | `?`                   | Noop                                    |
| 30    | `11110` | Unused 4                 | `?`                   | Noop                                    |
| 31    | `11111` | Unused 5                 | `?`                   | Noop                                    |

Branch Instructions use the `C2` field to determine the type of condition:

| `C2` | Condition          | RTN       |
| ---- | ------------------ | --------- |
| `00` | Branch if zero     | `rA == 0` |
| `01` | Branch if nonzero  | `rA != 0` |
| `10` | Branch if positive | `rA > 0`  |
| `01` | Branch if negative | `rA < 0`  |

#### Floating Point Support

The processor has a floating point unit, capable of doing a select operations defined by the IEEE-754, single precision, floating point (`binary32`) standard. There is a single floating point instruction, which uses the `FPU` opcode to determine what action it takes. The FPU supports the following operations:

- Casts of both signed and unsigned integers (Completely IEEE-754 compliant).
- Addition, subtraction and multiplication of floating point values.
- Floating point reciprocal using an approximate algorithm, (see [Resources](#resources)).
- `==` and `>` comparisons.

The FPU defines one additional instruction type:

| Type               | Fields                                                                    |
| ------------------ | ------------------------------------------------------------------------- |
| F - Floating Point | `[5b - opcode][4b - FA][4b - FB][4b - FC][11b - Unused][4b - FPU Opcode]` |

The "Floating Point" instruction has the following subinstructions based on the FPU opcode:

| FPU Opcode | Name                              | Assembly          | RTN                               |
| ---------- | --------------------------------- | ----------------- | --------------------------------- |
| `0000`     | Cast Register to Float            | `crf fA, rB`      | `fA <- (float) rB`                |
| `0001`     | Cast Float to Register            | `cfr rA, fB`      | `rA <- (int) fB`                  |
| `0010`     | Cast Register to Float (Unsigned) | `curf fA, rB`     | `fA <- (float) (unsigned int) rB` |
| `0011`     | Cast Float to Register (Unsigned) | `cufr rA, fB`     | `rA <- (unsigned int) fB`         |
| `0100`     | Float Add                         | `fadd fA, fB, fC` | `fA <- fB + fC`                   |
| `0101`     | Float Subtract                    | `fsub fA, fB, fC` | `fA <- fB - fC`                   |
| `0110`     | Float Multiply                    | `fmul fA, fB, fC` | `fA <- fB * fC`                   |
| `0111`     | Float Reciprocal                  | `frc fA, fB`      | `fA <- 1.0f / fC` (Approximate)   |
| `1000`     | Float Greater Than                | `fgt rA, fB, fC`  | `rA <- fB > fC`                   |
| `1010`     | Float Equals                      | `feq rA, fB, fC`  | `rA <- fB == fC`                  |

### Instruction RTN

- Unless otherwise specified, `rX`, `rY`, `rZ` has the same meaning as `rA`, `rB`, and `rC` as above.

#### Instruction Fetch (Common to all instructions):

- T1 `PC <- PC + 1`, `MD <- Memory[PC]`
- T2 `IR <- MD`

Three Register (`add`, `sub`, `shr`, `shl`, `ror`, `rol`, `and`, `or`, all FPU except `frc`): `op rX, rY, rZ`

- T3 `rX <- rY <op> rZ`

Two Register (`neg`, `not`): `op rX, rY`

- T3 `rX <- rY <op> r0`

Multiply: `mul rY, rZ`

- T3 `HI, LO <- rY * rZ`

Divide: `div rY, rZ`

- DIV0 ... DIV30: `HI, LO <- RY / rZ`

FPU Reciprocal: `frc f1 f2`

- R0 ... R7: `f1 <- 1.0f / f2`

Move Instructions (`mfhi`, `mflo`, `in`): `mov rX`

- T3 `rX <- <target>`

Output: `out rY`

- T3 `<output> <- rY`

Two Register Immediate (`ldi`, `addi`, `andi`, `ori`): `op rX, rY, C`

- T3 `rX <- rY <op> C`

Load: `ld rX, C(rY)`

- T3 `MA <- rY + C`
- T4 Memory Read
- T5 `rX <- Memory[MA]`

Store: `st C(rY), rX`

- T3 `MA <- rY + C`
- T4 `Memory[MA] <- rX`, Memory Write

Conditional Branch: `br<condition> rX, C`

- T3 `if condition(rX) PC <- PC + C`

Jump (Return): `jr rX`

- T3 `PC <- rX`

Jump And Link (Call): `jal rX`

- T3 `r15 <- PC`, `PC <- rX`

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
- [Altera TimeQuest Timing Analyzer - Quick Start Tutorial](https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/hb/qts/ug_tq_tutorial.pdf)
- [Altera Best Practices for the Quartus II TimeQuest Timing Analyzer](https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/hb/qts/qts_qii53024.pdf)
- [754-2019 - IEEE Standard for Floating-Point Arithmetic](https://ieeexplore.ieee.org/document/8766229)
- [IEEE - An Effective Floating-Point Reciprocal](https://ieeexplore.ieee.org/document/8525803)
- [ISO/IEC 9899:201x - C Programming Language Standard](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n1548.pdf)