# Configuracao opt-in de HTTPS. Pode solicitar elevacao para instalar CA no Windows.
param([switch]$NoRestart)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Write-Host ''
Write-Host 'LAN Cam OBS - configurar HTTPS para o celular via Wi-Fi' -ForegroundColor Cyan
Write-Host 'Este procedimento cria uma autoridade certificadora local no computador.'
Write-Host 'Depois, instale manualmente a CA publica no seu celular (somente se confiar nesse computador).' -ForegroundColor Yellow
Write-Host ''
$mkcert = Get-Command mkcert -ErrorAction SilentlyContinue
if (-not $mkcert) {
    $links = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
    if (Test-Path -LiteralPath (Join-Path $links 'mkcert.exe')) { $env:Path = "$links;$env:Path" }
    $mkcert = Get-Command mkcert -ErrorAction SilentlyContinue
}
if (-not $mkcert) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'Instale mkcert manualmente: https://github.com/FiloSottile/mkcert'
    }
    Write-Host 'Instalando mkcert (necessita Internet)...' -ForegroundColor Cyan
    & winget install --id FiloSottile.mkcert --exact --accept-source-agreements --accept-package-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao instalar mkcert. Verifique o winget.' }
    $env:Path = "$([Environment]::GetEnvironmentVariable('Path','Machine'));$([Environment]::GetEnvironmentVariable('Path','User'));$env:Path"
    $links = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
    $env:Path = "$links;$env:Path"
}
if (-not (Get-Command mkcert -ErrorAction SilentlyContinue)) {
    throw 'mkcert instalado, mas nao encontrado no PATH. Abra outro terminal e tente novamente.'
}
& (Join-Path $Root 'scripts\setup-https.ps1')
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw 'Falha ao configurar HTTPS.' }
if (-not $NoRestart) {
    Write-Host 'Reiniciando o servidor local...' -ForegroundColor Cyan
    & (Join-Path $Root 'scripts\stop-installed.ps1')
    & (Join-Path $Root 'scripts\launch-installed.ps1')
}
Write-Host ''
Write-Host 'Pronto. Copie o link HTTPS da camera no painel do computador.' -ForegroundColor Green
Write-Host 'A CA publica pode ser baixada na rede local em http://IP-DO-PC:8787/local-ca.crt'
Write-Host 'ATENCAO: o celular precisa confiar manualmente nessa CA antes de usar a camera.' -ForegroundColor Yellow
