# Windows launcher without Node on PATH: replaces an outdated Balatro Observer viewer, cold-starts the
# .NET server, reports request-specific readiness, reuses a running viewer, and refuses a foreign listener.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path $root '.test-runtime\startup no node'
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
$listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
$listener.Start(); $port = $listener.LocalEndpoint.Port; $listener.Stop()
$status = Join-Path $fixture 'status.txt'
$stderr = Join-Path $fixture 'launcher-stderr.txt'
$powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$launcher = Join-Path $root 'server\start-viewer.ps1'
$release = Get-Content -LiteralPath (Join-Path $root 'BalatroObserver.json') -Raw | ConvertFrom-Json
$originalPath = $env:PATH
$outdated = $null
function Invoke-Launcher([string]$Request, [int]$OnPort) {
    $process = Start-Process -FilePath $powershell -ArgumentList @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',"`"$launcher`"",'-NoOpen','-Port',$OnPort,'-StateDirectory',"`"$fixture`"",'-Request',$Request,'-StatusFile',"`"$status`"") -WindowStyle Hidden -PassThru -RedirectStandardError $stderr
    $null = $process.Handle   # cache the handle, or ExitCode is null once the process has exited
    $process.WaitForExit()   # not Start-Process -Wait: that would also wait for the server the launcher starts
    return $process.ExitCode
}
try {
    $env:PATH = "$env:SystemRoot\System32"

    # 1. An older Balatro Observer server already holds the port: a copy of this release reporting version 0.0.1.
    $old = Join-Path $fixture 'older-release'
    if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Recurse -Force }
    foreach ($name in 'BalatroObserver.json','server\start-viewer.ps1','server\viewer-server.cs','viewer\observer.html','assets\wiki-art.json','THIRD_PARTY_NOTICES.md') {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $old $name)) | Out-Null
        Copy-Item -LiteralPath (Join-Path $root $name) -Destination (Join-Path $old $name)
    }
    $manifest = Join-Path $old 'BalatroObserver.json'
    [IO.File]::WriteAllText($manifest, ([IO.File]::ReadAllText($manifest) -replace '"version": "[^"]+"', '"version": "0.0.1"'))
    $outdated = Start-Process -FilePath $powershell -ArgumentList @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',"`"$(Join-Path $old 'server\start-viewer.ps1')`"",'-Server','-Port',$port,'-StateDirectory',"`"$fixture`"") -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(15); $health = $null
    do { Start-Sleep -Milliseconds 200; try { $health = Invoke-RestMethod "http://127.0.0.1:$port/health" } catch { } } while (-not $health -and [DateTime]::UtcNow -lt $deadline)
    if ($health.version -ne '0.0.1') { throw 'Outdated fixture server did not start' }

    # 2. The launcher replaces it, cold-starts this release and reports readiness for this request only.
    $code = Invoke-Launcher 'cold-start' $port
    if ($code -ne 0 -or [IO.File]::ReadAllText($status) -ne 'cold-start:ready') { throw "Cold start failed (exit $code, status '$(Get-Content $status -Raw -ErrorAction SilentlyContinue)'): $(Get-Content $stderr -Raw)" }
    $health = Invoke-RestMethod "http://127.0.0.1:$port/health"
    if ($health.runtime -ne 'Windows PowerShell/.NET' -or $health.version -ne $release.version) { throw 'Wrong runtime or version after replacing the outdated viewer' }
    $outdated.WaitForExit(5000) | Out-Null
    if (-not $outdated.HasExited) { throw 'Outdated viewer was not stopped' }
    if (-not (Select-String -LiteralPath (Join-Path $root 'viewer-launch.log') -Pattern 'Replacing older viewer' -Quiet)) { throw 'Replacement was not logged' }

    # 3. A second launch reuses the running viewer without starting another.
    $before = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains("-Server -Port $port ") }).Count
    $code = Invoke-Launcher 'reuse' $port
    if ($code -ne 0 -or [IO.File]::ReadAllText($status) -ne 'reuse:ready') { throw 'Reuse failed' }
    $after = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine.Contains("-Server -Port $port ") }).Count
    if ($before -ne 1 -or $after -ne 1) { throw "Expected one server process, found $before then $after" }

    # 4. A foreign listener is reported by name with a reason in the status file, and left running.
    $foreign = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
    $foreign.Start(); $foreignPort = $foreign.LocalEndpoint.Port
    try {
        $code = Invoke-Launcher 'foreign' $foreignPort
        $text = [IO.File]::ReadAllText($status)
        if ($code -eq 0 -or -not $text.StartsWith("foreign:error:Port $foreignPort is occupied by powershell") -or -not $text.Contains('not a Balatro Observer viewer')) { throw "Foreign listener not reported: $text" }
        $foreign.Pending() | Out-Null   # still listening: nothing was stopped
    } finally { $foreign.Stop() }

    Write-Output 'PASS: hidden startup with Node absent from PATH; outdated viewer replaced, request-specific readiness, reuse without duplicates, foreign listener refused by name.'
} finally {
    $env:PATH = $originalPath
    if ($outdated -and -not $outdated.HasExited) { Stop-Process -Id $outdated.Id -Force }
    # Stop only the server created for this unique test port and fixture.
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" | Where-Object {
        $_.CommandLine -and $_.CommandLine.Contains($fixture) -and $_.CommandLine.Contains("-Server -Port $port ")
    } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
}
