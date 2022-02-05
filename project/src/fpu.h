#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include <fenv.h>
#include <stdbool.h>
#include <limits.h>

#pragma STDC FENV_ACCESS ON


#define SIGNED '-'
#define UNSIGNED '+'

#define ADD '+'
#define SUB '-'

#define GREATER_THAN 'G'
#define LESS_THAN 'L'
#define EQUALS 'E'

#define FLOAT(x) (* (float*) &(x))
#define INT(x) (* (int32_t*) &(x))
#define UINT(x) (* (uint32_t*) &(x))

void print_float(float, char);
void print_int(int32_t, char, char);
void print_bits(int32_t*, uint32_t);

void cast_int_to_float(char);
void cast_float_to_int();
void cast_float_to_unsigned_int();
void binary_op_floats(char);
void compare_floats(char);

// Limits for float -> int32_t and uint32_t casts
// https://stackoverflow.com/questions/46928840/what-happens-when-casting-floating-point-types-to-unsigned-integer-types-when-th

bool convert_float_to_int(int32_t *i, float f);
bool convert_float_to_unsigned(uint32_t *u, float f);