#ifndef FPU_H
#define FPU_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include <fenv.h>
#include <stdbool.h>
#include <limits.h>

#pragma STDC FENV_ACCESS ON

_Static_assert(sizeof(int32_t) == 4, "sizeof(int32_t) == 4");
_Static_assert(sizeof(uint32_t) == 4, "sizeof(uint32_t) == 4");
_Static_assert(sizeof(float) == 4, "sizeof(float) == 4");

#define SIGNED '-'
#define UNSIGNED '+'

#define ADD 'a'
#define SUB 's'
#define MUL 'x'
#define DIV 'd'

#define GREATER_THAN 'G'
#define LESS_THAN 'L'
#define EQUALS 'E'

#define FLOAT(x) (* (float*) &(x))
#define INT(x) (* (int32_t*) &(x))
#define UINT(x) (* (uint32_t*) &(x))

#define SIGN(x) ((INT(x) >> 31) & 0b1)
#define EXPONENT(x) ((INT(x) >> 23) & 0b11111111)
#define MANTISSA(x) (INT(x) & 0b11111111111111111111111)

void print_float(float, char);
void print_int(int32_t, char, char);
void print_bits(int32_t*, uint32_t);


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

// Limits for float -> int32_t and uint32_t casts
// https://stackoverflow.com/questions/46928840/what-happens-when-casting-floating-point-types-to-unsigned-integer-types-when-th

#define FLT_UINT_MAX_P1 ((UINT_MAX/2 + 1)*2.0f)
#define FLT_INT_MAX_P1 ((INT_MAX/2 + 1)*2.0f)

bool convert_float_to_int(int32_t *i, float f) {
    // Do not use f + 1 > INT_MIN as it may incur rounding
    // Do not use f > INT_MIN - 1.0f as it may incur rounding
    // f - INT_MIN is expected to be exact for values near the limit
    if (f - INT_MIN > -1 && f < FLT_INT_MAX_P1) {
        *i = (int32_t) f;
        return true;
    }
    return false;  // out of range
}

bool convert_float_to_unsigned(uint32_t *u, float f) {
    if (f > -1.0f && f < FLT_UINT_MAX_P1) {
        *u = (uint32_t) f;
        return true;
    }
    return false;  // out of range
}

#endif