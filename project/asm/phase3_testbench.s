// Phase 3 Example Program
.org 0
    ldi r3, 0x87        // r3 = 0x87
    ldi r3, 1(r3)       // r3 = 0x88
    ld r2, 0x75         // r2 = Memory[0x75] = 0x56
    ldi r2, -2(r2)      // r2 = 0x54
    ld r1, 4(r2)        // r1 = Memory[0x58] = 0x34
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
    // Phase 3 Spec suggests this should be Memory[0x75], this is an error
    // It does decimal addition rather than treating these as hex
    // The actual memory value that is written to is Memory[0x6F]
    st 0x67(r1), r2     // Memory[0x6F] = 0xCD
    sub r3, r2, r3      // r3 = 1
    shl r1, r2, r0      // r1 = 0x19A
    ldi r4, 5           // r4 = 5
    ldi r5, 0x1D        // r5 = 0x1D
    mul r5, r4          // {HI, LO} = 0, 0x91
    mfhi r7             // r7 = 0
    mflo r6             // r6 = 0x91
    div r5, r4          // {HI, LO} = 4, 5
    
    // Subroutine call: r8, r9 = return values, r10, r11 = parameters, r12 = address, r13 = zero
    ldi r10, 0(r4)      // r10 = 5
    ldi r11, 2(r5)      // r11 = 0x1F
    ldi r12, 0(r6)      // r12 = 0x91
    ldi r13, 0(r7)      // r13 = 0
    jal r12             // address of subroutine subA in r12 - return address in r15
    halt                // upon return, the program halts

.org 0x91               // procedure subA
subA:
    add r9, r10, r12    // r9 = 0x96
    sub r8, r11, r13    // r8 = 0x1F
    sub r9, r9, r8      // r9 = 0x77
    // The spec used r14 as the return address - this is incorrect
    // The return address register was changed to r15 here.
    jr r15              // return

.org 0x58
    .mem 0x34

.org 0x75
    .mem 0x56