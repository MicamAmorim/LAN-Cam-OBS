@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
if errorlevel 1 (
  echo.
  echo Instalacao interrompida. Verifique o erro acima.
  pause
  exit /b 1
)
