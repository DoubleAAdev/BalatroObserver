param([switch]$Server,[switch]$NoOpen,[string]$Request,[string]$StatusFile,[string]$StateDirectory=(Join-Path $env:APPDATA 'Balatro/balatro_action_recorder'),[ValidateRange(1,65535)][int]$Port=8766,[ValidateRange(0,2147483647)][int]$GamePid=0)
$ErrorActionPreference='Stop'
$recorderRoot=Split-Path -Parent $PSScriptRoot
if ($Server) {
    Add-Type -Path (Join-Path $PSScriptRoot 'recorder-server.cs') -ReferencedAssemblies 'System.Web','System.Web.Extensions'
    [ActionRecorderServer]::Run($recorderRoot,[IO.Path]::GetFullPath($StateDirectory),$Port,$GamePid)
    exit
}
function Get-RecorderStatus {
    $probe=New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback,$Port)
    $probe.ExclusiveAddressUse=$true
    try {$probe.Start();return 'stopped'} catch {} finally {$probe.Stop()}
    try {
        $health=Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 2
        if ($health.app -eq 'BalatroActionRecorder') {
            if ($health.version -eq '0.4.1' -and (-not $GamePid -or $health.gamePid -eq $GamePid)) {return 'ready'}
            return 'outdated'
        }
    } catch {}
    return 'occupied'
}
try {
    if (-not $GamePid) { $GamePid = (Get-Process -Name Balatro -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Id) }
    $status=Get-RecorderStatus
    if ($status -eq 'outdated') {
        $owners=@(Get-NetTCPConnection -LocalPort $Port -State Listen | Select-Object -ExpandProperty OwningProcess -Unique)
        foreach ($ownerId in $owners) {
            $owner=Get-CimInstance Win32_Process -Filter "ProcessId=$ownerId"
            if ($owner.CommandLine -notmatch 'start-recorder\.ps1.*-Server') { throw 'Unrecognized recorder process; close it and retry.' }
        }
        foreach ($ownerId in $owners) { Stop-Process -Id $ownerId }
        $deadline=[DateTime]::UtcNow.AddSeconds(5)
        do {Start-Sleep -Milliseconds 100;$status=Get-RecorderStatus} while ($status -ne 'stopped' -and [DateTime]::UtcNow -lt $deadline)
        if ($status -ne 'stopped') {throw 'Previous recorder did not stop.'}
    }
    if ($status -eq 'occupied') {throw "Port $Port is in use by another application or recorder version."}
    if ($status -eq 'stopped') {
        foreach ($argument in @($PSCommandPath,$StateDirectory)) {if ($argument.Contains('"')) {throw 'Invalid launcher path'}}
        $arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Server -Port '+$Port+' -StateDirectory "'+$StateDirectory.TrimEnd('\')+'"'
        $arguments+=' -GamePid '+$GamePid
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
