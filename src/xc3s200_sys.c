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

// Defines
#define BTN0_MASK     0x10
#define BTN1_MASK     0x20
#define BTN2_MASK     0x40
#define BTN_THRESHOLD 10

#define R0R31SET1_MASK 0x100
#define R0R31SET2_MASK 0x200
#define R0R31SET3_MASK 0x300
#define R0R31SET_MASK  ( R0R31SET1_MASK | R0R31SET2_MASK | R0R31SET2_MASK )

// Global variables
int btn_r0r31;
int btn0;
int btn1;
int btn2;

int getBtn() {
    btn_r0r31 = *pLED_R0R31;

    if ( btn_r0r31 & BTN0_MASK ) {
        if ( btn0 < BTN_THRESHOLD ) {
            btn0++;
        } else return BTN0_MASK;
    } else if ( btn0 > 0 ) {
        btn0--;
    }

    if ( btn_r0r31 & BTN1_MASK ) {
        if ( btn1 < BTN_THRESHOLD ) {
            btn1++;
        } else return BTN1_MASK;
    } else if ( btn1 > 0 ) {
        btn1--;
    }

    if ( btn_r0r31 & BTN2_MASK ) {
        if ( btn2 < BTN_THRESHOLD ) {
            btn2++;
        } else return BTN2_MASK;
    } else if ( btn2 > 0 ) {
        btn2--;
    }

    return 0;
}

char* const pAterisk = "*";
char* const pBTN = "BTN";
char* const p0 = "0\r";
char* const p1 = "1\r";
char* const p2 = "2\r";

void printBtn0() {
    while ( 1 ) { // Thread printBtn0
        if ( *pLED_R0R31 & R0R31SET1_MASK ) {
            putChar( pBTN );
            putChar( p0 );
            *pLED_R0R31 = 0; // Context switch to run()
        }
    }
}

void printBtn1() {
    while ( 1 ) { // Thread printBtn1
        if ( *pLED_R0R31 & R0R31SET2_MASK ) {
            putChar( pBTN );
            putChar( p1 );
            *pLED_R0R31 = 0; // Context switch to run()
        }
    }
}

void printBtn2() {
    while ( 1 ) { // Thread printBtn2
        if ( *pLED_R0R31 & R0R31SET3_MASK ) {
            putChar( pBTN );
            putChar( p2 );
            *pLED_R0R31 = 0; // Context switch to run()
        }
    }
}

void run() {
    btn_r0r31 = *pLED_R0R31;

    if ( btn_r0r31 & R0R31SET_MASK ) { // R0R31 set > 0!
        asm volatile( "la sp,_stack_top-100" );
        // Only when R0R31 set R0 (PC) = 0!
        putChar( pAterisk );

        if ( btn_r0r31 & R0R31SET1_MASK ) asm volatile( "j printBtn0" );
        if ( btn_r0r31 & R0R31SET2_MASK ) asm volatile( "j printBtn1" );
        if ( btn_r0r31 & R0R31SET3_MASK ) asm volatile( "j printBtn2" );
    } else {
        putChar( pSysString );
        // Initialize btn0-2 global variables! Could be located in XMODEM end-of-file section.
        btn0 = 0;
        btn1 = 0;
        btn2 = 0;
    }

    while ( 1 ) {
        if ( getBtn() & BTN0_MASK ) {
            btn0 = 0;
            *pLED_R0R31 = R0R31SET1_MASK; // Set 1 R0R31 (0-15) select
        }

        if ( getBtn() & BTN1_MASK ) {
            btn1 = 0;
            *pLED_R0R31 = R0R31SET2_MASK; // Set 2 R0R31 (0-15) select
        }

        if ( getBtn() & BTN2_MASK ) {
            btn2 = 0;
            *pLED_R0R31 = R0R31SET3_MASK; // Set 3 R0R31 (0-15) select
        }
    }
}
