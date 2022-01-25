# CPU Design Project

Lorem Ipsum.

#### Testing

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
# Test | shift1 | 25 << 3 = 200 |         25 <<  3 =        200
# Test | shift2 | 2374123 << 14 = 242925568 |    2374123 << 14 =  242925568
# Test | shift3 | 1 << 31 = 2147483648 |          1 << 31 = 2147483648
# Test | shift4 | 1 << 32 = 0 |          1 << 32 =          0
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