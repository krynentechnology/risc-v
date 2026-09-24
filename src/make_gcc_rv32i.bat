echo off
:: make file for RISCV GCC C/CC++ compiler
if not [%1]==[] (
  if not defined RISCVGCC (
    set RISCVGCC=%1
    set PATH=%PATH%;%1\bin;%1\lib
  )
)
if not defined RISCVGCC (
  echo Run batch file with path to RISCV GCC C/C++ compiler installed directory,
  echo "o" argument is optional afterwards for to keep generated object files.
  goto :END
)
if exist xc3s200_boot.c (
  riscv-none-elf-gcc.exe -Wall -march=rv32i -mabi=ilp32 -S -o xc3s200_boot.s xc3s200_boot.c
  riscv-none-elf-gcc.exe -Wall -march=rv32i -mabi=ilp32 -nostdlib -ffreestanding -fno-delete-null-pointer-checks -s -Os -Txc3s200_boot.ld -o xc3s200_boot.o xc3s200_boot.c
)
if exist xc3s200_boot.o (
  riscv-none-elf-objcopy.exe -O binary xc3s200_boot.o ..\xc3s200\xc3s200_boot.bin
  riscv-none-elf-objcopy.exe -O verilog xc3s200_boot.o xc3s200_boot.ver
  if exist ..\xc3s200\xc3s200_boot.bin (
    if exist ..\bin\bin2hex.exe (
      ..\bin\bin2hex.exe ..\xc3s200\xc3s200_boot.bin
    )
    if exist ..\bin\bin2init.exe (
      ..\bin\bin2init.exe ..\xc3s200\xc3s200_boot.bin
    )
  )
  if exist ..\xc3s200\xc3s200_boot.hex (
    if exist ..\xc3s200\xc3s200_boot.mem (
      del ..\xc3s200\xc3s200_boot.mem
    )
    ren ..\xc3s200\xc3s200_boot.hex xc3s200_boot.mem
  )
  if not "%1"=="o" (
    del xc3s200_boot.o
  )
)
if exist xc3s200_sys.c (
  riscv-none-elf-gcc.exe -Wall -march=rv32i -mabi=ilp32 -nostdlib -ffreestanding -fno-delete-null-pointer-checks -s -Os -Txc3s200_sys.ld -o xc3s200_sys.o xc3s200_sys.c
)
if exist xc3s200_sys.o (
  riscv-none-elf-objcopy.exe -O binary xc3s200_sys.o ..\xc3s200\xc3s200_sys.bin
  if exist ..\xc3s200\xc3s200_sys.bin (
    if exist ..\bin2hex.exe (
      ..\bin2hex.exe ..\xc3s200\xc3s200_sys.bin
    )
  )
  if exist ..\xc3s200\xc3s200_sys.hex (
    if exist ..\xc3s200\xc3s200_sys.mem (
      del ..\xc3s200\xc3s200_sys.mem
    )
    ren ..\xc3s200\xc3s200_sys.hex xc3s200_sys.mem
  )
  if not "%1"=="o" (
    del xc3s200_sys.o
  )
)
:END
