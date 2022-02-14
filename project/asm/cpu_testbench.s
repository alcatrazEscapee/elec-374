// Phase 1 Setup : r2 = 53, r4 = 28
    addi r2, r0, 53
    addi r4, r0, 28

// Phase 1
    and r5, r2, r4
    or r5, r2, r4
    add r5, r2, r4
    sub r5, r2, r4
    shr r5, r2, r4
    shl r5, r2, r4
    ror r5, r2, r4
    rol r5, r2, r4
    mul r2, r4
    div r2, r4
    neg r5, r2
    not r5, r2

// Phase 2
    ld r1, 85
    ld r0, 35(r1) // Loads from 35 + 10
    ldi r1, 85
    ldi r0, 35(r1)
    st 90, r1
    st 90(r1), r1
    addi r2, r1, -5
    andi r2, r1, 26
    ori r2, r1, 26
    brzr r2, 35
    brnz r2, 35 // Will branch to 60
jump_back_1:
    brpl r2, 35 // Will branch to 61
jump_back_2:
    brmi r2, 35
    ldi r1, 62 // Non-test instruction, just to set r1 to 62 before jr
    jal r1 // Will jump to 62
    mfhi r2
    mflo r2
    out r1
    in r1

.org 60
    brnz r2, jump_back_1
    brpl r2, jump_back_2
    jr r15 // Jump return

.org 45
    .mem 0xdeadbeef
.org 85
    .mem 10
