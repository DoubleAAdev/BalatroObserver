# v0.4.0 — Remaining cards, descriptions, and stable previews

This release implements the current local player-visible feature checklist.

## New in the viewer

- **Remaining cards:** a dedicated section matching the public unplayed-deck view. Face-down ambiguity is preserved, so its count can exceed the actual draw-pile count. No draw order or hidden-slot identities are exported.
- **Card sorting:** choose game/canonical order, rank ascending or descending, suit, or name. Sorting affects only the browser, persists across refreshes, and leaves face-down slots fixed.
- **Boss effects:** show the current blind's cached effect text and available descriptions for current-ante blind choices.
- **Joker descriptions:** display localization text with explicitly supported live values. Abstract Joker reports its multiplier per joker and its current total. Unsupported dynamic values display ?; custom tooltip callbacks are not executed.
- **Stable previews:** keep the last available game preview during animations, pauses, stale exports, and connection interruptions. A status label identifies the retained preview. New sessions clear the previous session's preview, and Raw data always shows the newest received record.

Also includes the previously committed v0.3.0 features: Blinds & tags, redeemed vouchers, and Steamodded opened-pack support.

## Install or update

Download BalatroObserver-v0.4.0.zip and extract its BalatroObserver folder into your Balatro Mods folder. Lovely and Steamodded are required. On Windows the mod manifest belongs at %APPDATA%/Balatro/Mods/BalatroObserver/BalatroObserver.json.

Restart Balatro to load v0.4.0. From the mod folder, run:

```sh
node viewer-server.js
```

Open http://127.0.0.1:8765 and refresh any existing viewer tab. Node.js 18 or newer is required for the local viewer. Raw snapshot files remain in %APPDATA%/Balatro/balatro_observer.

## Validation

Lua tests passed for visibility, remaining-card ambiguity, joker totals, boss text, blind/tag/voucher exports, pack phases, JSON encoding, and export failure handling. Node server tests and browser regression checks passed for all 11 sections, sorting, persistence, retained previews, session resets, pause, and mobile width.

Browser checks use controlled snapshot fixtures. Comparison with the live game HUD remains a manual check.

## Update workflow

The local “update missing” command now includes checklist review, implementation, versioning, ignored generated artifacts, validation, installed-mod synchronization, an explanatory commit, push, and a packaged GitHub release. The local checklist remains ignored and is not included in this release.

