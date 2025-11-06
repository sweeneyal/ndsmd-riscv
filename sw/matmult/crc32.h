#include <stdint.h>

//----- Defines ---------------------------------------------------------------
#define POLYNOMIAL 0x04c11db7L      // Standard CRC-32 ppolynomial

//----- Global variables ------------------------------------------------------
static uint32_t crc_table[256];       // Table of 8-bit remainders

//----- Prototypes ------------------------------------------------------------
void gen_crc_table(void);
uint32_t update_crc(uint32_t crc_accum, uint8_t *data_blk_ptr, uint32_t data_blk_size);