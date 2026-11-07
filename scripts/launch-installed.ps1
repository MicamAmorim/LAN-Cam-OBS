# Atalho do aplicativo instalado: inicia o servidor se necessario e abre o painel.
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Server = Join-Path $Root 'server.js'
$Node = Join-Path $Root 'runtime\node.exe'
$Local = Join-Path $Root '.local'
$PidFile = Join-Path $Local 'server.pid'
$Url = 'http://localhost:8787'
New-Item -ItemType Directory -Force -Path $Local | Out-Null

function Is-Ours([int]$ProcessId) {
    if ($ProcessId -le 0) { return $false }
    $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" -ErrorAction SilentlyContinue
    return [bool]($proc -and $proc.CommandLine -and $proc.CommandLine.Contains($Server))
}
$running = $false
if (Test-Path -LiteralPath $PidFile) {
    $savedId = 0
    [void][int]::TryParse((Get-Content -LiteralPath $PidFile -Raw).Trim(), [ref]$savedId)
    $running = Is-Ours $savedId
}
if (-not $running) {
    if (-not (Test-Path -LiteralPath $Node)) { throw 'Node.js embutido ausente. Reinstale o aplicativo.' }
    $quotedServer = '"' + $Server + '"'
    $proc = Start-Process -FilePath $Node -ArgumentList $quotedServer -WorkingDirectory $Root -WindowStyle Hidden -PassThru
    Set-Content -LiteralPath $PidFile -Value $proc.Id -Encoding ASCII
}
# A porta pode ja estar ocupada por outra instalacao: nao alterar servidor existente.
$ready = $false
for ($n = 0; $n -lt 40; $n++) {
    try {
        $response = Invoke-WebRequest -Uri "$Url/api/config" -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Milliseconds 250
}
if ($ready) {
    Start-Process $Url
} else {
    Add-Type -AssemblyName System.Windows.Forms
    [void][System.Windows.Forms.MessageBox]::Show(
        'O servidor nao iniciou em http://localhost:8787. Verifique se a porta 8787 esta livre ou se outra copia do aplicativo esta em execucao.',
        'LAN Cam OBS')
}
