# Balatro Observer

View player-visible Balatro game data through **raw JSON snapshot files** or a **live local HTML dashboard**. This read-only Steamodded mod exports the current state every 200 ms and never changes the game.

| View | How to open it | What it provides |
| --- | --- | --- |
| Raw JSON files | Open `state-0.json` / `state-1.json` in `%APPDATA%/Balatro/balatro_observer` | Structured snapshots for inspection and external tools |
| Local HTML dashboard | Mods → Balatro Observer → configuration, or double-click `start-viewer.cmd` | Live sections for the run, current deck and blind, hand, deck composition, jokers, shop, packs, poker hands and a score preview |

On Windows the dashboard runs on the built-in Windows PowerShell 5.1 and .NET Framework — no Node.js required. On other platforms an optional Node.js 18+ server is included. Both views show the same exported information; the dashboard also has a Raw data section.

## Install the mod

1. Install **Lovely and Steamodded** first, following the [Steamodded installation guide](https://docs.smods.dev/Installation/). Lovely alone does not load this mod. Confirm that Balatro's main menu shows a **Mods** button.
2. Download `BalatroObserver-v<version>.zip` from [GitHub Releases](https://github.com/DoubleAAdev/BalatroObserver/releases/latest) and extract its `BalatroObserver` folder into `%APPDATA%/Balatro/Mods/`. A source checkout works the same way. Keep the folder layout intact: `BalatroObserver.json` and `main.lua` must stay directly inside `BalatroObserver`.
3. Restart Balatro. The mod appears in the Mods menu; if it is missing or disabled, check the folder layout and the dependency status shown there.

No file in the game installation is modified. The Steamodded folder must sit alongside `BalatroObserver` inside `Mods`.

## Open the dashboard

**Windows.** Use Mods → Balatro Observer → configuration, or double-click `start-viewer.cmd` in the mod folder. The launcher starts a hidden localhost server (or reuses a running one of the same version), waits until it responds, and opens `http://127.0.0.1:8765` in your browser. No administrator rights or firewall changes are needed; the server binds only to 127.0.0.1. For a custom snapshot directory or port run

```bash
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\server\start-viewer.ps1 -StateDirectory "D:\path\to\balatro_observer" -Port 8765
```

A viewer left running from an earlier release is replaced automatically (it is recognized by its own command line); any other program on the port is reported by name and never stopped. The reason for a failed launch appears under the in-game button and in `viewer-launch.log` in the mod folder; server output goes to `viewer-server.log` / `viewer-server-error.log`. Environments that block PowerShell scripts or runtime C# compilation need those allowed, or can use the Node server below.

**Other platforms.** With Node.js 18+ installed, run `node server/start-viewer.js` (starts the server and opens the browser) or `node server/viewer-server.js [stateDirectory]` and open `http://127.0.0.1:8765`. The in-game button then simply opens that address.

The dashboard keeps the last available preview during animations, stale exports or a lost connection and labels it; a new game session clears the previous preview. Raw data always shows the newest received record, including unavailable ones. The viewer version and the `mod_version` loaded in Balatro are shown side by side; a mismatch means Balatro needs a restart after an update.

## Snapshot files

Every 200 ms after a game update, the mod writes alternating `state-0.json` and `state-1.json` under `balatro_observer` in LÖVE's save directory (`love.filesystem.getSaveDirectory()`, normally `%APPDATA%/Balatro` on Windows). The files are snapshots, not a recording of every action.

Consumers should parse both files independently, ignore malformed or incomplete files, and choose the newest `observed_at`, then the greatest `sequence` within its `session`. Reset per-episode state on a session change. Reject stale records and records with `available: false`; never fall back to an older playable observation when a newer unavailable record exists. A failed write preserves the other slot. Polling can miss fast transitions; this is not an action/reward training pipeline.

For in-process use, `BalatroObserver.snapshot()` returns a detached Lua table and `BalatroObserver.last_export_ok` reports the latest export's success. Errors are contained so the observer cannot stop the update loop; error details are deliberately not exported.

### Schema version 1

- `phase`, `available` — only recognized completed run phases are sampled. Animations, overlays, pauses, menus and unknown phases produce an unavailable record. Availability is a sampling guard, not a guarantee that an action is legal.
- `run`, `round`, `blind` — money, score, stake, round, ante, remaining hands/discards and the current blind, including its boss effect text. `run.deck` carries the current deck's key, localized name and effect text, filled with the same public definition values Run Info shows (`run.deck_key` remains for compatibility).
- `hand`, `jokers`, `consumables` — ordered area cards with capacity, slot, selection, visible identity, edition, seal, costs, supported stickers and, for face-up playing cards, the public chip bonus. Jokers carry their localized description and the reviewed public tooltip values (`score_vars`). Face-down cards contain only `visible: false` and their slot.
- `deck` — full deck composition in canonical order plus draw-pile and discard-pile counts. `remaining_cards` is the public unplayed composition, including cards kept ambiguous by face-down effects; it can exceed `draw_count`. Neither list contains draw order, IDs, area membership or links to hidden hand slots. Stone Cards omit their underlying rank and suit.
- `poker_hands` — visible hand types with level, chips, multiplier and play counts.
- `blinds` — current-ante Small/Big/Boss definitions, statuses, next and boss identities and skip-tag identities. Multipliers and rewards are definition values, not final modified targets.
- `vouchers` — redeemed vouchers in Run Info order, including starting vouchers.
- `shop` — present only during SHOP: card, voucher and booster areas plus reroll cost. Booster contents are not inspected.
- `pack` — present only while a pack is open (including Steamodded's `SMODS_BOOSTER_OPENED`): visible choices and remaining picks.
- `scoring_context` — public counters the score preview needs (currently Loyalty Card progress).
- `session`, `sequence`, `observed_at`, `mod_version` — export metadata, unrelated to game RNG.

Unknown scalar values are omitted; arrays stay arrays even when empty. Scores held in another mod's big-number objects are omitted rather than traversed or rounded. Treat missing fields as unknown, not zero.

## Visibility boundary

No seed, RNG state, future shops, unopened pack contents, draw order, internal card IDs, arbitrary `ability.extra`, callbacks, game actions or private opponent state are exported. Multiplayer exposes only the explicitly reviewed visible HUD fields described below. The collector reads explicit allowlists only; it never calls scoring, random, tooltip or action functions and never modifies game objects. Deck composition follows the full deck viewer in [Steamodded's source](https://github.com/Steamodded/smods/blob/main/src/overrides.lua).

Joker descriptions come from the loaded localization text with explicit adapters for vanilla dynamic values. Unsupported placeholders display `?` instead of guessed values. Custom tooltip callbacks, custom editions or enhancements, dynamic tag effects and additional multiplayer HUD data need their own visibility-reviewed adapters before they can appear.

The **Selected hand score** panel uses the locally bundled [Balatro Calculator](https://efhiii.github.io/balatro-calculator/) engine with the actual selection and joker order, held cards, public counters, hand levels, editions, seals and supported bonuses. Random effects show a range; unsupported or hidden inputs show an explanation instead of a guess. It does not simulate custom-mod callbacks.

## Project layout

```
BalatroObserver.json   Steamodded manifest (must stay at the root)
main.lua               mod entry point: loads mod/ and runs the 200 ms export loop
start-viewer.cmd       double-click shortcut for the Windows dashboard
mod/                   in-game code: collector (observer.lua), JSON encoder, settings button, launcher
viewer/                the dashboard: observer.html/.css/.js, joker sprite table, score-preview adapter
server/                localhost servers: start-viewer.ps1 + viewer-server.cs (Windows), start-viewer.js + viewer-server.js (Node)
assets/                sprite atlases, wiki artwork, calculator engine and their licenses
scripts/               release-files.ps1 (shared manifest), sync-mod.ps1 (install), build-release.ps1 (ZIP)
tests/                 Lua, Node and browser checks
```

The two servers expose identical read-only routes: `/`, `/observer.html`, `/observer.css`, `/observer.js`, `/joker-sprites.js`, `/score-preview.js`, `/health`, `/state`, `/credits` and the bundled assets. URLs never change between releases; only the disk layout may.

## Development

Install the working copy into Balatro and verify every file by SHA-256 (files not part of the release are removed from the installed folder):

```bash
powershell -ExecutionPolicy Bypass -File scripts/sync-mod.ps1
```

Stage and package a release ZIP into `dist/`:

```bash
powershell -ExecutionPolicy Bypass -File scripts/build-release.ps1
```

Checks, from the repository root:

| Suite | Command | Needs |
| --- | --- | --- |
| Collector, JSON, export hook, launcher, Multiplayer | `lua tests/test_observer.lua` and `lua tests/test_launcher.lua`, or `python scripts/run-lua-tests.py` (also runs Multiplayer privacy checks) (uses the game's own `lua51.dll`; set `BALATRO_LUA_DLL` for a non-default Steam library) | Lua 5.1+/LuaJIT, or Python 3 plus an installed Balatro |
| Node server, launcher, score engine | `node --test tests/test_viewer.cjs tests/test_start_viewer.cjs tests/test_score.cjs` | Node.js 18+ |
| Windows launcher: outdated viewer replaced, cold start, reuse, foreign listener refused | `powershell -ExecutionPolicy Bypass -File tests/test_windows_startup.ps1` | Windows PowerShell 5.1 |
| Browser rendering | `node tests/test_viewer_browser.cjs`, `test_card_art.cjs`, `test_wiki_shop.cjs`, `test_score_browser.cjs`, `test_windows_viewer.cjs`, `test_multiplayer_browser.cjs` | Playwright + Chromium (`PLAYWRIGHT_MODULE`, `BROWSER_EXECUTABLE` may point at existing installs) |

Live smoke test after installing: start a run, compare a snapshot with the HUD and the full deck viewer, select a card, discard and play, enter and leave the shop, open a pack and face a boss blind that hides cards. Confirm that unavailable phases are not consumable as playable states and that no draw order or face-down identity appears.

Release steps (version bump, sync, ZIP, commit, push) are listed in `AGENTS.md`; history is in `CHANGELOG.md`.

## Credits

Card sprites and the layer-compositing approach are adapted from [Balatro Calculator by Saffron Haas (efhiii)](https://efhiii.github.io/balatro-calculator/) (MIT), whose scoring engine is also bundled. Additional artwork comes from [Balatro Wiki](https://balatrowiki.org/) contributors. See `THIRD_PARTY_NOTICES.md` (also served at `/credits`) for sources and licenses. Balatro and its artwork belong to their respective owners; this project is not endorsed by them.

## Multiplayer compatibility (v1.2.0)

The existing dashboard supports the seven decks and nine added jokers listed on [Balatro Mods Wiki](https://balatromods.miraheze.org/wiki/Multiplayer), verified against installed Multiplayer 0.5.5 definitions. Artwork also covers Asteroid, Ouija 2, the Giga Standard Pack and Your Nemesis. Descriptions come from the loaded localization, including the current scalar values of reviewed jokers and the standard Hanging Chad, Bloodstone, Seltzer, Turtle Bean and Golden Ticket reworks. Phantom jokers are labeled separately.

Overview shows the active mode/ruleset, visible lives and, during PvP, the HUD's opponent hands and score text. Hidden scores remain hidden; raw enemy score objects, opponent cards, networking, lobby codes and seeds are never exported. Cocktail shows only component stickers revealed by the game. No new multiplayer network connection is opened.

The bundled vanilla calculator does not model Multiplayer rulesets, so it explains that limitation instead of reporting an incorrect estimate in active matches or with Multiplayer decks. Probability callbacks and unreviewed custom tooltip values remain `?`; the observer never calls them. Gameplay and vanilla observation behavior are unchanged. Restart Balatro after installation.

## Action history

Open **Mods > Balatro Observer > Config > Open Action Recorder** to export readable action logs with card positions, identities, and brief property changes. See [recorder documentation](action-recorder/README.md). Disable any older standalone recorder and restart Balatro after updating.
