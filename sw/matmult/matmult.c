#include <stdint.h>
#include "crc32.h"

#define NROWS 4
#define NCOLS NROWS

int32_t a[NROWS * NCOLS];
int32_t b[NROWS * NCOLS];
int32_t c[NROWS * NCOLS];

uint8_t success = 0;

#define nDEBUG_PRINT
#define INFINITE_LOOP

#if defined(DEBUG_PRINT)

#include <stdio.h>

void print_matrix(int32_t m[NROWS * NCOLS])
{
    for (uint8_t i = 0; i < 100; i++)
    {
        printf("*");
    }
    printf("\n");
    
    for (uint32_t i = 0; i < NROWS; i++)
    {
        for (uint32_t j = 0; j < NCOLS; j++)
        {
            printf("%d ", m[NROWS *i + j]);
        }
        printf("\n");
    }
    
}

#endif // DEBUG_PRINT

void main()
{
    // Initalize the matrix A to the row index times the column index
    for (uint32_t i = 0; i < NROWS; i++)
        for (uint32_t j = 0; j < NCOLS; j++)
            a[NROWS * i + j] = i * j;

    #if defined(DEBUG_PRINT)
    print_matrix(a);
    #endif // DEBUG_PRINT
    
    // Initalize the matrix B to the row index times the column index
    for (uint32_t i = 0; i < NROWS; i++)
        for (uint32_t j = 0; j < NCOLS; j++)
            b[NROWS * i + j] = i * j;

    #if defined(DEBUG_PRINT)
    print_matrix(b);
    #endif // DEBUG_PRINT
    
    // Initalize the matrix C to all zeros in order to prepare for matrix multiplication
    for (uint32_t i = 0; i < NROWS; i++)
        for (uint32_t j = 0; j < NCOLS; j++)
            c[NROWS * i + j] = 0;

    #if defined(DEBUG_PRINT)
    print_matrix(c);
    #endif // DEBUG_PRINT

    for (uint32_t i = 0; i < NROWS; i++)
        for (uint32_t j = 0; j < NCOLS; j++)
            for (uint32_t k = 0; k < NCOLS; k++)
                c[NROWS * i + j] += a[NROWS * i + k] * b[NROWS * k + j];

    #if defined(DEBUG_PRINT)
    print_matrix(c);
    #endif // DEBUG_PRINT

    uint32_t crc_accum=0;
    uint8_t * ptr;

    gen_crc_table();

    ptr = (uint8_t *) a;
    crc_accum = update_crc(crc_accum, ptr, NROWS * NCOLS * 4);
    ptr = (uint8_t *) b;
    crc_accum = update_crc(crc_accum, ptr, NROWS * NCOLS * 4);
    ptr = (uint8_t *) c;
    crc_accum = update_crc(crc_accum, ptr, NROWS * NCOLS * 4);

    if (crc_accum = 0xb555a39c)
        success = 1;

    #if defined(DEBUG_PRINT)
    printf("Expected: b555a39c; Actual: %x\n", crc_accum);
    #endif

    #if defined(INFINITE_LOOP)
    while (1);
    #endif // INFINITE LOOP

    return;
}