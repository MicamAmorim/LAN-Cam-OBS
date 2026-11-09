# Build local + publicacao verificavel no GitHub Releases.
# Por padrao publica v0.3.0-rc.1 como pre-release: ainda exige teste de hardware.
[CmdletBinding()]
param([switch]$Stable, [ValidateRange(1,99)][int]$Candidate = 1)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Repository = 'MicamAmorim/LAN-Cam-OBS'
$Branch = 'feature/dual-camera-modes'
Set-Location -LiteralPath $Root
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git nao foi encontrado no PATH.' }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI (gh) nao foi encontrado no PATH.' }
& gh auth status
if ($LASTEXITCODE -ne 0) { throw 'Entre no GitHub CLI usando gh auth login.' }
$current = (& git branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or $current -ne $Branch) {
    throw "Alterne primeiro para a branch $Branch. Branch atual: $current"
}
$dirty = @(& git status --porcelain)
if ($dirty.Count -gt 0) { throw 'Existem arquivos alterados no Git. Commit ou guarde as mudancas antes de publicar.' }
& git pull --ff-only origin $Branch
if ($LASTEXITCODE -ne 0) { throw 'git pull falhou.' }
$version = (Get-Content -LiteralPath (Join-Path $Root 'package.json') -Raw | ConvertFrom-Json).version
$tag = if ($Stable) { "v$version" } else { "v$version-rc.$Candidate" }
# Primeira publicacao: release ausente e esperado. Listar releases retorna 200
# mesmo quando nao ha nenhuma, evitando erro fatal em PowerShell 5.1.
$publishedTags = @(& gh api "repos/$Repository/releases" --paginate --jq '.[].tag_name')
if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel consultar as releases no GitHub.' }
if ($publishedTags -contains $tag) { throw "Release $tag ja existe. Nao sera sobrescrita automaticamente." }
Write-Host "Buildando $version para $Branch..." -ForegroundColor Cyan
& (Join-Path $Root 'scripts\build-installer.ps1')
if (-not $?) { throw 'Build do instalador falhou.' }
$filename = "LAN-Cam-OBS-Setup-$version-win-x64.exe"
$installer = Join-Path $Root "dist\$filename"
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) { throw "Instalador nao localizado: $installer" }
$hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
$checksum = Join-Path $Root "dist\$filename.sha256"
Set-Content -LiteralPath $checksum -Value "$hash  $filename" -Encoding ASCII
$commit = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel consultar o commit.' }
$notes = @'
LAN Cam OBS v0.3.0: OBS (WebRTC/JPEG) e webcam virtual independente para Meet/Zoom/Teams.
No Windows, registre o dispositivo virtual uma unica vez pelo atalho LAN Cam OBS - Instalar webcam virtual (UAC); depois ative a webcam no painel.
O modo webcam dispensa o OBS e transmite video, nao microfone. A instalacao do driver e opcional.
Primeiro release publico: teste a instalacao e a compatibilidade com seus aplicativos/dispositivos antes de distribuicao em larga escala.
'@
$releaseArgs = @('release','create',$tag,$installer,$checksum,'--repo',$Repository,
  '--target',$commit,'--title',"LAN Cam OBS $tag",'--notes',$notes)
if (-not $Stable) { $releaseArgs += '--prerelease' }
& gh @releaseArgs
if ($LASTEXITCODE -ne 0) { throw 'Falha ao criar GitHub Release.' }
Write-Host "Publicado: https://github.com/$Repository/releases/tag/$tag" -ForegroundColor Green
