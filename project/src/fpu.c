#include "fpu.h"

void cast_int_to_float(char);
void cast_float_to_int();
void cast_float_to_unsigned_int();
void binary_op_floats(char);
void reciprocal_float();
void compare_floats(char);


int main(int argc, char ** argv) {

    fesetround(FE_TONEAREST);

    if (argc != 2) {
        printf("Usage: fpu [fgijasxdGEL]\n");
        return 1;
    }
    switch (argv[1][0]) {
        case 'f': cast_int_to_float(SIGNED); break;
        case 'g': cast_int_to_float(UNSIGNED); break;
        case 'i': cast_float_to_int(); break;
        case 'j': cast_float_to_unsigned_int(); break;
        case 'a': binary_op_floats(ADD); break;
        case 's': binary_op_floats(SUB); break;
        case 'x': binary_op_floats(MUL); break;
        case 'd': binary_op_floats(DIV); break;
        case 'r': reciprocal_float(); break;
        case 'G': compare_floats(GREATER_THAN); break;
        case 'E': compare_floats(EQUALS); break;
        case 'L': compare_floats(LESS_THAN); break;
        default : printf("Unknown: %c\n", argv[1][0]);
    }
    return 0;
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
            op == MUL ? FLOAT(i) * FLOAT(j) :
            op == DIV ? FLOAT(i) / FLOAT(j) :
            0;
        print_float(FLOAT(i), '|');
        print_float(FLOAT(j), '|');
        print_float(f, '|');
        print_float(FLOAT(k), '\n');
    }
}

void reciprocal_float() {
    int32_t i, j;
    while (scanf("%x", &i) != -1 && scanf("%x", &j) != -1) {
        float f = 1.0f / FLOAT(i), g = FLOAT(j);
        print_float(FLOAT(i), '|');
        print_float(f, '|');
        print_float(g, '|');

        float realitive_error = fabsf(f - g) / fmaxf(fabsf(f), fabsf(g));
        float binary_error = (float) abs(MANTISSA(f) - MANTISSA(g)) / (1 << 23);
        bool close_enough = 
               realitive_error <= 2e-4 // Realitive Error below threshold
            && SIGN(f) == SIGN(g) // Equal sign
            && EXPONENT(f) == EXPONENT(g) // Equal exponent
            && binary_error <= (1.0f / (1 << 12)); // Correct to 12 binary decimal places

        printf("(Realitive) %e (Binary) %e|%s\n", realitive_error, binary_error, close_enough ? "true" : "false");
    }
}

void compare_floats(char op) {
    int32_t i, j, actual;
    while (scanf("%x", &i) != -1 && scanf("%x", &j) != -1 && scanf("%d", &actual) != -1) {
        bool expected = 
            op == GREATER_THAN ? FLOAT(i) > FLOAT(j) :
            op == LESS_THAN ? FLOAT(i) < FLOAT(j) :
            op == EQUALS ? FLOAT(i) == FLOAT(j) :
            0;
        print_float(FLOAT(i), ' ');
        printf("%s ", 
            op == GREATER_THAN ? ">" :
            op == LESS_THAN ? "<" :
            op == EQUALS ? "==" :
            "??");
        print_float(FLOAT(j), '|');
        printf("%s|%s\n", expected ? "true" : "false", actual ? "true" : "false");
    }
}
