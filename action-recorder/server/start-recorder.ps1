param([switch]$Server,[switch]$NoOpen,[string]$Request,[string]$StatusFile,[string]$StateDirectory=(Join-Path $env:APPDATA 'Balatro/balatro_action_recorder'),[ValidateRange(1,65535)][int]$Port=8766)
$ErrorActionPreference='Stop'
$recorderRoot=Split-Path -Parent $PSScriptRoot
if ($Server) {
    Add-Type -Path (Join-Path $PSScriptRoot 'recorder-server.cs') -ReferencedAssemblies 'System.Web','System.Web.Extensions'
    [ActionRecorderServer]::Run($recorderRoot,[IO.Path]::GetFullPath($StateDirectory),$Port)
    exit
}
function Get-RecorderStatus {
    $probe=New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback,$Port)
    $probe.ExclusiveAddressUse=$true
    try {$probe.Start();return 'stopped'} catch {} finally {$probe.Stop()}
    try {
        $health=Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2
        if ($health.app -eq 'BalatroActionRecorder' -and $health.version -eq '0.1.0') {return 'ready'}
    } catch {}
    return 'occupied'
}
try {
    $status=Get-RecorderStatus
    if ($status -eq 'occupied') {throw "Port $Port is in use by another application or recorder version."}
    if ($status -eq 'stopped') {
        foreach ($argument in @($PSCommandPath,$StateDirectory)) {if ($argument.Contains('"')) {throw 'Invalid launcher path'}}
        $arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Server -Port '+$Port+' -StateDirectory "'+$StateDirectory.TrimEnd('\')+'"'
        Start-Process -FilePath "$env:SystemRoot/System32/WindowsPowerShell/v1.0/powershell.exe" -ArgumentList $arguments -WindowStyle Hidden -RedirectStandardOutput (Join-Path $recorderRoot 'recorder-server.log') -RedirectStandardError (Join-Path $recorderRoot 'recorder-server-error.log') | Out-Null
        $deadline=[DateTime]::UtcNow.AddSeconds(10)
        do {Start-Sleep -Milliseconds 100;$status=Get-RecorderStatus} while ($status -eq 'stopped' -and [DateTime]::UtcNow -lt $deadline)
        if ($status -ne 'ready') {throw 'Recorder export server did not start. See recorder-server-error.log.'}
    }
    if ($Request -and $StatusFile) {[IO.File]::WriteAllText($StatusFile,"${Request}:ready")}
    if (-not $NoOpen) {Start-Process "http://127.0.0.1:$Port"}
} catch {
    if ($Request -and $StatusFile) {[IO.File]::WriteAllText($StatusFile,"${Request}:error:Recorder server failed. See recorder-server-error.log.")}
    try {Add-Content -LiteralPath (Join-Path $recorderRoot 'recorder-launch.log') -Value $_.Exception.Message} catch {}
    Write-Error $_
    exit 1
}
