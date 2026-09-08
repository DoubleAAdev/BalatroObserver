# v1.0.0 — Organized layout

- The mod folder is sorted by role — `mod/`, `viewer/`, `server/`, `assets/`, `scripts/`, `tests/` — with only the Steamodded manifest, `main.lua` and `start-viewer.cmd` at the root. The dashboard is split into HTML, CSS, JS and a sprite table. Every server URL is unchanged, so bookmarks and external tools keep working.
- The Node launcher now reuses a running viewer only when its version matches, exactly like the Windows launcher; both servers report their runtime in `/health`.
- The installer (`scripts/sync-mod.ps1`) removes files from the installed folder that are not part of the release, so the previous flat layout cannot linger beside the new one. A new `scripts/build-release.ps1` packages the ZIP from the same manifest.
- README rewritten as a user and developer guide; release history lives in `CHANGELOG.md`.
- No change to the exported schema, the visibility boundary, or the information collected. `mod_version` still identifies the version loaded in Balatro.

Extract the `BalatroObserver` folder into `%APPDATA%/Balatro/Mods`, replacing the old one, and restart Balatro. Close any viewer server from an earlier release before opening the new dashboard; the launcher reports an occupied port rather than stopping another process.

Validation: Node unit checks (server, launcher, score engine) run on Node 24; hidden Windows/.NET cold startup, readiness reporting and every public route verified against the restructured layout; the dashboard rendered from the .NET server in Chromium with no console errors across all sections. Not run in this release: the Lua collector/launcher suites and the Playwright browser suites, because no Lua runtime or Playwright installation was available on the release machine — the Lua changes are limited to module paths, and the browser suites' route lists were updated. Live in-game verification after restart remains to be confirmed.
