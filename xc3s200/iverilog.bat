echo off
:: make file for Icarus Verilog simulator used to verify syntax and module
:: parameter check
if not [%1]==[] (
  if not defined IVERILOG (
    if not defined YOSYS (
      set IVERILOG=%1
      set PATH=%PATH%;%1\bin;%1\lib
    )
  )
)
if not defined IVERILOG (
  if not defined YOSYS (
    echo Run batch file with path to Icarus Verilog simulator installed directory
    echo as first argument. If Yosys/OSS is available run yosys.bat instead of
    echo verilog.bat!
    goto :END
  )
)
iverilog.exe -Wall -DXC3S200_TB -o xc3s_femtoRV32_tb.out -g2009 ..\lib\uart_io.v ..\femtoRV32.v uart.xise.v xc3s200_femtoRV32.v xc3s200_femtoRV32_tb.sv
if exist xc3s_femtoRV32_tb.out vvp.exe xc3s_femtoRV32_tb.out
if exist xc3s_femtoRV32_tb.out del xc3s_femtoRV32_tb.out
:END
