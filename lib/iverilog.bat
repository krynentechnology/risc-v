echo off
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
if exist .\bin rmdir /Q/S bin
if not exist .\bin mkdir bin
cd .\bin
if [%1]==[] (
  iverilog.exe -o uart_tb.out -I .. ..\uart.v ..\uart_io.v ..\uart_tb.sv
) else (
  if "%1"=="VCD" (
    iverilog.exe -DGTK_WAVE -o uart_tb.out -I .. ..\uart.v ..\uart_io.v ..\uart_tb.sv
  ) else (
    iverilog.exe -I .. ..\uart.v ..\uart_io.v ..\uart_tb.sv
  )
)
if exist uart_tb.out vvp.exe uart_tb.out
cd ..
:END
