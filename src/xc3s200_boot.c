/*
 *  Boot soft core Digilent Xilinx Spartan-3 Starter Kit (XC3S200-4FT256). Boots
 *  from BRAM; writes soft core system firmware to SRAM via terminal XMODEM
 *  transfer and starts system firmware when XMODEM transfer is finished.
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

volatile unsigned int* const pLED = (unsigned int*)0x120000; // LEDs
volatile unsigned int* const pSSG = (unsigned int*)0x140000; // Seven Segment Display
volatile unsigned int* const pUart = (unsigned int*)0x180000; // Read = uart data/status

void putNibble( char nibble ) {
    while ( !( *pUart & 0x400 )); // Uart TX not ready, wait...

    nibble &= 0x0F;
    *pUart = ( nibble > 9 ) ? nibble + '7' : nibble + '0';
}

void putChar( char* pString ) {
    while ( *pString ) {
        while ( !( *pUart & 0x400 )); // Uart TX not ready, wait...

        *pUart = *pString;
        pString++;
    }
}

#define UART_RX_VALID_MASK 0x100
#define UART_TX_READY_MASK 0x400
#define BTN0_LED_MASK      0x10
#define XMODEM_READY_MASK  0x10000

typedef void VOID_FUNC();
VOID_FUNC* const pSysReset = 0;
char* const pBootMsg = "\rBoot xc3c200, wait for xmodem system binary (press BNT0)...\r";

void run() {
    *pSSG = 0x83A3A387; // "boot"
    putChar( pBootMsg ); // Starts with '\r' -> UART_IO PROMPT

    // Console sends UART_IO PROMPT after '\r' Carriage Return
    while ( !( *pUart & UART_TX_READY_MASK )); // Uart TX not ready, wait...

    unsigned int btn0 = 0;

    do {
        if ( !btn0 && ( *pLED & BTN0_LED_MASK )) { // BNT0 active
            if ( *pUart & UART_TX_READY_MASK ) {
                *pUart = 0x15; // Send NAK to XMODEM transmitter.
                btn0 = *pLED & BTN0_LED_MASK; // Update BNT0
            }
        }
    } while ( !( *pUart & XMODEM_READY_MASK )); // Uart XMODEM not ready, wait...

    volatile unsigned char* pSramByte = 0;
    unsigned int uart;

    do {
        uart = *pUart;

        if (( uart & ( XMODEM_READY_MASK | UART_RX_VALID_MASK )) == ( XMODEM_READY_MASK | UART_RX_VALID_MASK )) { // Uart RX data valid?
            *pSramByte = (unsigned char)uart;
            pSramByte++;
        }
    } while ( uart & XMODEM_READY_MASK ); // Uart XMODEM active
/*
    while ( !( *pLED & BTN0_LED_MASK )); // BTN0, wait...

    pSramByte = 0;
    putNibble(( *pSramByte ) >> 4 );
    putNibble( *pSramByte );
*/
    pSysReset(); // Does not return!
}
