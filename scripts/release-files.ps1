# Shared release manifest: every file that ships inside the installable BalatroObserver folder.
# Dot-source this file; scripts/sync-mod.ps1 and scripts/build-release.ps1 both use Get-ReleaseFiles.
# Development files (scripts/, tests/, AGENTS.md, dist/, .test-runtime/) are deliberately absent.
function Get-ReleaseFiles([string]$Root) {
    $files = @(
        # Root: Steamodded manifest, mod entry point, double-click viewer shortcut, documents
        'BalatroObserver.json', 'main.lua', 'start-viewer.cmd',
        'replayer/init.lua', 'replayer/log.lua', 'replayer/driver.lua', 'replayer/session.lua', 'replayer/file-picker.lua', 'replayer/README.md',
        'LICENSE', 'README.md', 'CHANGELOG.md', 'THIRD_PARTY_NOTICES.md',
        # In-game collector and settings launcher
        'mod/observer.lua', 'mod/multiplayer.lua', 'mod/json.lua', 'mod/launcher.lua', 'mod/open-viewer.lua',
        # Dashboard
        'viewer/observer.html', 'viewer/observer.css', 'viewer/observer.js', 'viewer/joker-sprites.js', 'viewer/score-preview.js',
        # Local servers: Windows PowerShell/.NET and optional Node.js
        'server/start-viewer.ps1', 'server/viewer-server.cs', 'server/start-viewer.js', 'server/viewer-server.js',
        # Sprite atlases, calculator engine and credits
        'assets/8BitDeck_opt2.png', 'assets/Enhancers.png', 'assets/Editions.png', 'assets/Jokers.png',
        'assets/LICENSE-balatro-calculator.txt', 'assets/wiki-art.json', 'assets/wiki-art.js',
        'assets/calculator/balatro-sim.js', 'assets/calculator/joker-ids.json', 'assets/calculator/joker-ids.js'
    )
    $files += @('action-recorder/init.lua', 'action-recorder/start-recorder.cmd', 'action-recorder/README.md', 'action-recorder/LICENSE')
    foreach ($folder in @('mod', 'server', 'viewer')) {
        $files += @(Get-ChildItem -LiteralPath (Join-Path $Root ('action-recorder/' + $folder)) -File | ForEach-Object { 'action-recorder/' + $folder + '/' + $_.Name })
    }
    # Every bundled wiki image listed in the artwork index ships unchanged.
    $files += @(Get-Content -LiteralPath (Join-Path $Root 'assets/wiki-art.json') -Raw | ConvertFrom-Json | ForEach-Object { $_.file })
    foreach ($name in $files) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $name) -PathType Leaf)) { throw "Missing release file: $name" }
    }
    return $files
}

# The viewer page must report the same version as the manifest before anything is installed or packaged.
function Assert-ViewerVersion([string]$Root, [string]$Version) {
    $viewer = Get-Content -LiteralPath (Join-Path $Root 'viewer/observer.html') -Raw
    if (-not $viewer.Contains('name="observer-version" content="' + $Version + '"')) {
        throw 'Viewer and manifest versions differ. Update both before installing or packaging.'
    }
}

# Copies one release file and confirms the copy by SHA-256.
function Copy-ReleaseFile([string]$Root, [string]$Target, [string]$Name) {
    $sourceFile = Join-Path $Root $Name
    $targetFile = Join-Path $Target $Name
    New-Item -ItemType Directory -Path (Split-Path -Parent $targetFile) -Force | Out-Null
    Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
    if ((Get-FileHash -LiteralPath $sourceFile).Hash -ne (Get-FileHash -LiteralPath $targetFile).Hash) {
        throw "File verification failed: $Name"
    }
}
