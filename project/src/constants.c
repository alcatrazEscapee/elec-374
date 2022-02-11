#include "fpu.h"

int main(void) {

    print_float(1.9395974f, '\n');
    print_float(1.436142f, '\n');
    print_float(1.0f, '\n');
    
    float pi = (float) acos(-1.0);
    int i = 0x3c10fa16;

    print_float(pi, '\n');
    print_float(355, '\n');
    print_float(113, '\n');
    print_float((float) 355 / (float) 113, '\n');
    print_float(355 + pi, '\n');
    print_float(1.0f / 113, '\n');
    print_float(FLOAT(i), '\n');

    float pi_approx = FLOAT(i) * (float) 355;

    print_float(pi_approx, '\n');
    print_float(pi - pi_approx, '\n');

    return 0;
}