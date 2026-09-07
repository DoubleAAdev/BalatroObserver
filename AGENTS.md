# Project update workflow

The user requires this workflow after every completed mod or viewer update:

1. Increment the release version in BalatroObserver.json (at least a patch bump; use a minor bump for new features).
2. Keep observer.html's observer-version meta tag, page title, and visible viewer version aligned with that release. Keep version-related tests aligned.
3. Preserve mod_version in exported snapshots and the viewer's running-mod version indicator. Distinguish installed files from the version actually loaded in Balatro.
4. Run relevant checks, then run ./sync-mod.ps1 to copy and hash-verify the latest release into %APPDATA%/Balatro/Mods/BalatroObserver. The user has explicitly authorized this ongoing installation workflow; do not ask again for routine synchronization. Leave other mods and unrelated files alone.
5. Report the new version and installation result. If the running game has not loaded it, say that Balatro needs restarting; do not close the game automatically.


6. Before each release commit, update .gitignore for generated snapshots, caches, downloaded runtimes, logs, and other redundant local artifacts. Keep source code, documentation, and useful tests tracked.
7. After validation and installation, commit the completed version update and its related changes locally. The user explicitly requests this for every version/subversion update. Do not push unless asked.

8. Before every code update, read missing.txt if present and compare each player-visible checklist item against both the exported state and browser. Implement missing coverage as part of the update, add relevant checks, and report any remaining limitations. Keep missing.txt local and ignored; do not delete or overwrite the user’s checklist. Do not infer hidden information from this list.

9. The command "update missing" means: read the current local missing.txt, implement its missing player-visible website/collector features, update versions and ignore generated artifacts, test, sync and hash-verify the installed mod, commit with an explanation, push to the configured GitHub remote, and publish a versioned release with explanatory notes and an installable ZIP. This command explicitly authorizes pushing and publishing for that update. Preserve the checklist itself.
