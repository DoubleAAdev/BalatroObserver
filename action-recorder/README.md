# Action Recorder

Open Mods > Balatro Observer > Config > Open Action Recorder. Export log downloads a plain .txt file, one numbered line per action. Cards are named at the time of the action, with their physical card ID and 1-based slot. First mentions include non-default properties. Later mentions report only changed properties. Hidden cards have no identity. Brief change lines can follow an action when its effects settle.

Tokens: play, discard, buy, sell, reroll, use, pack_pick, pack_skip, reorder, select_blind, skip_blind. Consumable targets, displayed costs, blind selections and reorder positions are retained. Automatic helpers using the same callbacks are also recorded.

No full deck, hand or Joker inventories are exported. New journals capture affected cards and targets only; after-action observations store changes to previously involved visible cards. Unrelated or unchanged cards are omitted. A card that changes while absent is updated on its next visible action; intermediate hidden changes and animation steps are not reconstructed.

Existing journals can be exported as text too. Internally the recorder retains append-only JSONL for crash recovery, stored in %APPDATA%/Balatro/balatro_action_recorder. Downloads are readable text, not dictionaries. Resumed games start partial segments. Incomplete trailing records are noted; corrupt complete records fail export. Exports are capped at 128 MB; original journals are never deleted.

The server runs locally on Windows at port 8766 using PowerShell/.NET. Restart Balatro after updating the recorder. Run python scripts/run-lua-tests.py from this directory, then node tests/test_export.cjs with Playwright and Chromium available. Install using the parent scripts/sync-mod.ps1.
