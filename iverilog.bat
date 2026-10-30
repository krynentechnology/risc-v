@echo off
:: make file for Icarus Verilog simulator
if not [%1]==[] (
  if not defined IVERILOG (
    set IVERILOG=%1
    set PATH=%PATH%;%1\bin;%1\lib
  )
)
if not defined IVERILOG (
  echo Run batch file with path to Icarus Verilog simulator installed directory
  echo as first argument. "VCD" argument is optional afterwards for defining
  echo GTK_WAVE to generate VCD file. Other argument skips vvp execution.
  goto :END
)
cd .\bin
if [%1]==[] (
  iverilog.exe -o jascRV32_tb.out -g2009 -I .. ..\jascRV32.v ..\jascRV32_tb.sv
) else (
  if "%1"=="VCD" (
    iverilog.exe -DGTK_WAVE -o jascRV32_tb.out -g2009 -I .. ..\jascRV32.v ..\jascRV32_tb.sv
  ) else (
    echo syntax check
    iverilog.exe -g2009 -I ..  ..\jascRV32.v ..\jascRV32_tb.sv
    del a.out
  )
)
if exist jascRV32_tb.out (
  vvp.exe jascRV32_tb.out
  del jascRV32_tb.out
)
cd ..
:END
