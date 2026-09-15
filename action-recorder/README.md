# Action Recorder

Use **Remove** beside a run to hide it from the website after confirmation. Its journal stays on disk, including when the run is still being recorded. To restore a run, delete only its matching `.jsonl.removed` marker in `%APPDATA%/Balatro/balatro_action_recorder`, then refresh the page.

Open Mods > Balatro Observer > Config > Open Action Recorder. Export log downloads a plain .txt file, one numbered line per action. Cards are listed as arrays of `(card, index)` tuples, for example `discard: [("Ace of Spades", 2), ("King of Spades", 3)]`. Indices are 1-based slots at the time of the action. Card names include current non-default properties when relevant. Internal physical IDs are not displayed. Change lines contain only changed cards, using the same tuple format. Hidden cards are labeled face-down.


Tokens: play, discard, buy, sell, reroll, use, pack_pick, pack_skip, reorder, select_blind, skip_blind. Consumable targets, displayed costs, blind selections and reorder positions are retained. Automatic helpers using the same callbacks are also recorded.

From v1.12.0, the run header records seed, deck, stake, challenge, loaded Observer version, installed mod versions, and available Multiplayer ruleset, game mode and scalar lobby settings. Play/discard actions include the complete visible hand before the callback and after settling (or before the next input). Slots and physical identities remain distinct internally; face-down cards stay anonymous. An unfinished action has an explicit unavailable outcome on export. No hidden draw order is captured.

Balatro Replayer currently imports Multiplayer Lovely logs, not this annotated export. Its log parser requires MP_RLOG manifests and positional actions plus opponent/server messages; its driver calls game callbacks and its session recreates the lobby and checks drift. This export preserves setup for future importer work, but is not yet a standalone replay input. Keep the original Lovely log for current replay use. Single-player/challenge imports and resuming mid-run also require replayer support. Old journals cannot recover missing seeds or hands.

Existing journals can be exported as text too. Internally the recorder retains append-only JSONL for crash recovery, stored in %APPDATA%/Balatro/balatro_action_recorder. Downloads are readable text, not dictionaries. Resumed games start partial segments. Incomplete trailing records are noted; corrupt complete records fail export. Exports are capped at 128 MB; original journals are never deleted.

The server runs locally on Windows at port 8766 using PowerShell/.NET. Restart Balatro after updating the recorder. Run python scripts/run-lua-tests.py from this directory, then node tests/test_export.cjs with Playwright and Chromium available. Install using the parent scripts/sync-mod.ps1.
