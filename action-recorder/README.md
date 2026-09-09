# Balatro Observer Action Recorder

Open **Mods > Balatro Observer > Config > Open Action Recorder** to start the local export page at http://127.0.0.1:8766. The Windows server uses built-in PowerShell/.NET. Restart Balatro after installing. Disable any older standalone companion to avoid duplicate recording; existing journals remain accessible.

Choose Export latest game or Export JSON. Journals stay in %APPDATA%/Balatro/balatro_action_recorder. Each new run has its own file; resumed runs start a segment marked partial:true.

Tokens: play, discard, buy, sell, reroll, use, pack_pick, pack_skip, reorder, select_blind, skip_blind.

Card indices are 1-based positions in the named area at action time. Card references contain index, card (description dictionary key), and instance (physical card identity). Resolve descriptions using export.cards[reference.card]. Different physical cards can share a description. Changed properties create new descriptions. Reorders include order[new_index] = old_index. Targets identify selected consumable targets; options describe visible choices. Prices reflect pre-action displayed costs.

The game appends compact JSONL records without rewriting history. Export produces ordinary JSON with recording metadata, cards, actions, and observations. Observations capture later stable visible state; rapid actions may share an observation. This is an action history, not a deterministic replay. Interrupted trailing records are flagged; corrupt complete records fail export. Exports are limited to 128 MB. Original journals are retained.

Face-down cards contain only their index and hidden:true. Stone cards omit rank and suit. Seeds, credentials, hidden opponent state, draw order, and arbitrary ability fields are excluded. Existing index-only logs cannot reconstruct identities. Disk failures stop the recording segment while gameplay continues.

Run python scripts/run-lua-tests.py from this folder, followed by node tests/test_export.cjs (requires Playwright and Chromium). Install using the parent repository scripts/sync-mod.ps1.

Exports use readable dictionary keys such as `Ace of Spades`; changed descriptions have numbered variants. Positions and physical instance IDs remain separate. Empty fields and default `c_base`, `Default`, and zero permanent bonus are omitted. Existing journals also receive this compact format when exported again.
