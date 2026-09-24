echo off
:: make file for TCC C compiler
if not [%1]==[] (
  if not defined TCC (
    set TCC=%1
    set PATH=%PATH%;%1
  )
)
if not defined TCC (
  echo run batch file with path to TCC C compiler installed directory
  goto :END
)
cd..
if not exist .\bin mkdir bin
cd .\src
tcc.exe -I=%TCC%\include -o ..\bin\bin2hex.exe bin2hex.c
tcc.exe -I=%TCC%\include -o ..\bin\bin2init.exe bin2init.c
:END
