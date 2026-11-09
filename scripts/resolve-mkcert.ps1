function Find-Mkcert {
    $candidates = @()
    $command = Get-Command mkcert -CommandType Application -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }
    $candidates += (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\mkcert.exe')
    $packages = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path -LiteralPath $packages) {
        $candidates += @(Get-ChildItem -LiteralPath $packages -Directory -Filter 'FiloSottile.mkcert_*' |
            ForEach-Object { Join-Path $_.FullName 'mkcert.exe' })
    }
    foreach ($candidate in $candidates) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        $item = Get-Item -LiteralPath $candidate -Force
        # Windows PowerShell 5.1 pode falhar ao executar o link do WinGet.
        for ($depth = 0; $item.LinkType -and $item.Target -and $depth -lt 8; $depth++) {
            $target = @($item.Target)[0]
            if (-not [IO.Path]::IsPathRooted($target)) { $target = Join-Path $item.DirectoryName $target }
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { break }
            $item = Get-Item -LiteralPath $target -Force
        }
        if (-not $item.LinkType) { return $item.FullName }
    }
    return $null
}
