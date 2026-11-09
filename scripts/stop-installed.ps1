# Encerra somente o runtime dedicado desta instalacao, mesmo sem PID salvo.
[CmdletBinding()]
param([string]$InstallRoot)
$ErrorActionPreference = 'Stop'
if (-not $InstallRoot) { $InstallRoot = Join-Path $PSScriptRoot '..' }
$Root = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
$Node = Join-Path $Root 'runtime\node.exe'
foreach ($proc in @(Get-Process -Name node -ErrorAction SilentlyContinue)) {
    $executable = $null
    try { $executable = $proc.Path } catch {}
    if ($executable -and [string]::Equals($executable, $Node, [StringComparison]::OrdinalIgnoreCase)) {
        Stop-Process -InputObject $proc -Force -ErrorAction Stop
        if (-not $proc.WaitForExit(5000)) { throw 'O runtime LAN Cam ainda esta em uso. Feche o aplicativo e tente novamente.' }
    }
}
$PidFile = Join-Path $Root '.local\server.pid'
if (Test-Path -LiteralPath $PidFile) { Remove-Item -LiteralPath $PidFile -Force }
