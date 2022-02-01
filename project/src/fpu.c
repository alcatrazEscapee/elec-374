#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include <fenv.h>

#pragma STDC FENV_ACCESS ON

#define SIGNED '-'
#define UNSIGNED '+'

#define ADD '+'
#define SUB '-'

#define FLOAT(x) (* (float*) &(x))
#define INT(x) (* (int32_t*) &(x))
#define UINT(x) (* (uint32_t*) &(x))

void print_float(float, char);
void print_bits(int32_t*, uint32_t);

void cast_int_to_float(char);
void binary_op_floats(char);

int main(int argc, char ** argv) {
    fesetround(FE_TONEAREST);

	if (argc != 2) {
        printf("Usage: fpu [fg+-]\n");
        return 1;
    }
	switch (argv[1][0]) {
        case 'f': cast_int_to_float(SIGNED); break;
        case 'g': cast_int_to_float(UNSIGNED); break;
        case '+': binary_op_floats(ADD); break;
        case '-': binary_op_floats(SUB); break;
        default : printf("Unknown: %c\n", argv[1][0]);
    }
    return 0;
}

void print_float(float value, char end) {
    int32_t raw = INT(value);
    printf("%08x : ", raw);
    print_bits(&raw, 1);
    printf(" ");
    print_bits(&raw, 8);
    printf(" ");
    print_bits(&raw, 23);
    printf(" = %g%c", value, end);
}

void print_bits(int32_t* value, uint32_t count) {
    for (uint32_t i = 0; i < count; i++) {
        putchar((*value & 0x80000000) ? '1' : '0');
        *value <<= 1;
    }
}

void cast_int_to_float(char u) {
    int32_t i, j;
    while (scanf("%x", &i) != -1 && scanf("%x", &j) != -1) {
        print_float(u == SIGNED ? (float) i : (float) UINT(i), '|');
        print_float(FLOAT(j), '\n');
    }
}

void cast_int_to_float_unsigned() {
    int32_t i, j;
    while (scanf("%x", &i) != -1 && scanf("%x", &j) != -1) {
        print_float((float) UINT(i), '|');
        print_float(FLOAT(j), '\n');
    }
}

void binary_op_floats(char op) {
    int32_t i, j, k;
    while (scanf("%x", &i) != -1 && scanf("%x", &j) != -1 && scanf("%x", &k) != -1) {
        float f = 
            op == ADD ? FLOAT(i) + FLOAT(j) :
            op == SUB ? FLOAT(i) - FLOAT(j) :
            0;
        print_float(FLOAT(i), '|');
        print_float(FLOAT(j), '|');
        print_float(f, '|');
        print_float(FLOAT(k), '\n');
    }
}
