@echo off
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js nao encontrado. Instale Node.js 20 ou superior.
  pause
  exit /b 1
)
echo Abra no PC: http://localhost:8787
echo Para desligar, pressione CTRL+C.
node server.js
pause
