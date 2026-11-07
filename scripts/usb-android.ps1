$ErrorActionPreference = 'Stop'
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Host 'ADB nao encontrado. Instale: winget install -e --id Google.PlatformTools' -ForegroundColor Yellow
    exit 1
}
& adb devices
& adb reverse tcp:8787 tcp:8787
if ($LASTEXITCODE -ne 0) { throw 'Falha no ADB reverse. Habilite depuracao USB e autorize este PC no celular.' }
Write-Host ''
Write-Host 'USB pronto. No celular abra o link http://localhost:8787/phone?key=... mostrado no painel do PC.' -ForegroundColor Green
Write-Host 'O modo USB/JPEG nao necessita de HTTPS e nao depende de Wi-Fi.'
