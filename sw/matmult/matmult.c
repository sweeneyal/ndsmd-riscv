#include <stdint.h>
#include <stdio.h>

#define NROWS 4
#define NCOLS NROWS

int32_t a[NROWS][NCOLS];
int32_t b[NROWS][NCOLS];
int32_t c[NROWS][NCOLS];

#define _DEBUG_PRINT
#define INFINITE_LOOP

#if defined(DEBUG_PRINT)

void print_matrix(int32_t m[NROWS][NCOLS])
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
            printf("%d ", m[i][j]);
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
            a[i][j] = i * j;

    #if defined(DEBUG_PRINT)
    print_matrix(a);
    #endif // DEBUG_PRINT
    
    // Initalize the matrix B to the row index times the column index
    for (uint32_t i = 0; i < NROWS; i++)
        for (uint32_t j = 0; j < NCOLS; j++)
            b[i][j] = i * j;

    #if defined(DEBUG_PRINT)
    print_matrix(b);
    #endif // DEBUG_PRINT
    
    // Initalize the matrix C to all zeros in order to prepare for matrix multiplication
    for (uint32_t i = 0; i < NROWS; i++)
        for (uint32_t j = 0; j < NCOLS; j++)
            c[i][j] = 0;

    #if defined(DEBUG_PRINT)
    print_matrix(c);
    #endif // DEBUG_PRINT

    for (uint32_t i = 0; i < NROWS; i++)
        for (uint32_t j = 0; j < NCOLS; j++)
            for (uint32_t k = 0; k < NCOLS; k++)
                c[i][j] += a[i][k] * b[k][j];

    #if defined(DEBUG_PRINT)
    print_matrix(c);
    #endif // DEBUG_PRINT

    #if defined(INFINITE_LOOP)
    while (1);
    #endif // INFINITE LOOP

    return;
}