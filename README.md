# Balatro Observer

View player-visible Balatro game data through **raw JSON snapshot files** or a **live local HTML dashboard**. This read-only Steamodded mod exports the current state every 200 ms.

## Two ways to view your data

| View | How to open it | What it provides |
| --- | --- | --- |
| Raw JSON files | Open state-0.json and state-1.json in %APPDATA%/Balatro/balatro_observer | Structured snapshots for inspection and external tools |
| Local HTML dashboard | Run node viewer-server.js from the mod folder, then open http://127.0.0.1:8765 | Automatically updating sections for the run, hand, deck, jokers, shop, packs, and poker hands |

The dashboard requires Node.js 18 or newer. The raw exports only require the mod. Both views use the same exported information; the dashboard also has a Raw data section.

## Install the mod

Download the mod ZIP from [GitHub Releases](https://github.com/DoubleAAdev/BalatroObserver/releases/latest) and extract its BalatroObserver folder into your Balatro Mods directory. You can also use a source checkout.

Read-only Steamodded mod. Install both **Lovely and Steamodded** first, following the [Steamodded installation guide](https://docs.smods.dev/Installation/). Lovely alone does not load this mod. Confirm that Balatro's main menu has a **Mods** button.

Copy this directory into `%APPDATA%/Balatro/Mods/BalatroObserver` and restart Balatro. Keep `BalatroObserver.json`, `main.lua`, `json.lua`, and `observer.lua` directly inside that folder. The Steamodded folder must be alongside `BalatroObserver` inside `Mods`. No files in the game installation are modified by BalatroObserver.

If there is no **Mods** button, check the Lovely/Steamodded installation first. If the button is present but Balatro Observer is missing or disabled, check the folder layout and its dependency status in the Mods menu.

Every 200 ms after a game update, the mod writes alternating `state-0.json` and `state-1.json` files under `balatro_observer` in LÖVE's save directory (normally `%APPDATA%/Balatro/balatro_observer` on Windows). `love.filesystem.getSaveDirectory()` gives the actual location. The files contain snapshots, not a recording of every action.

Consumers should parse both files independently, ignore malformed/incomplete files, and choose the newest `observed_at`, then the greatest `sequence` within its `session`. On a session change reset episode state. Reject stale records and records with `available: false`; never fall back to an older playable observation when a newer unavailable record exists. A failed write preserves the other slot. Polling can miss fast transitions; this is not yet an action/reward training pipeline.

For in-process use, `BalatroObserver.snapshot()` returns a detached Lua table. `BalatroObserver.last_export_ok` reports the latest export's success. Errors are contained so the observer cannot stop the update loop; error details are deliberately not exported.

## Schema version 1

- `phase`, `available`: only recognized completed run phases are sampled. Animations, overlays, pauses, menus and unknown phases produce an unavailable record. Availability is a sampling guard, not a guarantee that a specific action is legal.
- `run`, `round`, `blind`: money, score, stake, round, ante, remaining hands/discards, and current blind information.
- `hand`, `jokers`, `consumables`: ordered area cards, capacity, current slot, selection, visible identity, edition, seal, costs and supported stickers. Face-down cards contain only `visible: false` and their slot.
- `deck`: full deck-view composition in canonical order, draw-pile count and discard-pile count. Duplicates are retained. This is **not** an ordered draw pile or an exact remaining-card list. Composition never includes area membership, selection, transient debuffs or persistent card IDs. Full composition includes cards currently in hand, matching the full deck viewer; it cannot map a hidden hand slot to a card. Stone Cards omit their underlying rank and suit.
- `poker_hands`: visible hand types with levels, chips, multiplier and play counts.
- `blinds`: current-ante Small/Big/Boss definitions, public statuses, next and boss identities, and skip-tag identities. Base multipliers/rewards are definition values, not a prediction of final modified targets or payouts.
- `vouchers`: acquired vouchers in the same registry order as Run Info, including starting vouchers.
- `shop`: present only during SHOP; card, voucher and booster areas plus reroll cost. Booster contents are not inspected.
- `pack`: present only during an opened pack phase (including Steamodded’s SMODS_BOOSTER_OPENED); visible choices and remaining picks.
- `session`, `sequence`, `observed_at`: export metadata, unrelated to game RNG.
- `mod_version`: the mod version loaded in Balatro, used to detect when a restart is needed.

Unknown scalar values are omitted. Arrays remain JSON arrays even when empty. Scores represented by another mod's big-number objects are omitted rather than traversed or rounded. Consumers must treat missing fields as unknown, not zero.

## Visibility boundary and limitations

No seed, RNG state, future shops, unopened pack contents, draw order, internal card IDs, arbitrary `ability.extra`, callbacks, game actions or opponent state are exported. The collector does not call scoring, random, card tooltip or action functions. It does not modify game objects. Deck composition follows the full deck viewer in [Steamodded's source](https://github.com/Steamodded/smods/blob/main/src/overrides.lua).

Dynamic joker tooltip values, custom editions/enhancements, dynamic tag effects and multiplayer HUD data need explicit visibility-reviewed adapters. They are not fully represented in this first schema. [Multiplayer's state](https://github.com/Balatro-Multiplayer/BalatroMultiplayer/blob/dev/core.lua) contains concealed opponent values and visibility settings, so copying it would be unsafe. Custom mods that alter visibility need separate verification. This mod does not establish multiplayer ruleset approval or guarantee compatibility with every mod version.

## Validation

From the repository root run `lua tests/test_observer.lua` with Lua 5.1+ or LuaJIT. Tests cover hidden-card redaction, deck order/membership invariance, secret exclusion, shop/phase gating, JSON escaping, and export failure isolation.

Live smoke test: start a run, compare a snapshot to the HUD and full deck viewer, select a card, discard/play, enter/leave the shop, open a pack, and test a face-down blind. Check that unavailable phases cannot be consumed as playable states. Confirm no draw order or hidden face-down identity appears. A local game was not available during implementation, so this live test remains required.

## Live HTML viewer

Run `node viewer-server.js` from this folder, then open http://127.0.0.1:8765. Requires Node.js 18 or newer. The viewer automatically reads `%APPDATA%/Balatro/balatro_observer` and refreshes every 200 ms. For another save location, run `node viewer-server.js "D:\path\to\balatro_observer"`. Set the `PORT` environment variable to change the default port of 8765.

`observer.html` displays the current hand, jokers, consumables, run counters, blind, shop, pack, poker hands, full deck composition, and raw snapshot. Unavailable or stale snapshots hide the game panels; missing fields display an em dash. Pause updates freezes the display and labels it as paused. The server listens only on localhost and reads the existing exports without modifying the mod. Open the HTTP URL rather than double-clicking the HTML file, because browsers cannot automatically read these local files.

Viewer checks: `node --test tests/test_viewer.cjs`.

## Release versions and installation

Current release: **0.3.0**. Every completed viewer or mod update increments the release version. The viewer shows its own version and the running mod version from snapshot metadata (`mod_version`). An older mod without this field is marked unreported; restart Balatro after installation to load the new release.

Run `./sync-mod.ps1` from the project to install the current release into `%APPDATA%/Balatro/Mods/BalatroObserver`. The script checks viewer/manifest version consistency and verifies every copied release file by SHA-256. An alternative Mods directory can be passed with `-ModsDirectory`. Refresh the viewer after an update. Restart its Node server if viewer-server.js changed.

Release 0.2.1 removes buy/sell labels from displayed cards. Generated local artifacts are ignored; release changes are committed after validation and installation.

Release 0.3.0 adds Blinds & tags and Vouchers sections and fixes opened-pack exports for Steamodded’s booster phase. Before each code update, the local missing.txt checklist is reviewed against collector and browser coverage.
