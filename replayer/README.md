# Replayer

In the main menu, open **Mods > Balatro Observer > Config**. Drop a Multiplayer `.log` onto Balatro, or put it at `%APPDATA%/Balatro/balatro_replayer/replay.log` and click **Load replay.log**. Use **Next run** for logs containing multiple manifests, then **Start Replayer**. **Stop Replayer** stops further input. Return to the main menu to end the replay session and restore prior practice settings.

Replayer uses Multiplayer's installed ghost engine for opponent scores and an Observer input driver for local actions. The manifest selects seed, deck, stake, ruleset, modifiers, and existing lobby gameplay options including Cocktail. It requires the recorded Multiplayer version, the deck/ruleset, and matching opponent history. Other installed gameplay mods should match the original environment; missing historical card identities or differing mod behavior can prevent exact reproduction.

Play, discard, buy, sell, use, reroll, pack selection/skipping, blind selection/skipping, and reorder pass through Action Recorder. Ante keys, PvP readiness and received asteroids drive the replay too. Cash-out and shop exit are inferred transitions because Multiplayer does not log them. Unsupported, ambiguous, rejected or timed-out actions stop the driver rather than silently skipping moves. This is not proof of deterministic equivalence: positional logs contain no card identity checkpoints for most actions.

Replay sessions disable saving and block Multiplayer Client.send. Importing never executes code from a log. No log contents are committed or transmitted. Existing user runs must be left before starting. Status is shown in config and `%APPDATA%/Balatro/balatro_replayer/status.json`. Export the resulting run through **Open Action Recorder**.
