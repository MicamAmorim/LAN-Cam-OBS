@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\build-installer.ps1" %*
if errorlevel 1 (
  echo.
  echo Falha ao gerar o instalador. Leia o erro acima.
  pause
  exit /b 1
)
echo.
echo Instalador criado em dist\
pause
