ENTRY(_start)

MEMORY {
    SRAM(rwx) : ORIGIN = 0x0, LENGTH = 1M
    BRAM(rwx) : ORIGIN = 0x100000, LENGTH = 2k
    IO(rwx)   : ORIGIN = 0x100800, LENGTH = (1M - 2k)
/*
    The RISC-V GCC toolchain does not initialize the stack pointer (R2-SP-X2).
    The stack pointer is default zero, when not defined the register R2 could
    be initialized by programming, otherwise the stack top is located at the
    end of the RISC-V processor address space.
*/
}

SECTIONS {
    _stack_top = ORIGIN(SRAM) + LENGTH(SRAM);

    .text   : {KEEP(*(.text.boot))
               KEEP(*(.stack)) /* Start of stack address space */
               *(.text*)}   > SRAM
    .rodata : {*(.rodata*)} > SRAM
    .data   : {*(.data*)}   > SRAM
    .bss    : {*(.bss*)}    > SRAM
}
