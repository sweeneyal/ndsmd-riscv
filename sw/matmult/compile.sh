
# Compiles matmult.c
riscv32-unknown-elf-gcc matmult.c crc32.h crc32.c -nostdlib -march=rv32imafd  -T ../sim/sim.ld -o matmult.elf

# Dumps the disassembly of the elf file
riscv32-unknown-elf-objdump -d matmult.elf > matmult.asm

# Dumps the binary of the elf file for use on hardware or in simulation
riscv32-unknown-elf-objcopy -O binary -j .text matmult.elf matmult.bin