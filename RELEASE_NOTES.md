# Balatro Observer and Action Recorder v2.0.0

- Action Recorder text exports now include exact replay records. Load exported `.txt` files or source `.jsonl` journals in Balatro Replayer v2.0.0.
- Record Multiplayer Ready inputs and ordered public opponent/PvP events. Observer displays opponent location and blind alongside visible scores, hands and lives.
- Preserve hidden-score and disabled-location settings; never expose face-down card identities or hidden draw order.
- Align Observer, Recorder page, health endpoint and launcher at 2.0.0. Remove the former replay incompatibility notice.

Replayer validates card identities and settled hands, preserves buy-and-use choices and sorting, and stops on divergence. Start a fresh v2.0.0 recording for Multiplayer; old logs lack network events. Resumed segments, challenges and arbitrary custom network effects are not supported.

Extract the ZIP's BalatroObserver folder into Balatro's Mods folder and restart Balatro. Install BalatroReplayer v2.0.0 separately. Viewer assets, Balatro Calculator credit and third-party licenses are included.

Validation: Observer and Recorder Lua suites; real C# export and Chromium download tests; Replayer importer/driver/session tests including the actual exported file; Multiplayer HUD/privacy checks and bundled asset tests.
