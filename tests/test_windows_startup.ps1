$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path $root '.test-runtime\startup no node'
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
$listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
$listener.Start(); $port = $listener.LocalEndpoint.Port; $listener.Stop()
$status = Join-Path $fixture 'status.txt'
$originalPath = $env:PATH
try {
    $env:PATH = "$env:SystemRoot\System32"
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File (Join-Path $root 'server/start-viewer.ps1') -NoOpen -Port $port -StateDirectory $fixture -Request 'cold-start' -StatusFile $status
    if ($LASTEXITCODE -ne 0 -or [IO.File]::ReadAllText($status) -ne 'cold-start:ready') { throw 'Cold start failed' }
    $health = Invoke-RestMethod "http://127.0.0.1:$port/health"
    if ($health.runtime -ne 'Windows PowerShell/.NET') { throw 'Wrong runtime' }
    Write-Output 'PASS: hidden cold startup with Node absent from PATH, spaced snapshot directory and request-specific readiness.'
} finally {
    $env:PATH = $originalPath
    # Stop only the process created for this unique test port and fixture.
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" | Where-Object {
        $_.CommandLine.Contains($fixture) -and $_.CommandLine.Contains("-Server -Port $port ")
    } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
}
