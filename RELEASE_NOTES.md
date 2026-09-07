# v0.2.2 — Raw JSON and live local viewer

Balatro Observer is a read-only Steamodded mod for viewing player-visible game data in two ways: raw JSON snapshot files and a live local HTML dashboard.

## Included in this release

- Raw state snapshots written every 200 ms to alternating state-0.json and state-1.json files.
- A local dashboard with Overview, Current hand, Deck, Jokers & items, Shop, Open pack, Poker hands, and Raw data sections.
- Automatic updates, pause/resume, hidden-card redaction, and clear unavailable/stale-data states.
- Viewer and running-mod version indicators to help identify an outdated loaded mod.
- Card displays without buy/sell labels.
- A clearer README and mod description explaining both data access options.
- Code comments explaining snapshot selection, local serving, loaded-version reporting, and stable live rendering.

This is the first packaged GitHub release; it includes the viewer and versioning work from v0.2.0 and v0.2.1. Version 0.2.2 adds documentation and explanatory comments without changing the observation schema.

## Install

1. Install Lovely and Steamodded.
2. Download BalatroObserver-v0.2.2.zip and extract it into your Balatro Mods directory. The archive contains a BalatroObserver folder. On Windows, the manifest should end up at %APPDATA%/Balatro/Mods/BalatroObserver/BalatroObserver.json.
3. Restart Balatro.

## View your data

**Raw files:** open state-0.json and state-1.json in %APPDATA%/Balatro/balatro_observer. Each is a snapshot; consumers must select the newest valid one.

**Local HTML dashboard:** install Node.js 18 or newer, open a terminal in the installed BalatroObserver folder, run:

```sh
node viewer-server.js
```

Then open http://127.0.0.1:8765. The server stays on your machine and reads the existing snapshot files. A custom save directory can be passed as the first command-line argument.

If upgrading, refresh the page and restart Balatro to load v0.2.2. Restart the viewer server if it is already running.

## Validation and limits

The automated Lua observer tests and Node viewer tests passed. Browser smoke checks passed for all eight sections, pause/navigation, mobile width, hidden cards, and stale-state hiding using controlled snapshot data.

The export is limited to player-visible information. It does not include hidden card identities, draw order, seeds, RNG state, or future shops. Full deck composition is not an ordered draw pile. Real-game HUD comparison remains a manual check.

