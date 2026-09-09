# Action Recorder

Use **Remove** beside a run to hide it from the website after confirmation. Its journal stays on disk, including when the run is still being recorded. To restore a run, delete only its matching `.jsonl.removed` marker in `%APPDATA%/Balatro/balatro_action_recorder`, then refresh the page.

Open Mods > Balatro Observer > Config > Open Action Recorder. Export log downloads a plain .txt file, one numbered line per action. Cards are listed as arrays of `(card, index)` tuples, for example `discard: [("Ace of Spades", 2), ("King of Spades", 3)]`. Indices are 1-based slots at the time of the action. Card names include current non-default properties when relevant. Internal physical IDs are not displayed. Change lines contain only changed cards, using the same tuple format. Hidden cards are labeled face-down.


Tokens: play, discard, buy, sell, reroll, use, pack_pick, pack_skip, reorder, select_blind, skip_blind. Consumable targets, displayed costs, blind selections and reorder positions are retained. Automatic helpers using the same callbacks are also recorded.

No full deck, hand or Joker inventories are exported. New journals capture affected cards and targets only; after-action observations store changes to previously involved visible cards. Unrelated or unchanged cards are omitted. A card that changes while absent is updated on its next visible action; intermediate hidden changes and animation steps are not reconstructed.

Existing journals can be exported as text too. Internally the recorder retains append-only JSONL for crash recovery, stored in %APPDATA%/Balatro/balatro_action_recorder. Downloads are readable text, not dictionaries. Resumed games start partial segments. Incomplete trailing records are noted; corrupt complete records fail export. Exports are capped at 128 MB; original journals are never deleted.

The server runs locally on Windows at port 8766 using PowerShell/.NET. Restart Balatro after updating the recorder. Run python scripts/run-lua-tests.py from this directory, then node tests/test_export.cjs with Playwright and Chromium available. Install using the parent scripts/sync-mod.ps1.
