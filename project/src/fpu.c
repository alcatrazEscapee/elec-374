#include "fpu.h"


int main(int argc, char ** argv) {
    fesetround(FE_TONEAREST);

	if (argc != 2) {
        printf("Usage: fpu [fgij+-]\n");
        return 1;
    }
	switch (argv[1][0]) {
        case 'f': cast_int_to_float(SIGNED); break;
        case 'g': cast_int_to_float(UNSIGNED); break;
        case 'i': cast_float_to_int(); break;
        case 'j': cast_float_to_unsigned_int(); break;
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

void print_int(int32_t value, char u, char end) {
    printf("%08x = ", value);
    if (u == SIGNED) printf("%d", value);
    else printf("%u", UINT(value));
    printf("%c", end);
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

void cast_float_to_int() {
    int32_t i, j, k, cast;
    while (scanf("%x", &i) != -1 && scanf("%x", &j) != -1 && scanf("%d", &k) != -1) {
        if (convert_float_to_int(&cast, FLOAT(i))) {
            print_float(FLOAT(i), '|');
            print_int(cast, SIGNED, ' ');
            printf(" (legal)|");
            print_int(j, SIGNED, ' ');
            printf(" (%s)\n", k ? "illegal" : "legal");
        } else {
            print_float(FLOAT(i), ' ');
            printf("(undefined behavior)|illegal|%s", k ? "illegal\n" : "legal ");
            if (!k) {
                print_int(cast, SIGNED, '\n');
            }
        }
    }
}

void cast_float_to_unsigned_int() {
    int32_t i, j, k;
    uint32_t cast;
    while (scanf("%x", &i) != -1 && scanf("%x", &j) != -1 && scanf("%d", &k) != -1) {
        if (convert_float_to_unsigned(&cast, FLOAT(i))) {
            print_float(FLOAT(i), '|');
            print_int(cast, UNSIGNED, ' ');
            printf(" (legal)|");
            print_int(j, UNSIGNED, ' ');
            printf(" (%s)\n", k ? "illegal" : "legal");
        } else {
            print_float(FLOAT(i), ' ');
            printf("(undefined behavior)|illegal|%s", k ? "illegal\n" : "legal ");
            if (!k) {
                print_int(cast, SIGNED, '\n');
            }
        }
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


#define FLT_UINT_MAX_P1 ((UINT_MAX/2 + 1)*2.0f)
#define FLT_INT_MAX_P1 ((INT_MAX/2 + 1)*2.0f)

bool convert_float_to_int(int32_t *i, float f) {
    #if INT_MIN == -INT_MAX
    // Rare non 2's complement integer
    if (fabsf(f) < FLT_INT_MAX_P1) {
        *i = (int32_t) f;
        return true;
    }
    #else
    // Do not use f + 1 > INT_MIN as it may incur rounding
    // Do not use f > INT_MIN - 1.0f as it may incur rounding
    // f - INT_MIN is expected to be exact for values near the limit
    if (f - INT_MIN > -1 && f < FLT_INT_MAX_P1) {
        *i = (int32_t) f;
        return true;
    }
    #endif
    return false;  // out of range
}

bool convert_float_to_unsigned(uint32_t *u, float f) {
    if (f > -1.0f && f < FLT_UINT_MAX_P1) {
        *u = (uint32_t) f;
        return true;
    }
    return false;  // out of range
}
