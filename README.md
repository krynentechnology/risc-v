# RISC-V
<h3>FemtoRV32</h3>
<p>The "quark/electron", the most elementary versions of FemtoRV32.</p>
<ul>
  <li>Verilog 2001 compliant - <a href="https://github.com/nokyalr/ise-14.7-windows-11">Xilinx ISE 14.7</a> synthesis.</li>
  <li>Reset address can be defined using PC_RESET (default is 0).</li>
  <li>The SP_RESET parameter sets the stack pointer register (R2). Default zero, when not defined the register R2 could be initialized by programming, otherwise the stack top is located at the end of the address space.</li>
  <li>The ADDR_WIDTH parameter sets the internal address bus (and address computation logic).</li>
  <li>The RVM parameter adds multiply-divide instructions (RV32IM).</li>
  <li>When RVM = 1, the DELAY_MULTIPLY parameter delays the multiply operation with one clock cycle (if required to meet timing constraints).</li>
  <li>In general, instructions take two clock cycles, except for load/store branch instructions (three clock cycles) or multiple clock ALU operations (division).</li>
</ul>
<p>For Icarus Verilog simulation run "iverilog.bat" in the "xc3s200" folder. For other simulators (e.g. Modelsim, Questasim, Vivado) define XC3S200_TB=1 for the project and locate the files "xc3s200_boot.mem" and "xc3s200_sys.bin" where the simulator expects them!</p>
<h3>Xilinx Spartan-3 Starter Kit (XC3S200-4FT256) target</h3>
<code>
    GCC linker script

    ENTRY(_start)

    MEMORY {
        SRAM(rwx)      : ORIGIN = 0x0, LENGTH = 1M
        BRAM_text(rx)  : ORIGIN = 0x100000, LENGTH = 2k
        BRAM_data(rwx) : ORIGIN = 0x100000, LENGTH = 2k
        IO(rwx)        : ORIGIN = 0x100800, LENGTH = (1M - 2k)
    }

    SECTIONS {
        _stack_top = ORIGIN(BRAM_data) + LENGTH(BRAM_data);

        .text   : {KEEP(*(.text.boot))
                   KEEP(*(.stack)) /* Start of stack address space */
                   *(.text*)}   > BRAM_text
        .rodata : {*(.rodata*)} > BRAM_text
        .data   : {*(.data*)}   > BRAM_data AT > BRAM_text
        .bss    : {*(.bss*)}    > BRAM_data
    }
</code>
<code>
    C boot code

    // Top of stack
    extern unsigned _stack_top;

    void __attribute__((section (".text.boot"))) _start() {
    /*
        The RISC-V GCC toolchain does not initialize the stack pointer (R2-SP-X2).
        The stack pointer is default zero, when not defined the register R2 could
        be initialized by programming, otherwise the stack top is located at the
        end of the RISC-V processor address space.

        If the FPGA systhesis sets the stack pointer register to _stack_top, the
        "asm volatile( "la sp,_stack_top" );" or equivalent inline assembly could
        be omitted!
    */
        asm volatile( "la sp,_stack_top" );
        asm volatile( "j run" );
    }

    void run() {
       .
       .
       .
    }
</code>
