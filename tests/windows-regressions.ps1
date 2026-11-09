param([Parameter(Mandatory=$true)][string]$NodeBinary)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$TestRoot = Join-Path $Root ('.build\regression-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $TestRoot 'runtime') -Force | Out-Null
. (Join-Path $Root 'scripts\driver-files.ps1')
$owned = $null; $unrelated = $null; $locked = $null
try {
    $from = Join-Path $TestRoot 'source.dll'
    $destination = Join-Path $TestRoot 'destination.dll'
    [IO.File]::WriteAllText($from, 'same driver binary')
    Copy-Item -LiteralPath $from -Destination $destination
    # Readers are allowed but replacement is blocked, like a loaded DLL.
    $locked = [IO.File]::Open($destination, 'Open', 'Read', 'Read')
    Copy-WebcamDriver -From $from -Destination $destination
    'PASS: repeated driver configuration preserves an identical locked DLL'
    $locked.Dispose(); $locked = $null
    [IO.File]::WriteAllText($from, 'new driver binary')
    $locked = [IO.File]::Open($destination, 'Open', 'Read', 'Read')
    $failed = $false
    try { Copy-WebcamDriver -From $from -Destination $destination } catch { $failed = $_.Exception.Message -like '*Feche os aplicativos*' }
    if (-not $failed) { throw 'A different locked driver must report an actionable failure.' }
    $locked.Dispose(); $locked = $null
    Copy-WebcamDriver -From $from -Destination $destination
    if ([IO.File]::ReadAllText($destination) -ne 'new driver binary') { throw 'Unlocked driver update failed.' }
    'PASS: locked update reports the cause; unlocked update succeeds'
    $runtime = Join-Path $TestRoot 'runtime\node.exe'
    Copy-Item -LiteralPath $NodeBinary -Destination $runtime
    $owned = Start-Process -FilePath $runtime -ArgumentList '-e "setInterval(()=>{},1000)"' -WindowStyle Hidden -PassThru
    $unrelated = Start-Process -FilePath $NodeBinary -ArgumentList '-e "setInterval(()=>{},1000)"' -WindowStyle Hidden -PassThru
    # No PID file exists: the old shutdown script left this process alive.
    & (Join-Path $Root 'scripts\stop-installed.ps1') -InstallRoot $TestRoot
    if (-not $owned.WaitForExit(5000)) { throw 'Dedicated runtime remained locked.' }
    $unrelated.Refresh()
    if ($unrelated.HasExited) { throw 'Shutdown affected an unrelated Node process.' }
    'PASS: shutdown works without PID and preserves unrelated Node processes'
} finally {
    if ($locked) { $locked.Dispose() }
    foreach ($proc in @($owned, $unrelated)) {
        if ($proc -and -not $proc.HasExited) { Stop-Process -InputObject $proc -Force; [void]$proc.WaitForExit(5000) }
    }
    $resolved = [IO.Path]::GetFullPath($TestRoot)
    if (-not $resolved.StartsWith((Join-Path $Root '.build\regression-'), [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid cleanup target' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
