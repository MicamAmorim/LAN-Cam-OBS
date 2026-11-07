# Gera instalador Windows x64 com Node.js LTS embutido e SHA-256 verificado.
[CmdletBinding()]
param(
    [string]$NodeVersion = '24.22.2',
    [switch]$SkipTests,
    [switch]$NoInstallInno
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$BuildDir = Join-Path $Root '.build'
$CacheDir = Join-Path $BuildDir 'cache'
$Stage = Join-Path $BuildDir 'windows\app'
$Dist = Join-Path $Root 'dist'
$NodeBinary = Join-Path $CacheDir "node-v$NodeVersion-win-x64.exe"
$DownloadBase = "https://nodejs.org/dist/v$NodeVersion"
$ProgressPreference = 'SilentlyContinue'

function Find-Iscc {
    $found = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($found) { return $found.Source }
    $programFilesX86 = [Environment]::GetFolderPath('ProgramFilesX86')
    $paths = @()
    if ($programFilesX86) { $paths += (Join-Path $programFilesX86 'Inno Setup 6\ISCC.exe') }
    if ($env:ProgramFiles) { $paths += (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe') }
    foreach ($item in $paths) {
        if (Test-Path -LiteralPath $item -PathType Leaf) { return $item }
    }
    return $null
}

Write-Host ''
Write-Host 'LAN Cam OBS - build de instalador Windows x64' -ForegroundColor Cyan
if (-not [Environment]::Is64BitOperatingSystem) {
    throw 'Windows x64 e necessario para este build.'
}
New-Item -ItemType Directory -Force -Path $CacheDir, $Dist | Out-Null

Write-Host "Conferindo Node.js v$NodeVersion (Windows x64)..."
if (-not (Test-Path -LiteralPath $NodeBinary)) {
    Invoke-WebRequest -Uri "$DownloadBase/win-x64/node.exe" -OutFile $NodeBinary -UseBasicParsing
}
$shasums = (Invoke-WebRequest -Uri "$DownloadBase/SHASUMS256.txt" -UseBasicParsing).Content
$hashMatch = [regex]::Match($shasums, '(?m)^([0-9a-fA-F]{64})\s+win-x64/node\.exe\s*$')
if (-not $hashMatch.Success) { throw 'Nao foi encontrado win-x64/node.exe no SHASUMS256.txt oficial.' }
$expected = $hashMatch.Groups[1].Value
$actual = (Get-FileHash -LiteralPath $NodeBinary -Algorithm SHA256).Hash
if ($actual -ine $expected) {
    Remove-Item -LiteralPath $NodeBinary -Force
    throw 'Hash SHA-256 do Node.js invalido. Download excluido e build cancelado.'
}
Write-Host 'Runtime verificado com SHA-256 do Node.js oficial.' -ForegroundColor Green

if (Test-Path -LiteralPath $Stage) { Remove-Item -LiteralPath $Stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Stage | Out-Null
foreach ($file in @('server.js','package.json','README.md','SETUP.md','INSTALLER.md')) {
    Copy-Item -LiteralPath (Join-Path $Root $file) -Destination $Stage -Force
}
foreach ($dir in @('lib','public')) {
    Copy-Item -LiteralPath (Join-Path $Root $dir) -Destination (Join-Path $Stage $dir) -Recurse -Force
}
New-Item -ItemType Directory -Force -Path (Join-Path $Stage 'runtime'), (Join-Path $Stage 'scripts') | Out-Null
Copy-Item -LiteralPath $NodeBinary -Destination (Join-Path $Stage 'runtime\node.exe') -Force
foreach ($file in @('setup-https.ps1','usb-android.ps1','launch-installed.ps1','stop-installed.ps1','configure-wifi.ps1')) {
    Copy-Item -LiteralPath (Join-Path $Root "scripts\$file") -Destination (Join-Path $Stage 'scripts') -Force
}

if (-not $SkipTests) {
    Write-Host 'Verificando sintaxe e testes automatizados...'
    & $NodeBinary --check (Join-Path $Root 'server.js')
    if ($LASTEXITCODE -ne 0) { throw 'Erro de sintaxe no servidor.' }
    & $NodeBinary --test (Join-Path $Root 'tests\server.test.js')
    if ($LASTEXITCODE -ne 0) { throw 'Testes falharam. Build interrompido.' }
}

$iscc = Find-Iscc
if (-not $iscc -and -not $NoInstallInno) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'Instale Inno Setup 6 (https://jrsoftware.org/isdl.php) antes de compilar.'
    }
    Write-Host 'Instalando Inno Setup 6 via winget...' -ForegroundColor Cyan
    & winget install --id JRSoftware.InnoSetup --exact --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel instalar o Inno Setup via winget.' }
    $iscc = Find-Iscc
}
if (-not $iscc) { throw 'ISCC.exe nao encontrado. Instale o Inno Setup 6.' }

$version = (Get-Content (Join-Path $Root 'package.json') -Raw | ConvertFrom-Json).version
$iss = Join-Path $Root 'installer\LAN-Cam-OBS.iss'
Write-Host "Compilando instalador v$version..."
& $iscc "/DStageDir=$Stage" "/DAppVersion=$version" "/O$Dist" $iss
if ($LASTEXITCODE -ne 0) { throw "Compilador Inno Setup falhou (codigo $LASTEXITCODE)." }
$installer = Join-Path $Dist "LAN-Cam-OBS-Setup-$version-win-x64.exe"
if (-not (Test-Path -LiteralPath $installer)) { throw "Instalador nao localizado: $installer" }
$sha = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash
Write-Host ''
Write-Host "INSTALADOR PRONTO: $installer" -ForegroundColor Green
Write-Host "SHA-256: $sha"
Write-Host 'Sem assinatura de codigo: o SmartScreen pode mostrar um aviso.' -ForegroundColor Yellow
