// Initialize some constants
addi r1 r0 355
addi r2 r0 113

// Initialize a floating point literal (pi = 40490fdb : 0 10000000 10010010000111111011011 = 3.14159)
ori r3 r0 0x4049
addi r4 r0 16
shl r3 r3 r4
ori r3 r3 0x0fdb

// Cast to floats
crf f1 r1
curf f2 r2

// Arithmetic
fadd f4 f1 f3 // 355 + pi
frc f5 f2 // f5 = 1.0 / 113
fmul f5 f5 f1 // f5 = 355 / 113 (a decent pi approximation)
fsub f6 f3 f5 // f6 = approximation delta

// Compare
feq r1 f3 f5 // pi == approximation ?
fgt r2 f6 f0 // delta > 0 ?

// Cast to ints
cfr r1 f6
cufr r1 f6
