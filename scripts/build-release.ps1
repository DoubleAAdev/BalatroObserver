# Stages dist/v<version>/BalatroObserver/ from the release manifest and packages it as
# dist/BalatroObserver-v<version>.zip, whose single top-level folder extracts straight into Mods/.
param(
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'release-files.ps1')
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$release = Get-Content -LiteralPath (Join-Path $root 'BalatroObserver.json') -Raw | ConvertFrom-Json
Assert-ViewerVersion $root $release.version
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root 'dist' }
$files = Get-ReleaseFiles $root

$stage = Join-Path $OutputDirectory ('v' + $release.version + '\BalatroObserver')
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
foreach ($name in $files) { Copy-ReleaseFile $root $stage $name }

$zip = Join-Path $OutputDirectory ('BalatroObserver-v' + $release.version + '.zip')
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
# Entry names are written explicitly with forward slashes: .NET Framework's CreateFromDirectory emits
# backslashes, which Linux/macOS extractors keep as part of the file name. ZipArchive stores non-ASCII
# names such as Séance.png as UTF-8, unlike Windows PowerShell's Compress-Archive.
$archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($name in $files) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $stage $name), 'BalatroObserver/' + $name, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally { $archive.Dispose() }

# Confirm the archive holds exactly the release, all under BalatroObserver/.
$archive = [IO.Compression.ZipFile]::OpenRead($zip)
try {
    $entries = @($archive.Entries | Where-Object { $_.Name })
    $expected = @{}
    foreach ($name in $files) { $expected['BalatroObserver/' + $name] = $true }
    foreach ($entry in $entries) {
        if (-not $expected.ContainsKey($entry.FullName)) { throw "Unexpected archive entry: $($entry.FullName)" }
    }
    if ($entries.Count -ne $files.Count) { throw "Archive holds $($entries.Count) files; expected $($files.Count)" }
} finally { $archive.Dispose() }

Write-Output "Staged $($files.Count) release files in $stage"
Write-Output "Packaged $zip ($([Math]::Round((Get-Item -LiteralPath $zip).Length / 1MB, 2)) MB)"
