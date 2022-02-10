#include "fpu.h"

int main(void) {

    print_float(1.9395974f, '\n');
    print_float(1.436142f, '\n');
    print_float(1.0f, '\n');
    
    float pi = (float) acos(-1.0);
    print_float(pi, '\n');
    print_float(355, '\n');
    print_float(113, '\n');
    print_float(355 + pi, '\n');

    return 0;
}