# Configure HTTPS para o acesso da câmera do celular pela rede local.
param([string]$MkcertPath)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$CertDir = Join-Path $Root 'certs'
. (Join-Path $PSScriptRoot 'resolve-mkcert.ps1')
if (-not $MkcertPath) { $MkcertPath = Find-Mkcert }
if (-not $MkcertPath) {
    Write-Host 'mkcert nao encontrado. Instale com: winget install -e --id FiloSottile.mkcert' -ForegroundColor Yellow
    exit 1
}
New-Item -ItemType Directory -Force -Path $CertDir | Out-Null
$IPs = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -notlike '0.*' } |
    Select-Object -ExpandProperty IPAddress -Unique)
if ($IPs.Count -eq 0) { throw 'Nenhum endereco IPv4 de rede encontrado. Conecte o PC ao Wi-Fi ou rede local.' }
Write-Host "Enderecos detectados: $($IPs -join ', ')"
& $MkcertPath -install
if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar a CA local.' }
$certFile = Join-Path $CertDir 'lan.pem'
$keyFile = Join-Path $CertDir 'lan-key.pem'
$names = @('localhost', '127.0.0.1', '::1') + $IPs
& $MkcertPath -cert-file $certFile -key-file $keyFile @names
if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar o certificado HTTPS.' }
$CARoot = (& $MkcertPath -CAROOT | Select-Object -First 1).Trim()
Copy-Item -LiteralPath (Join-Path $CARoot 'rootCA.pem') -Destination (Join-Path $CertDir 'rootCA.crt') -Force
Write-Host ''
Write-Host 'Pronto! Reinicie o servidor (npm start).' -ForegroundColor Green
Write-Host 'Para a CAMERA funcionar no navegador do celular, instale o arquivo rootCA.crt como CA confiavel no celular.'
Write-Host "Baixe-o por: http://$($IPs[0]):8787/local-ca.crt"
Write-Host "Depois acesse: https://$($IPs[0]):8788/phone?key=... (copie a URL exata do painel no PC)"
Write-Host 'IMPORTANTE: nunca compartilhe a CA privada/rootCA-key.pem ou o arquivo lan-key.pem.' -ForegroundColor Yellow
