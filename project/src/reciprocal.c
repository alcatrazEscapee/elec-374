#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "fpu.h"

#define random(x) ((float)rand()/(float)(RAND_MAX)) * (x)

#define accuracy(x, y) (float) (mantissa(x) - mantissa(y))
#define mantissa(x) (INT(x) & 0b11111111111111111111111)

float reciprocal_2_f(float);
float reciprocal_rtn(float);

int main(void) {

    srand((unsigned int) time(NULL));

    float delta_2f = 0;
    float delta_rtn = 0;

    for (int i = 0; i < 100000; i++) {
        float val = random(1000000000);
        float rec = 1.0f / val;

        float val_2f = reciprocal_2_f(val);
        float val_rtn = reciprocal_rtn(val);
        
        delta_2f += accuracy(rec, val_2f);
        delta_rtn += accuracy(rec, val_rtn);
    }

    delta_2f /= 1000.0f;
    delta_rtn /= 1000.0f;

    printf("Error 2f  : %f\nError RTN : %f\n", delta_2f, delta_rtn);

    return 0;
}

float reciprocal_2_f(float x) {
    int i = *(int*)&x;
    i = 0x7eb53567 - i;
    float y = *(float*)&i;
    y = 1.9395974f * y * fmaf(-x, y, 1.436142f);
    float r = fmaf(y, -x, 1.0f);
    y = fmaf(y, r, y);
    return y;
}

/**
 * 0 | X  <= IN; Y <- 0x7eb53567 - IN;
 * 1 | T1 <= -X * Y
 * 2 | T0 <= 1.9395974f * Y; T1 <- T1 + 1.436142f
 * 3 | Y  <= T0 * T1
 * 4 | T1 <= -X * Y
 * 5 | R  <= T1 + 1.0f
 * 6 | T0 <= Y * R
 * 7 | Y  <= T0 + Y
 */
float reciprocal_rtn(float in) {
    int i;
    float x, y, r, t0, t1;
    
    i = 0x7eb53567 - INT(in);
    x = in;
    y = FLOAT(i);
    
    t1 = -x * y;

    t0 = 1.9395974f * y;
    t1 = t1 + 1.436142f;

    y = t0 * t1;

    t1 = -x * y;

    r = t1 + 1.0f;

    t0 = y * r;

    y = t0 + y;

    return y;
}