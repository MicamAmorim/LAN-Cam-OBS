$ErrorActionPreference = 'Stop'
$powershell = Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe'
& $powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'install-webcam-driver.ps1')
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw 'Falha ao instalar webcam.' }
& $powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'configure-wifi.ps1') -NoRestart
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw 'Falha ao configurar Wi-Fi.' }
