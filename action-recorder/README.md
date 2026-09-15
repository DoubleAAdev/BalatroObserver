# Action Recorder v2.0.0

Open **Mods > Balatro Observer > Config > Open Action Recorder**, then **Export latest game**. The downloaded `.txt` contains readable actions, full visible hands before and after plays/discards, in a readable text file. Replayer uses the original Multiplayer Lovely log; these text exports are for reviewing actions.

Run setup includes seed, deck, stake, hand sorting, loaded versions, and Multiplayer lobby options. Card slots are 1-based. Physical card identities are retained in replay records to distinguish duplicates. Face-down cards remain anonymous; no hidden draw order is captured.

Multiplayer logs record Ready inputs, public opponent location/score changes, and ordered receive events for PvP starts/results, lives, and supported opponent effects. Hidden scores and disabled locations remain hidden. The recorder never sends network messages. The dashboard follows the same visibility settings.

To replay a run, load its original Multiplayer Lovely log in Replayer. The recorder retains JSONL journals internally; downloads are readable `.txt` files without embedded replay records.

**Remove** hides a recording after confirmation and leaves its journal on disk. Delete its matching `.jsonl.removed` marker in `%APPDATA%/Balatro/balatro_action_recorder` to restore the listing. Incomplete trailing entries are noted on export; corrupt complete records fail export. Exports are capped at 128 MB.

The Windows server runs locally on port 8766. Restart Balatro after updating. Run `python scripts/run-lua-tests.py` from this directory, then `node tests/test_export.cjs` with Playwright and Chromium available. Install with the parent `scripts/sync-mod.ps1`.
