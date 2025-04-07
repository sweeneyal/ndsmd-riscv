OUTPUT_FORMAT("elf32-littleriscv")

ENTRY(main)

SECTIONS
{
    .text : { *(.text) }
    
    . = 0x00005000;
    .data : { *(.data) }
    
    .bss : { *(.bss) }
    
    .stack : {
        . = ALIGN(8);
        __stack_size = 4k;
        __stack_end = .;
        . = . + __stack_size;
        PROVIDE(__stack_start = .);
    }
}