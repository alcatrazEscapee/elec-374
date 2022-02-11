// Initialize RF : r2 = 53, r4 = 28
addi r2, r0, 53
addi r4, r0, 28

// Test Instructions
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
ld r0, 35(r1)
ldi r1, 85
ldi r0, 35(r1)
st 90, r1
st 90(r1), r1
addi r2, r1, -5
andi r2, r1, 26
ori r2, r1, 26
// brzr r2, 35
// brnx r2, 35
// brpl r2, 35
// brmi r2, 35
// jr r1
// jal r1
// mfhi r2
// mflo r2
// out r1
// in r1
