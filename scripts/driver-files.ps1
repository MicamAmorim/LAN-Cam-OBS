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
function Invoke-WebcamRegistration {
    param([string]$Executable, [string]$Binary, [switch]$Remove)
    # GUI executables do not reliably populate LASTEXITCODE in Windows PowerShell.
    $arguments = if ($Remove) { '/s /u "' + $Binary + '"' }
                 else { '/s "/i:UnityCaptureName=LAN Cam Webcam" "' + $Binary + '"' }
    $registration = Start-Process -FilePath $Executable -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
    if ($null -eq $registration.ExitCode) { throw 'O Windows nao retornou o codigo de saida do regsvr32.' }
    if ($registration.ExitCode -ne 0) {
        throw "Regsvr32 falhou (codigo $($registration.ExitCode)), arquivo: $Binary. Feche os aplicativos que usam a webcam e tente novamente."
    }
}
