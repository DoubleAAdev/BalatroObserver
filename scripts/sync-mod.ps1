# Installs the current release into the Balatro Mods folder and verifies every file by SHA-256.
# Files inside the installed BalatroObserver folder that are not part of the release are removed,
# so an older flat layout or a stray copy of the source tree cannot linger next to the new files.
# Other mods and everything outside that folder are never touched.
param(
    [string]$ModsDirectory = (Join-Path $env:APPDATA 'Balatro\Mods')
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'release-files.ps1')

$release = Get-Content -LiteralPath (Join-Path $root 'BalatroObserver.json') -Raw | ConvertFrom-Json
Assert-ViewerVersion $root $release.version
$target = Join-Path ([IO.Path]::GetFullPath($ModsDirectory)) 'BalatroObserver'
if ([IO.Path]::GetFullPath($root).TrimEnd('\') -eq $target.TrimEnd('\')) {
    throw 'Run this script from the source project, not the installed mod folder.'
}
$files = Get-ReleaseFiles $root

New-Item -ItemType Directory -Path $target -Force | Out-Null
foreach ($name in $files) { Copy-ReleaseFile $root $target $name }

# Prune: anything under the install folder that the release does not contain.
$expected = @{}
foreach ($name in $files) { $expected[[IO.Path]::GetFullPath((Join-Path $target $name))] = $true }
$removed = @(); $kept = @()
foreach ($file in Get-ChildItem -LiteralPath $target -Recurse -File -Force) {
    if ($expected.ContainsKey([IO.Path]::GetFullPath($file.FullName))) { continue }
    try { Remove-Item -LiteralPath $file.FullName -Force; $removed += $file.FullName.Substring($target.Length + 1) }
    catch { $kept += $file.FullName.Substring($target.Length + 1) }   # e.g. a log held open by a running viewer
}
foreach ($directory in Get-ChildItem -LiteralPath $target -Recurse -Directory -Force | Sort-Object { $_.FullName.Length } -Descending) {
    if (-not (Get-ChildItem -LiteralPath $directory.FullName -Force | Select-Object -First 1)) { Remove-Item -LiteralPath $directory.FullName -Force }
}

Write-Output "Installed Balatro Observer v$($release.version) to $target"
Write-Output "Verified all $($files.Count) release files by SHA-256."
if ($removed.Count) { Write-Output "Removed $($removed.Count) file(s) that are not part of the release." }
if ($kept.Count) { Write-Warning ("Could not remove (in use?): " + ($kept -join ', ')) }
Write-Output 'Restart Balatro to load the updated mod.'
