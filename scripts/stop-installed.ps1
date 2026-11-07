# Para apenas o processo criado pelo launcher desta instalacao.
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Server = Join-Path $Root 'server.js'
$PidFile = Join-Path $Root '.local\server.pid'
if (-not (Test-Path -LiteralPath $PidFile)) { exit 0 }
$processId = 0
[void][int]::TryParse((Get-Content -LiteralPath $PidFile -Raw).Trim(), [ref]$processId)
if ($processId -gt 0) {
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
    if ($proc -and $proc.CommandLine -and $proc.CommandLine.Contains($Server)) {
        Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
    }
}
Remove-Item -LiteralPath $PidFile -Force -ErrorAction SilentlyContinue
