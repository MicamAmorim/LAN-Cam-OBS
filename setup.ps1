# Instalador Windows do LAN Cam OBS. Execute com .\setup.bat ou .\setup.ps1.
[CmdletBinding()]
param(
    [ValidateSet('wifi', 'usb', 'both')][string]$Mode = 'wifi',
    [switch]$NoStart,
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Set-Location -LiteralPath $Root

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($env:Path, $machine, $user -join ';')
}

function Find-Executable([string]$Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $candidates = @()
    if ($Name -eq 'node') {
        $candidates += "${env:ProgramFiles}\nodejs\node.exe"
        if (${env:ProgramFiles(x86)}) { $candidates += "${env:ProgramFiles(x86)}\nodejs\node.exe" }
    } elseif ($Name -eq 'mkcert') {
        $candidates += "${env:LOCALAPPDATA}\Microsoft\WinGet\Links\mkcert.exe"
        $packages = "${env:LOCALAPPDATA}\Microsoft\WinGet\Packages"
        if (Test-Path $packages) {
            $found = Get-ChildItem -LiteralPath $packages -File -Filter 'mkcert.exe' -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($found) { $candidates += $found.FullName }
        }
    } elseif ($Name -eq 'adb') {
        $candidates += "${env:LOCALAPPDATA}\Microsoft\WinGet\Links\adb.exe"
        $candidates += "${env:LOCALAPPDATA}\Android\Sdk\platform-tools\adb.exe"
    }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }
    return $null
}

function Install-WithWinget([string]$Id) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "Nao encontrei winget. Instale 'App Installer' da Microsoft Store e execute novamente. Pacote necessario: $Id"
    }
    Write-Host "Instalando $Id via winget..." -ForegroundColor Cyan
    & winget install --id $Id --exact --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "Falha ao instalar $Id (codigo $LASTEXITCODE)." }
    Refresh-Path
}

Write-Host "`nLAN Cam OBS - configuracao inicial ($Mode)" -ForegroundColor Cyan
Write-Host 'Nenhum ambiente Python/.venv e necessario: o projeto e 100% Node.js.'
Refresh-Path
$node = Find-Executable 'node'
$version = if ($node) { (& $node --version) -replace '\s', '' } else { '' }
$major = if ($version -match '^v(\d+)') { [int]$Matches[1] } else { 0 }
if ($major -lt 20) {
    Install-WithWinget 'OpenJS.NodeJS.LTS'
    $node = Find-Executable 'node'
    $version = if ($node) { (& $node --version) -replace '\s', '' } else { '' }
    $major = if ($version -match '^v(\d+)') { [int]$Matches[1] } else { 0 }
}
if ($major -lt 20) { throw 'Node.js 20+ nao foi encontrado apos a instalacao. Abra novo terminal e tente novamente.' }
Write-Host "Node.js encontrado: $version" -ForegroundColor Green

if ($Mode -in @('wifi', 'both')) {
    $mkcert = Find-Executable 'mkcert'
    if (-not $mkcert) {
        Install-WithWinget 'FiloSottile.mkcert'
        $mkcert = Find-Executable 'mkcert'
    }
    if (-not $mkcert) { throw 'mkcert nao encontrado apos a instalacao. Abra novo terminal e tente novamente.' }
    $env:Path = "$(Split-Path -Parent $mkcert);$env:Path"
    Write-Host "mkcert encontrado: $mkcert" -ForegroundColor Green
    Write-Host 'mkcert ira criar/confiar uma CA raiz local neste computador. Pode solicitar autorizacao do Windows.' -ForegroundColor Yellow
    & (Join-Path $Root 'scripts\setup-https.ps1')
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw 'Falha na configuracao de HTTPS.' }
}

if ($Mode -in @('usb', 'both')) {
    $adb = Find-Executable 'adb'
    if (-not $adb) {
        Install-WithWinget 'Google.PlatformTools'
        $adb = Find-Executable 'adb'
    }
    if (-not $adb) { throw 'ADB nao encontrado apos a instalacao. Abra novo terminal e tente novamente.' }
    $env:Path = "$(Split-Path -Parent $adb);$env:Path"
    Write-Host 'ADB instalado. Conecte o celular por USB, autorize a depuracao e execute .\scripts\usb-android.ps1' -ForegroundColor Green
}

if (-not $SkipTests) {
    Write-Host "`nValidando sintaxe..." -ForegroundColor Cyan
    & $node --check (Join-Path $Root 'server.js')
    if ($LASTEXITCODE -ne 0) { throw 'Erro de sintaxe no servidor.' }
    Write-Host 'Executando testes...' -ForegroundColor Cyan
    & $node --test (Join-Path $Root 'tests\server.test.js')
    if ($LASTEXITCODE -ne 0) { throw 'Um ou mais testes falharam. Servidor nao iniciado.' }
}

Write-Host "`nConfiguracao concluida." -ForegroundColor Green
Write-Host 'No PC, o painel e http://localhost:8787'
if ($Mode -in @('wifi', 'both')) {
    Write-Host 'No celular, instale manualmente a CA publica (rootCA.crt) antes de abrir o link HTTPS.' -ForegroundColor Yellow
    Write-Host 'O endereco para baixar e as URLs com chave aparecem no painel.'
}
if ($NoStart) { exit 0 }
Write-Host 'Iniciando servidor... Ctrl+C para parar.' -ForegroundColor Cyan
& $node (Join-Path $Root 'server.js')
exit $LASTEXITCODE
