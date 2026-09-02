/*
 *  System soft core Digilent Xilinx Spartan-3 Starter Kit (XC3S200-4FT256).
 *  Boots from SRAM.
 *
 *      MEMORY {
 *          SRAM(rwx) : ORIGIN = 0x000000, LENGTH = 1M
 *          BRAM(rwx) : ORIGIN = 0x100000, LENGTH = 2k
 *          IO(rwx)   : ORIGIN = 0x100800, LENGTH = (1M - 2k)
 *      }
 */

// Top of stack
extern unsigned _stack_top;

void __attribute__((section (".text.boot"))) _start() {
/*
    The RISC-V GCC toolchain does not initialize the stack pointer (R2-SP-X2).
    The stack pointer is default zero, when not defined the register R2 could
    be initialized by programming, otherwise the stack top is located at the
    end of the RISC-V processor address space.

    If the xc3s200 systhesis sets the stack pointer register to _stack_top, the
    "asm volatile( "la sp,_stack_top" );" or equivalent inline assembly could be
    omitted!
*/
    asm volatile( "la sp,_stack_top" );
    asm volatile( "j run" );
}

volatile unsigned int* const pUart = (unsigned int*)0x180000; // Read = uart data/status

void putChar( char* pString ) {
    while ( *pString ) {
        while ( !( *pUart & 0x400 )) {} // Uart TX not ready, wait...

        *pUart = *pString;
        pString++;
    }
}

typedef void VOID_FUNC();
char* const pSysString = "System soft core xc3c200 started...\r";

void run() {
    putChar( pSysString );

    while ( 1 ); // Wait...
}
