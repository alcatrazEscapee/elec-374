// Initialize some constants
addi r1 r0 355
addi r2 r0 113

// Initialize a floating point literal (pi = 40490fdb : 0 10000000 10010010000111111011011 = 3.14159)
ori r3 r0 0x4049
addi r4 r0 16
shl r3 r3 r4
ori r3 r3 0x0fdb

// Move and Cast
crf f1 r1
curf f2 r2
mvrf f3 r3

// Arithmetic
fadd f4 f1 f3 // 355 + pi