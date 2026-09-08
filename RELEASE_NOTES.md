# v1.0.1 — Viewer button recovers from an older viewer

- Fixes "Viewer failed - retry" after updating: the viewer server from the previous release kept port 8765, so the in-game button could never start the new one. The Windows launcher now replaces an older Balatro Observer server — recognized by its own command line — and still refuses any other program on the port, naming it instead of stopping it.
- A failed launch explains itself: the reason is shown under the button in the mod settings and written to `viewer-launch.log` in the mod folder. A missing launcher script fails immediately rather than after the 15-second timeout.
- Includes the v1.0.0 reorganization: `mod/`, `viewer/`, `server/`, `scripts/` layout, split dashboard files, unchanged URLs, a pruning installer and a ZIP builder. No change to the exported schema or the information collected.

Extract the `BalatroObserver` folder into `%APPDATA%/Balatro/Mods`, replacing the old one, and restart Balatro. The first click on the button replaces any older viewer automatically.

Validation: Windows launcher suite (outdated viewer replaced, cold start, request-specific readiness, reuse without duplicates, foreign listener refused by name) with Node absent from PATH; 12 Node unit checks (Node 24 via Electron); the installed launcher replaced a real v0.8.0 viewer on port 8765 on the release machine. Not run: the Lua suites and the Playwright browser suites (no runtime available); the launcher Lua was updated with matching test changes.
