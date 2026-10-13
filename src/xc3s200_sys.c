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

volatile unsigned int* const pLED_R0R31 = (unsigned int*)0x120000; // LEDs, R0R31 set select

typedef void VOID_FUNC();
char* const pSysString = "System soft core xc3c200 started...\r";

#define BTN0_MASK     0x10
#define BTN1_MASK     0x20
#define BTN2_MASK     0x40
#define BTN_THRESHOLD 10
#define R0R31_MASK    0xF00

int btn0;
int btn1;
int btn2;

int getBtnR0R31sel() {
    int btn = *pLED_R0R31;

    if ( btn & BTN0_MASK ) {
        if ( btn0 < BTN_THRESHOLD ) {
            btn0++;
        } else return BTN0_MASK;
    } else if ( btn0 > 0 ) {
        btn0--;
    }

    if ( btn & BTN1_MASK ) {
        if ( btn1 < BTN_THRESHOLD ) {
            btn1++;
        } else return BTN1_MASK;
    } else if ( btn1 > 0 ) {
        btn1--;
    }

    if ( btn & BTN2_MASK ) {
        if ( btn2 < BTN_THRESHOLD ) {
            btn2++;
        } else return BTN2_MASK;
    } else if ( btn2 > 0 ) {
        btn2--;
    }

    return ( btn & ~( BTN0_MASK | BTN1_MASK | BTN2_MASK )); // BTN0-2 excluded!
}

char* const pAterisk = "*";
char* const pBTN = "BTN";
char* const p0 = "0\r";
char* const p1 = "1\r";
char* const p2 = "2\r";

void printBtn0() {
    putChar( pBTN );
    putChar( p0 );
}

void printBtn1() {
    putChar( pBTN );
    putChar( p1 );
}

void printBtn2() {
    putChar( pBTN );
    putChar( p2 );
}

void run() {
    int r0r31sel = (( getBtnR0R31sel() & R0R31_MASK ) >> 8 );
    // Sets stack top for every R0R31 set!
    if ( 1 == r0r31sel ) asm volatile( "la sp,_stack_top-100" );
    if ( 2 == r0r31sel ) asm volatile( "la sp,_stack_top-200" );
    if ( 3 == r0r31sel ) asm volatile( "la sp,_stack_top-300" );

    if ( 0 == r0r31sel ) {
        putChar( pSysString );
        // Initialize global variables! Could be located in XMODEM end-of-file section.
        btn0 = 0;
        btn1 = 0;
        btn2 = 0;
    } else { // R0R31 set > 0!
        putChar( pAterisk );

        if ( 1 == r0r31sel ) printBtn0();
        if ( 2 == r0r31sel ) printBtn1();
        if ( 3 == r0r31sel ) printBtn2();

        *pLED_R0R31 = 0; // Return to while loop
    }

    while ( 1 ) {
        int btn = getBtnR0R31sel();

        if ( btn & BTN0_MASK ) {
            btn0 = 0;
            *pLED_R0R31 = 1 << 8; // Set R0R31 (0-15) select
        }

        if ( btn & BTN1_MASK ) {
            btn1 = 0;
            *pLED_R0R31 = 2 << 8; // Set R0R31 (0-15) select
        }

        if ( btn & BTN2_MASK ) {
            btn2 = 0;
            *pLED_R0R31 = 3 << 8; // Set R0R31 (0-15) select
        }
    }
}
