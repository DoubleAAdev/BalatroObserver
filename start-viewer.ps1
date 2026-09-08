param(
    [switch]$Server,
    [switch]$NoOpen,
    [string]$Request,
    [string]$StatusFile,
    [string]$StateDirectory = (Join-Path $env:APPDATA 'Balatro\balatro_observer'),
    [ValidateRange(1,65535)][int]$Port = 8765
)
$ErrorActionPreference = 'Stop'
if ($Server) {
    Add-Type -Path (Join-Path $PSScriptRoot 'viewer-server.cs') -ReferencedAssemblies 'System.Web.Extensions'
    [ObserverServer]::Run($PSScriptRoot, [IO.Path]::GetFullPath($StateDirectory), $Port)
    exit
}
function Set-LaunchStatus($Status) {
    if ($Request -and $StatusFile) { [IO.File]::WriteAllText($StatusFile, "${Request}:$Status") }
}
function Get-ViewerStatus {
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
            if ($health.app -eq 'BalatroObserver' -and $health.version -eq $release.version) { return 'ready' }
            return 'occupied'
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
try {
    $release = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'BalatroObserver.json') -Raw | ConvertFrom-Json
    $status = Get-ViewerStatus
    if ($status -eq 'occupied') { throw "Port $Port is occupied by another application or an older viewer. Close that viewer server and retry." }
    if ($status -eq 'stopped') {
        foreach ($argument in @($PSCommandPath, $StateDirectory)) { if ($argument.Contains('"')) { throw 'Invalid launcher path' } }
        $arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Server -Port ' + $Port + ' -StateDirectory "' + $StateDirectory.TrimEnd('\') + '"'
        Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput (Join-Path $PSScriptRoot 'viewer-server.log') -RedirectStandardError (Join-Path $PSScriptRoot 'viewer-server-error.log') | Out-Null
        $deadline = [DateTime]::UtcNow.AddSeconds(10)
        do {
            Start-Sleep -Milliseconds 100
            $status = Get-ViewerStatus
        } while ($status -eq 'stopped' -and [DateTime]::UtcNow -lt $deadline)
        if ($status -ne 'ready') { throw 'Viewer startup failed. See viewer-server-error.log in the mod folder.' }
    }
    Set-LaunchStatus 'ready'
    if (-not $NoOpen) { Start-Process "http://127.0.0.1:$Port" }
} catch {
    Set-LaunchStatus 'error'
    Write-Error $_
    exit 1
}

