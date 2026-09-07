param(
    [string]$ModsDirectory = (Join-Path $env:APPDATA 'Balatro\Mods')
)
$ErrorActionPreference = 'Stop'
$releaseRoot = $PSScriptRoot
$release = Get-Content -LiteralPath (Join-Path $releaseRoot 'BalatroObserver.json') -Raw | ConvertFrom-Json
$viewer = Get-Content -LiteralPath (Join-Path $releaseRoot 'observer.html') -Raw
if (-not $viewer.Contains('name="observer-version" content="' + $release.version + '"')) {
    throw 'Viewer and manifest versions differ. Update both before installing.'
}
$target = Join-Path ([IO.Path]::GetFullPath($ModsDirectory)) 'BalatroObserver'
if ([IO.Path]::GetFullPath($releaseRoot).TrimEnd('\') -eq $target.TrimEnd('\')) {
    throw 'Run this script from the source project, not the installed mod folder.'
}
$files = @('BalatroObserver.json', 'main.lua', 'observer.lua', 'json.lua',
    'observer.html', 'viewer-server.js', 'README.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md',
    'assets/8BitDeck_opt2.png', 'assets/Enhancers.png', 'assets/Editions.png',
    'assets/Jokers.png', 'assets/LICENSE-balatro-calculator.txt')
$files += @('assets/wiki-art.json', 'assets/wiki-art.js')
$files += @(Get-Content -LiteralPath (Join-Path $releaseRoot 'assets/wiki-art.json') -Raw | ConvertFrom-Json | ForEach-Object { $_.file })
foreach ($name in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $releaseRoot $name) -PathType Leaf)) {
        throw "Missing release file: $name"
    }
}
New-Item -ItemType Directory -Path $target -Force | Out-Null
foreach ($name in $files) {
    $sourceFile = Join-Path $releaseRoot $name
    $targetFile = Join-Path $target $name
    New-Item -ItemType Directory -Path (Split-Path -Parent $targetFile) -Force | Out-Null
    Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
    if ((Get-FileHash -LiteralPath $sourceFile).Hash -ne (Get-FileHash -LiteralPath $targetFile).Hash) {
        throw "Installed file verification failed: $name"
    }
}
Write-Output "Installed Balatro Observer v$($release.version) to $target"
Write-Output "Verified all $($files.Count) release files. Restart Balatro to load the updated mod."

