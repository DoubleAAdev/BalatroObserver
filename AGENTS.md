# Project update workflow

The user requires this workflow after every completed mod or viewer update:

1. Increment the release version in BalatroObserver.json (at least a patch bump; use a minor bump for new features).
2. Keep viewer/observer.html's observer-version meta tag, page title, and visible viewer version aligned with that release. Keep version-related tests aligned.
3. Preserve mod_version in exported snapshots and the viewer's running-mod version indicator. Distinguish installed files from the version actually loaded in Balatro.
4. Run relevant checks (the Lua suites run without a Lua install via python scripts/run-lua-tests.py; any change to mod/ must pass them before installing), then run ./scripts/sync-mod.ps1 to copy, hash-verify and prune the latest release into %APPDATA%/Balatro/Mods/BalatroObserver. The user has explicitly authorized this ongoing installation workflow; do not ask again for routine synchronization. Leave other mods and unrelated files alone.
5. Report the new version and installation result. If the running game has not loaded it, say that Balatro needs restarting; do not close the game automatically.


6. Before each release commit, update .gitignore for generated snapshots, caches, downloaded runtimes, logs, and other redundant local artifacts. Keep source code, documentation, and useful tests tracked.
7. After validation and installation, commit the completed version update and its related changes with an explanatory message, then push to the configured GitHub remote. The user explicitly requires GitHub synchronization for every completed version/subversion update; a local-only commit does not complete the workflow. Verify the remote branch matches the local commit. Do not ask again for routine pushes, and never force-push to bypass remote changes.

8. Before every code update, read missing.txt if present and compare each player-visible checklist item against both the exported state and browser. Implement missing coverage as part of the update, add relevant checks, and report any remaining limitations. Keep missing.txt local and ignored; do not delete or overwrite the user’s checklist. Do not infer hidden information from this list.

9. The command "update missing" means: read the current local missing.txt, implement its missing player-visible website/collector features, update versions and ignore generated artifacts, test, sync and hash-verify the installed mod, commit with an explanation, push to the configured GitHub remote, and publish a versioned release with explanatory notes and an installable ZIP built by ./scripts/build-release.ps1. This command explicitly authorizes pushing and publishing for that update. Preserve the checklist itself.

10. Viewer releases must include assets/ and THIRD_PARTY_NOTICES.md; scripts/release-files.ps1 is the single list of shipped files and must be updated whenever a release file is added, moved or renamed. Preserve the Balatro Calculator credit and bundled MIT notice when modifying or distributing the reused sprite assets and rendering adaptations. Verify static asset routes and install hashes.
