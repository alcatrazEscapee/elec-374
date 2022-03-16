# CPU Design Project

![Automated Build and Test](https://github.com/alcatrazEscapee/elec-374/actions/workflows/test.yml/badge.svg)

Lorem Ipsum.

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

- The below instructions are instructions as interpreted by the hardware. The assembler may implement pseudoinstructions (such as `mov rA, rB`) which are implemented as alises to existing instructions (such as `add rA, rB, r0`).
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

The processor has a floating point unit, capable of doing a select operations defined by the IEEE-754, single percision, floating point (`binary32`) standard. There is a single floating point instruction, which uses the `FPU` opcode to determine what action it takes. The FPU supports the following operations:

- Casts of both signed and unsigned integers (Completely IEEE-754 compliant).
- Addition, subtraction and multiplication of floating point values.
- Floating point reciprocal using an approximate algorithim, (see [Resources](#resources)).
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

## Datapath & Control Signals

Below is a summary of important wires and control signals in the data path. **This is not an exhaustive list, and is not updated to reflect all phase 3 reorganizations.**

### Datapath

The following components are central to the datapath, all instantiated within the `cpu` module, with various interconnections between them.

| Name      | Module          | Description                                                                           |
| --------- | --------------- | ------------------------------------------------------------------------------------- |
| `_rf`     | `register_file` | 16-word 32-bit primary register file                                                  |
| `_memory` | `memory`        | 512-word 32-bit main memory                                                           |
| `_alu`    | `alu`           | ALU                                                                                   |
| `_fpu`    | `fpu`           | Floating point unit co-processor                                                      |
| `_pc`     | `register`      | 32-bit PC register                                                                    |
| `_ir`     | `register`      | 32-bit IR register                                                                    |
| `_ma`     | `register`      | 32-bit MA special register, containing memory address                                 |
| `_hi`     | `register`      | 32-bit HI special register, containing partial result of `div` and `mul` instructions |
| `_lo`     | `register`      | 32-bit LO special register, containing partial result of `div` and `mul` instructions |
| `_in`     | `register`      | 32-bit IN special register, representing the input port                               |
| `_out`    | `register`      | 32-bit OUT special register, representing the output port                             |

There is also an instantiation of `ripple_carry_adder`, named `_pc_adder`, which computes `PC + 1`.

### Internal Bus Connections

Bus interconnection wires are listed under the datapath component that 'owns' them.

**Notes:**

- A common clock `clk` and asynchronous clear `clr` is connected to all components, both of which are inputs to the `cpu` module
- An asterisk (\*) beside a wire name denotes a data wire that is accessible via input/output port of `cpu` module

#### `_rf`

| Name        | Description    | Width | Expression                  |
| ----------- | -------------- | ----- | --------------------------- |
| `rf_in`     | Data in        | 32    |                             |
| `rf_z_addr` | Write address  | 4     |                             |
| `rf_a_addr` | Read address A | 4     |                             |
| `rf_b_addr` | Read address B | 4     |                             |
| `rf_a_out`  | Read data A    | 32    | `rf_a_out <- RF[rf_a_addr]` |
| `rf_b_out`  | Read data B    | 32    | `rf_b_out <- RF[rf_b_addr]` |

#### `_memory`

| Name         | Description | Width | Expression                     |
| ------------ | ----------- | ----- | ------------------------------ |
| `memory_out` | Read data   | 32    | `memory_out <- Memory[ma_out]` |

Note: we don't need `memory_in` because it's always wired to `rf_b_out`.

#### `_alu`

| Name         | Description                        | Width | Expression                                                                          |
| ------------ | ---------------------------------- | ----- | ----------------------------------------------------------------------------------- |
| `alu_a_in`   | Data in A                          | 32    |                                                                                     |
| `alu_b_in`   | Data in B                          | 32    |                                                                                     |
| `alu_z_out`  | Output for all but `mul` and `div` | 32    | `alu_z_out <- alu_a_in <op alu_select> alu_b_in`                                    |
| `alu_hi_out` | HI output for `mul` and `div`      | 32    | `alu_hi_out <- alu_a_in % alu_b_in` or `alu_hi_out <- (alu_a_in * alu_b_in)[63:32]` |
| `alu_lo_out` | LO output for `mul` and `div`      | 32    | `alu_hi_out <- alu_a_in // alu_b_in` or `alu_hi_out <- (alu_a_in * alu_b_in)[31:0]` |
| `rf_a_out`   | Read data A                        | 32    | `rf_a_out <- RF[rf_a_addr]`                                                         |
| `rf_b_out`   | Read data B                        | 32    | `rf_b_out <- RF[rf_b_addr]`                                                         |

#### Registers

Most registers have identical data wires that follow a common naming convention

| Name           | Description     | Width |
| -------------- | --------------- | ----- |
| `pc_in`        | `_pc` Data in   | 32    |
| `pc_out`       | `_pc` Data out  | 32    |
| `ir_out`\*     | `_ir` Data out  | 32    |
| `ma_in`        | `_ma` Data in   | 32    |
| `ma_out`       | `_ma` Data out  | 32    |
| `hi_out`       | `_hi` Data out  | 32    |
| `lo_out`       | `_lo` Data out  | 32    |
| `input_in`\*   | `_in` Data in   | 32    |
| `input_out`    | `_in` Data out  | 32    |
| `output_out`\* | `_out` Data out | 32    |

Exceptions to this scheme:

- `_ir` does not have its own input; input is always `memory_out`
- `_hi` and `_lo` do not have their own inputs; they use the ALU's `alu_hi_out` and `alu_lo_out`, respectively
- `_out` does not have its own input; input is always `rf_a_out`

#### `_fpu`

| Name               | Description                                          | Width | Expression |
| ------------------ | ---------------------------------------------------- | ----- | ---------- |
| `fpu_rz_out`       | Output of FPU                                        | 32    |            |
| `fpu_bridge_alu_a` | Passthrough to ALU in B for `fmul` if `fpu_mode = 1` | 32    |            |
| `fpu_bridge_alu_b` | Passthrough to ALU in B for `fmul` if `fpu_mode = 1` | 32    |            |

### Instruction decoding

From `ir_out`, we decode the following signals

| Name            | Description                                  | Width | Expression                      |
| --------------- | -------------------------------------------- | ----- | ------------------------------- |
| `ir_opcode`     | Opcode                                       | 5     | `ir_opcode <- ir_out[31:27]`    |
| `ir_ra`         | `Ra` field                                   | 4     | `ir_ra <- ir_out[26:23]`        |
| `ir_rb_or_c2`   | `Rb` field for R/I-format, `C2` for B-format | 4     | `ir_rb_or_c2 <- ir_out[22:19]`  |
| `ir_rc`         | `Rc` field for R-format                      | 4     | `ir_rc <- ir_out[18:15]`        |
| `ir_constant_c` | `C` field for I/B-format                     | 19    | `ir_constant_c <- ir_out[18:0]` |
| `constant_c`    | Sign-extended constant `C`                   | 32    |                                 |

From these values, we derive assignments for the following bus interconnections and control wires (see code for details):

- `rf_z_addr`
- `rf_a_addr`
- `rf_b_addr`
- `branch_condition`

### Control Signals

The following control signals exist to dictate bus interconnections. Those noted with an asterisk (\*) beside the name are controlled externally, and double asterisk (\*\*) is an output of `cpu`.

| Name                   | Description                              | Width | Expression/Action                                                                        |
| ---------------------- | ---------------------------------------- | ----- | ---------------------------------------------------------------------------------------- |
| `rf_in_alu`\*          | Connect ALU out to RF in                 | 1     | `rf_in <- alu_z_out`                                                                     |
| `rf_in_hi`\*           | Connect HI out to RF in                  | 1     | `rf_in <- hi_out`                                                                        |
| `rf_in_lo`\*           | Connect LO out to RF in                  | 1     | `rf_in <- lo_out`                                                                        |
| `rf_in_memory`\*       | Connect Memory out to RF in              | 1     | `rf_in <- memory_out`                                                                    |
| `rf_in_fpu`\*          | Connect FPU out to RF in                 | 1     | `rf_in <- fpu_rz_out`                                                                    |
| `rf_in_input`\*        | Connect Input out to RF in               | 1     | `rf_en <- input_out`                                                                     |
| `rf_en`                | Enable write to RF                       | 1     | `rf_en <- rf_in_alu \| rf_in_hi \| rf_in_lo \| rf_in_memory \| rf_in_input \| rf_in_fpu` |
| `memory_en`\*          | Enable write to memory                   | 1     | `Memory[ma_out] <- rf_b_out`                                                             |
| `alu_select`\*         | One-hot ALU operation select             | 12    |                                                                                          |
| `alu_a_in_rf`\*        | Connect RF read data A to ALU input A    | 1     | `alu_a_in <- rf_a_out`                                                                   |
| `alu_a_in_pc`\*        | Connect PC to ALU input A                | 1     | `alu_a_in <- pc_out`                                                                     |
| `alu_b_in_rf`\*        | Connect RF read data B to ALU input B    | 1     | `alu_b_in <- rf_b_out`                                                                   |
| `alu_b_in_constant`\*  | Connect constant to ALU input B          | 1     | `alu_a_in <- constant_c`                                                                 |
| `pc_increment`\*       | Connect `PC + 1` to PC in                | 1     | `pc_in <- pc_plus_1`                                                                     |
| `pc_in_alu`\*          | Connect ALU out to PC in                 | 1     | `pc_in <- alu_z_out`                                                                     |
| `pc_in_rf_a`\*         | Connect RF read data A to PC in          | 1     | `pc_in <- rf_a_out`                                                                      |
| `pc_en`                | Enable write to PC                       | 1     | `pc_en <- pc_increment \| pc_in_alu \| pc_in_rf_a`                                       |
| `ir_en`\*              | Enable write to IR                       | 1     |                                                                                          |
| `ma_in_pc`\*           | Connect PC to MA in                      | 1     | `ma_in <- pc_out`                                                                        |
| `ma_in_alu`\*          | Connect ALU out to MA in                 | 1     | `ma_in <- alu_z_out`                                                                     |
| `ma_en`                | Enable write to MA                       | 1     | `ma_en <- ma_in_pc \| ma_in_alu`                                                         |
| `hi_en`\*              | Enable write to HI                       | 1     |                                                                                          |
| `lo_en`\*              | Enable write to LO                       | 1     |                                                                                          |
| `input_en`\*           | Enable write to Input port               | 1     |                                                                                          |
| `output_en`\*          | Enable write to Output port              | 1     |                                                                                          |
| `branch_condition`\*\* | Indicates whether branch should be taken | 1     | `branch_condition <- condition(rf_a_out)`                                                |
| `fpu_select`\*         | One-hot FPU operation select             | 10    |                                                                                          |
| `fpu_mode`\*           | Determines if ALU (0) or FPU (1) is used | 1     |                                                                                          |
