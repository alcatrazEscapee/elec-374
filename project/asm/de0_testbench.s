.org 0x0
    andi r0 r0 0    // Set r0 = 0

loop:
    in r1           // Read Input
    brzr r1 end     // If input is zero, exit
    out r1          // And output it
    brzr r0, loop   // And loop
end:
    halt