#include <stdio.h>

void print_float(float);
void print_bits(int*, int);

float castf(int i);

void cast_int_to_float();
void cast_float_to_int();

int main(int argc, char ** argv) {
	if (argc != 2) {
        printf("Usage: fpu [f]\n");
        return 1;
    }
	switch (argv[1][0]) {
        case 'f': cast_int_to_float(); break;
        default : printf("Unknown: %c\n", argv[1][0]);
    }
    return 0;
}

void print_float(float value) {
    int raw = *(int*) &value;
    printf("%08x : ", raw);
    print_bits(&raw, 1);
    printf(" ");
    print_bits(&raw, 8);
    printf(" ");
    print_bits(&raw, 23);
    printf(" = %g\n", value);
}

void print_bits(int* value, int count) {
    for (int i = 0; i < count; i++) {
        putchar((*value & 0x80000000) ? '1' : '0');
        *value <<= 1;
    }
}

float castf(int i) {
    return * (float*) &i;
}

void cast_int_to_float() {
    int i, b;
    while (scanf("%x", &i) != -1) {
        print_float(b ? (float) i : castf(i));
        b = !b;
    }
}
