// Phase 4 Example Program
// All '$X' constants are interpreted as hex
// The return address register was changed from r14 to r15, in compliance with the spec.

.org 0
    ldi r3, 0x87        // r3 = 0x87
    ldi r3, 1(r3)       // r3 = 0x88
    ld r2, 0x75         // r2 = (0x75) = 0x56
    ldi r2, -2(r2)      // r2 = 0x54
    ld r1, 4(r2)        // r1 = (0x58) = 0x34
    ldi r0, 1           // r0 = 1
    ldi r3, 0x73        // r3 = 0x73
    brmi r3, 3          // branch not taken
    ldi r3, 5(r3)       // r3 = 0x78
    ld r7, -3(r3)       // r7 = (0x78 - 3) = 0x56
    nop
    brpl r7, 2          // branch to target
    ldi r4, 6(r1)       // skipped
    ldi r3, 2(r4)       // skipped
target:
    add r3, r2, r3      // r3 = 0xCC
    addi r7, r7, 3      // r7 = 0x59
    neg r7, r7          // r7 = 0xFFFFFFA7
    not r7, r7          // r7 = 0x58
    andi r7, r7, 0x0F   // r7 = 8
    ori r7, r1, 3       // r7 = 0x37
    shr r2, r3, r0      // r2 = 0x66
    st 0x58, r2         // Memory[0x58] = 0x66
    ror r1, r1, r0      // r1 = 0x1A
    rol r2, r2, r0      // r2 = 0xCC
    or r2, r3, r0       // r2 = 0xCD
    and r1, r2, r1      // r1 = 0x8
    st 0x67(r1), r2     // Memory[0x75] = 0xCD
    sub r3, r2, r3      // r3 = 1
    shl r1, r2, r0      // r1 = 0x19A
    ldi r4, 5           // r4 = 5
    ldi r5, 0x1D        // r5 = 0x1D
    mul r5, r4          // {HI, LO} = 0, 0x91
    mfhi r7             // r7 = 0
    mflo r6             // r6 = 0x91
    div r5, r4          // {HI, LO} = 4, 5
    ldi r10, 0(r4)      // r10 = 5 setting up argument registers
    ldi r11, 2(r5)      // r11 = 0x1F r8, r9, r10, and r11
    ldi r12, 0(r6)      // r12 = 0x91
    ldi r13, 0(r7)      // r13 = 0
    jal r12             // address of subroutine subA in r12 - return address in r15
    
    // New in Phase 4

    in r4               // set 8 switches (SW[0] to SW[7]) to 0x88 = read it into the lower 8 bits 
    st 0x95, r4         // of r4 (set other input bits to 0), and save it for the next time around 
    ldi r1, 0x2D        // address of loop in r1 
    ldi r7, 1           // r7 = 1 
    ldi r5, 40          // r5 = 40, loop counter (5 times) 
.org 0x2D
loop:
    out r4              // display the lower 8 bits of r4 on the two 7-segment displays 
    ldi r5, -1(r5)      // is the loop done? 
    brzr r5, 8          // yes = branch to done 
    ld r6, 0xF0         // no = set r6 = 0xFFFF
loop2:
    ldi r6, -1(r6)      // delay, so you can see the numbers on the two 7-segment displays 
    nop 
    brnz r6, -3         // branch to loop2 if r6 != 0 = delay is not done yet 
    shr r4, r4, r7      // delay is done - shift the number in r4 right once 
    brnz r4, -9         // back to loop and display the shifted number if it is not zero 
    ld r4, 0x95         // if it is zero, start over with the number 0x88 
    jr r1               // branch to loop using address in r1 
done:
    ldi r4, 0x5A        // final display value 0x5A 
    out r4              // display the final display value 0x5A on the two 7-segment displays
    
    halt                // upon return, the program halts

.org 0x91               // procedure subA
subA:
    add r9, r10, r12    // r8 and r9 are return value registers
    sub r8, r11, r13    // r9 = 0x96, r8 = 0x1F
    sub r9, r9, r8      // r13 = 0x77
    jr r15              // return

.org 0x75
    .mem 0x56
.org 0x58
    .mem 0x34
.org 0xF0
    .mem 0xFFFF