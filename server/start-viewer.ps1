# Windows launcher: starts the hidden .NET viewer server (or reuses a healthy one) and opens the browser.
# Runs on built-in Windows PowerShell 5.1; no Node.js required. Double-click ..\start-viewer.cmd to use it.
param(
    [switch]$Server,
    [switch]$NoOpen,
    [string]$Request,
    [string]$StatusFile,
    [ValidateRange(0,2147483647)][int]$GamePid = 0,
    [string]$StateDirectory = (Join-Path $env:APPDATA 'Balatro\balatro_observer'),
    [ValidateRange(1,65535)][int]$Port = 8765
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot   # the mod folder: manifest, viewer/, assets/, logs

if ($Server) {
    Add-Type -Path (Join-Path $PSScriptRoot 'viewer-server.cs') -ReferencedAssemblies 'System.Web.Extensions'
    [ObserverServer]::Run($root, [IO.Path]::GetFullPath($StateDirectory), $Port, $GamePid)
    exit
}

# The in-game button polls this file: "<request>:ready" or "<request>:error:<reason>".
function Set-LaunchStatus([string]$Status, [string]$Reason) {
    if (-not ($Request -and $StatusFile)) { return }
    $line = "${Request}:$Status"
    if ($Reason) { $line += ':' + ($Reason -replace '[\r\n]+', ' ') }
    [IO.File]::WriteAllText($StatusFile, $line)
}
function Write-LaunchLog([string]$Message) {
    try { Add-Content -LiteralPath (Join-Path $root 'viewer-launch.log') -Value ('{0:s} {1}' -f (Get-Date), $Message) } catch { }
}

# Processes listening on the port, for diagnostics and for recognizing an older viewer of ours.
# Callers wrap the result in @(): a lone CimInstance has no usable .Count of its own.
function Get-PortOwners {
    $ids = @()
    try { $ids = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique) } catch { }
    if (-not $ids.Count) {
        # Fallback when the NetTCPIP cmdlets are unavailable: netstat always ships in System32.
        try {
            $ids = @(& "$env:SystemRoot\System32\netstat.exe" -ano -p tcp | ForEach-Object {
                if ($_ -match '^\s*TCP\s+\S+:(\d+)\s+\S+\s+LISTENING\s+(\d+)\s*$' -and [int]$Matches[1] -eq $Port) { [int]$Matches[2] }
            } | Select-Object -Unique)
        } catch { }
    }
    foreach ($id in $ids) { try { Get-CimInstance Win32_Process -Filter "ProcessId = $id" } catch { } }
}
function Describe-PortOwners($Owners) {
    $list = @($Owners)
    if (-not $list.Count) { return 'another application' }
    ($list | ForEach-Object { "$($_.Name) (PID $($_.ProcessId))" }) -join ', '
}

function Get-ViewerStatus([string]$ExpectedVersion) {
    # Windows can time out instead of refusing a connection to an unused port.
    # An exclusive loopback bind distinguishes a free port without assuming timeouts mean free.
    $availability = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $Port)
    $availability.ExclusiveAddressUse = $true
    try { $availability.Start(); return 'stopped' } catch { } finally { $availability.Stop() }
    try {
        $probe = [Net.HttpWebRequest]::Create("http://127.0.0.1:$Port/health")
        $probe.Proxy = $null; $probe.Timeout = 2000
        $response = $probe.GetResponse()
        try {
            $reader = New-Object IO.StreamReader($response.GetResponseStream())
            $health = $reader.ReadToEnd() | ConvertFrom-Json
            if ($health.app -ne 'BalatroObserver') { return 'occupied' }
            # Only a viewer of this exact release is reused; an older one is replaced below.
            if ($health.version -eq $ExpectedVersion -and (-not $GamePid -or $health.gamePid -eq $GamePid)) { return 'ready' }
            return 'outdated'
        } finally { $response.Close() }
    } catch {
        $failure = $_.Exception
        while ($failure) {
            if ($failure -is [Net.Sockets.SocketException] -and $failure.SocketErrorCode -eq [Net.Sockets.SocketError]::ConnectionRefused) { return 'stopped' }
            $failure = $failure.InnerException
        }
        return 'occupied'
    }
}

# An older Balatro Observer server left running after an update is ours to replace: it is recognized by
# its command line (this script in -Server mode, or the optional Node server). Anything else is never stopped.
function Stop-OutdatedViewer([string]$ExpectedVersion) {
    $owners = @(Get-PortOwners)
    if (-not $owners.Count) { throw "Port $Port is occupied by an older viewer whose process could not be identified. Close it and retry." }
    foreach ($owner in $owners) {
        $command = [string]$owner.CommandLine
        if ($command -notmatch 'start-viewer\.ps1.*-Server' -and $command -notmatch 'viewer-server\.js') {
            throw "Port $Port is occupied by $(Describe-PortOwners @($owner)), which is not a Balatro Observer viewer. Close it and retry."
        }
        Write-LaunchLog "Replacing older viewer $(Describe-PortOwners @($owner)): $command"
        Stop-Process -Id $owner.ProcessId -Force
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(5)
    do { Start-Sleep -Milliseconds 100; $status = Get-ViewerStatus $ExpectedVersion } while ($status -ne 'stopped' -and [DateTime]::UtcNow -lt $deadline)
    if ($status -ne 'stopped') { throw "Port $Port is still in use after stopping the older viewer. Retry in a moment." }
}

try {
    if (-not $GamePid) { $GamePid = (Get-Process -Name Balatro -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Id) }
    $release = Get-Content -LiteralPath (Join-Path $root 'BalatroObserver.json') -Raw | ConvertFrom-Json
    $status = Get-ViewerStatus $release.version
    if ($status -eq 'occupied') { throw "Port $Port is occupied by $(Describe-PortOwners (Get-PortOwners)), which is not a Balatro Observer viewer. Close it and retry." }
    if ($status -eq 'outdated') { Stop-OutdatedViewer $release.version; $status = 'stopped' }
    if ($status -eq 'stopped') {
        foreach ($argument in @($PSCommandPath, $StateDirectory)) { if ($argument.Contains('"')) { throw 'Invalid launcher path' } }
        $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Server -Port ' + $Port + ' -StateDirectory "' + $StateDirectory.TrimEnd('\') + '"'
        $arguments += ' -GamePid ' + $GamePid
        Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -WindowStyle Hidden `
            -RedirectStandardOutput (Join-Path $root 'viewer-server.log') -RedirectStandardError (Join-Path $root 'viewer-server-error.log') | Out-Null
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        do {
            Start-Sleep -Milliseconds 100
            $status = Get-ViewerStatus $release.version
        } while ($status -eq 'stopped' -and [DateTime]::UtcNow -lt $deadline)
        if ($status -ne 'ready') { throw 'Viewer startup failed. See viewer-server-error.log in the mod folder.' }
        Write-LaunchLog "Started viewer v$($release.version) on port $Port"
    }
    Set-LaunchStatus 'ready'
    if (-not $NoOpen) { Start-Process "http://127.0.0.1:$Port" }
} catch {
    $reason = $_.Exception.Message
    Set-LaunchStatus 'error' $reason
    Write-LaunchLog "Launch failed: $reason"
    Write-Error $_
    exit 1
}
