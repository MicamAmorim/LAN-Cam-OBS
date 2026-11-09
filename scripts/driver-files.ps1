function Copy-WebcamDriver {
    param([string]$From, [string]$Destination)
        # Preserve identical DLLs even when a browser has loaded the filter.
        if ((Test-Path -LiteralPath $Destination) -and
            ((Get-FileHash -LiteralPath $From -Algorithm SHA256).Hash -eq
             (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash)) {
            Write-Host "Driver ja atualizado: $([IO.Path]::GetFileName($From))"
            return
        }
        try { Copy-Item -LiteralPath $From -Destination $Destination -Force }
        catch { throw "Nao foi possivel atualizar $([IO.Path]::GetFileName($From)). Feche os aplicativos que usam a webcam (navegadores, OBS, Meet, Zoom e Teams) e tente novamente. Detalhes: $_" }
}
