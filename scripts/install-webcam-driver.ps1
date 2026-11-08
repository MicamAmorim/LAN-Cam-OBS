# Registro opcional e explicito de dispositivo DirectShow (requer UAC).
# O driver de terceiros e distribuido pelo projeto UnityCapture (MIT).
[CmdletBinding()]
param([switch]$Remove)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$InstalledDir = Join-Path $env:ProgramData 'LAN Cam Webcam\Driver'
$SourceDir = Join-Path $Root 'driver'

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $powershell = Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $args = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
    if ($Remove) { $args += ' -Remove' }
    try {
        $p = Start-Process -FilePath $powershell -ArgumentList $args -Verb RunAs -PassThru -Wait
        if ($p.ExitCode -ne 0) { throw "Registro retornou codigo $($p.ExitCode)" }
        exit 0
    } catch { Write-Error "O usuario cancelou a elevacao ou falhou: $_"; exit 1 }
}
if (-not $Remove) {
    New-Item -ItemType Directory -Path $InstalledDir -Force | Out-Null
    foreach ($name in @('UnityCaptureFilter32.dll','UnityCaptureFilter64.dll')) {
        $from = Join-Path $SourceDir $name
        if (-not (Test-Path -LiteralPath $from -PathType Leaf)) { throw "Arquivo ausente: $from" }
        Copy-Item -LiteralPath $from -Destination (Join-Path $InstalledDir $name) -Force
    }
}
# Os executaveis regsvr32 de 32/64 bits sao distintos no Windows x64.
$targets = @(
    @{ Executable = (Join-Path $env:windir 'SysWOW64\regsvr32.exe'); Binary = (Join-Path $InstalledDir 'UnityCaptureFilter32.dll') },
    @{ Executable = (Join-Path $env:windir 'System32\regsvr32.exe'); Binary = (Join-Path $InstalledDir 'UnityCaptureFilter64.dll') }
)
foreach ($item in $targets) {
    if ($Remove) {
        if (Test-Path -LiteralPath $item.Binary) {
            & $item.Executable /s /u $item.Binary
            if ($LASTEXITCODE -ne 0) { throw "Falha ao remover: $($item.Binary)" }
        }
    } else {
        # Nome de dispositivo independente do nome usado por outros projetos Unity.
        & $item.Executable /s '/i:UnityCaptureName=LAN Cam Webcam' $item.Binary
        if ($LASTEXITCODE -ne 0) { throw "Falha ao registrar driver: $($item.Binary)" }
    }
}
if ($Remove) {
    if (Test-Path -LiteralPath $InstalledDir) { Remove-Item -LiteralPath $InstalledDir -Recurse -Force }
    Write-Host 'Dispositivo LAN Cam Webcam removido.' -ForegroundColor Green
} else {
    Write-Host 'LAN Cam Webcam registrado. Reinicie o navegador/Meet/Zoom/Teams se a lista de cameras nao atualizar.' -ForegroundColor Green
}
