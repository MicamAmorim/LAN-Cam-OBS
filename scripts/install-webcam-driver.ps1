# Registro opcional e explicito de dispositivo DirectShow (requer UAC).
# O driver de terceiros e distribuido pelo projeto UnityCapture (MIT).
[CmdletBinding()]
param([switch]$Remove, [switch]$Include32Bit)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$InstalledDir = Join-Path $env:ProgramData 'LAN Cam Webcam\Driver'
$SourceDir = Join-Path $Root 'driver'

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $powershell = Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $elevatedArgs = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '"'
    if ($Remove) { $elevatedArgs += ' -Remove' }
    if ($Include32Bit) { $elevatedArgs += ' -Include32Bit' }
    try {
        $p = Start-Process -FilePath $powershell -ArgumentList $elevatedArgs -Verb RunAs -PassThru -Wait
    } catch {
        Write-Error "Nao foi possivel iniciar o PowerShell administrativo (UAC recusado ou indisponivel): $_"
        exit 1
    }
    if ($p.ExitCode -ne 0) {
        Write-Error "Registro executado com privilegios administrativos, mas falhou (codigo $($p.ExitCode)). Verifique a mensagem na janela administrativa."
        exit $p.ExitCode
    }
    exit 0
}
if (-not $Remove) {
    New-Item -ItemType Directory -Path $InstalledDir -Force | Out-Null
    foreach ($name in @('UnityCaptureFilter32.dll','UnityCaptureFilter64.dll')) {
        $from = Join-Path $SourceDir $name
        if (-not (Test-Path -LiteralPath $from -PathType Leaf)) { throw "Arquivo ausente: $from" }
        Copy-Item -LiteralPath $from -Destination (Join-Path $InstalledDir $name) -Force
    }
}
# Windows x64: System32 contem regsvr32 de 64 bits; SysWOW64 o de 32 bits.
# Priorizar x64: navegadores modernos geralmente usam processo de 64 bits.
# O componente opcional x86 pode falhar em Windows sem suas dependencias e
# nao deve impedir o registro do componente principal.
$targets = @(
    @{ Architecture = 'x64'; Executable = (Join-Path $env:windir 'System32\regsvr32.exe'); Binary = (Join-Path $InstalledDir 'UnityCaptureFilter64.dll') }
)
if ($Include32Bit) {
    $targets += @{ Architecture = 'x86'; Executable = (Join-Path $env:windir 'SysWOW64\regsvr32.exe'); Binary = (Join-Path $InstalledDir 'UnityCaptureFilter32.dll') }
}
foreach ($item in $targets) {
    if (-not (Test-Path -LiteralPath $item.Binary -PathType Leaf)) {
        if ($Remove) { continue }
        throw "Arquivo nao encontrado: $($item.Binary)"
    }
    if ($Remove) {
        Write-Host "Removendo filtro $($item.Architecture): $($item.Binary)"
        & $item.Executable /s /u $item.Binary
    } else {
        Write-Host "Registrando filtro $($item.Architecture): $($item.Binary)"
        & $item.Executable /s '/i:UnityCaptureName=LAN Cam Webcam' $item.Binary
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Regsvr32 $($item.Architecture) falhou (codigo $LASTEXITCODE), arquivo: $($item.Binary). Execute regsvr32 sem /s para ver os detalhes."
    }
}
if ($Remove) {
    if ($Include32Bit -and (Test-Path -LiteralPath $InstalledDir)) { Remove-Item -LiteralPath $InstalledDir -Recurse -Force }
    elseif (Test-Path -LiteralPath $InstalledDir) { Write-Host 'Os binarios foram mantidos para nao remover um filtro x86 possivelmente registrado. Use -Remove -Include32Bit para desinstalar ambos.' }
    Write-Host 'Dispositivo LAN Cam Webcam removido.' -ForegroundColor Green
} else {
    Write-Host 'LAN Cam Webcam x64 registrado. Reinicie o navegador/Meet/Zoom/Teams para atualizar a lista de cameras.' -ForegroundColor Green
    if (-not $Include32Bit) { Write-Host 'A instalacao x86 foi ignorada intencionalmente. Para incluir aplicativos de 32 bits, execute novamente com -Include32Bit.' }
}
