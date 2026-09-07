# Balatro Observer

Read-only Steamodded mod. Copy this directory into `%APPDATA%/Balatro/Mods/BalatroObserver` and restart Balatro with Steamodded installed. Keep the JSON manifest and the three Lua modules together. No files in the game installation are modified.

Every 200 ms after a game update, the mod writes alternating `state-0.json` and `state-1.json` files under `balatro_observer` in LÖVE's save directory (normally `%APPDATA%/Balatro/balatro_observer` on Windows). `love.filesystem.getSaveDirectory()` gives the actual location. The files contain snapshots, not a recording of every action.

Consumers should parse both files independently, ignore malformed/incomplete files, and choose the newest `observed_at`, then the greatest `sequence` within its `session`. On a session change reset episode state. Reject stale records and records with `available: false`; never fall back to an older playable observation when a newer unavailable record exists. A failed write preserves the other slot. Polling can miss fast transitions; this is not yet an action/reward training pipeline.

For in-process use, `BalatroObserver.snapshot()` returns a detached Lua table. `BalatroObserver.last_export_ok` reports the latest export's success. Errors are contained so the observer cannot stop the update loop; error details are deliberately not exported.

## Schema version 1

- `phase`, `available`: only recognized completed run phases are sampled. Animations, overlays, pauses, menus and unknown phases produce an unavailable record. Availability is a sampling guard, not a guarantee that a specific action is legal.
- `run`, `round`, `blind`: money, score, stake, round, ante, remaining hands/discards, and current blind information.
- `hand`, `jokers`, `consumables`: ordered area cards, capacity, current slot, selection, visible identity, edition, seal, costs and supported stickers. Face-down cards contain only `visible: false` and their slot.
- `deck`: full deck-view composition in canonical order, draw-pile count and discard-pile count. Duplicates are retained. This is **not** an ordered draw pile or an exact remaining-card list. Composition never includes area membership, selection, transient debuffs or persistent card IDs. Full composition includes cards currently in hand, matching the full deck viewer; it cannot map a hidden hand slot to a card. Stone Cards omit their underlying rank and suit.
- `poker_hands`: visible hand types with levels, chips, multiplier and play counts.
- `shop`: present only during SHOP; card, voucher and booster areas plus reroll cost. Booster contents are not inspected.
- `pack`: present only during an opened pack phase; visible choices and remaining picks.
- `session`, `sequence`, `observed_at`: export metadata, unrelated to game RNG.

Unknown scalar values are omitted. Arrays remain JSON arrays even when empty. Scores represented by another mod's big-number objects are omitted rather than traversed or rounded. Consumers must treat missing fields as unknown, not zero.

## Visibility boundary and limitations

No seed, RNG state, future shops, unopened pack contents, draw order, internal card IDs, arbitrary `ability.extra`, callbacks, game actions or opponent state are exported. The collector does not call scoring, random, card tooltip or action functions. It does not modify game objects. Deck composition follows the full deck viewer in [Steamodded's source](https://github.com/Steamodded/smods/blob/main/src/overrides.lua).

Dynamic joker tooltip values, custom editions/enhancements, tags, vouchers already redeemed, upcoming blind choices, and multiplayer HUD data need explicit visibility-reviewed adapters. They are not fully represented in this first schema. [Multiplayer's state](https://github.com/Balatro-Multiplayer/BalatroMultiplayer/blob/dev/core.lua) contains concealed opponent values and visibility settings, so copying it would be unsafe. Custom mods that alter visibility need separate verification. This mod does not establish multiplayer ruleset approval or guarantee compatibility with every mod version.

## Validation

From the repository root run `lua tests/test_observer.lua` with Lua 5.1+ or LuaJIT. Tests cover hidden-card redaction, deck order/membership invariance, secret exclusion, shop/phase gating, JSON escaping, and export failure isolation.

Live smoke test: start a run, compare a snapshot to the HUD and full deck viewer, select a card, discard/play, enter/leave the shop, open a pack, and test a face-down blind. Check that unavailable phases cannot be consumed as playable states. Confirm no draw order or hidden face-down identity appears. A local game was not available during implementation, so this live test remains required.
