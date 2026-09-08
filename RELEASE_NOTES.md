# v1.1.1 — Current deck on the overview

- The Overview now shows the deck you are playing next to the current blind: wiki artwork, name and effect text phrased exactly as Run Info shows it. The collector exports `run.deck` (key, localized name, description) from the same public definition values the game uses for its placeholders; modded decks with dynamic values show `?` rather than a guess. No other information is collected.
- Five deck pictures (Green, Black, Magic, Abandoned, Checkered) join the bundled Balatro Wiki artwork, so every vanilla deck has an image. Credits and sources are in THIRD_PARTY_NOTICES.md.
- 1.1.1 fixes a syntax error that crashed Balatro on load in 1.1.0 (never published). Includes the 1.0.1 launcher fix (an older viewer on the port is replaced automatically) and the 1.0.0 folder reorganization.

Extract the `BalatroObserver` folder into `%APPDATA%/Balatro/Mods`, replacing the old one, and restart Balatro to load the deck export.

Validation: both Lua suites (collector, JSON, export hook, launcher, deck adapter) executed on Balatro's own LuaJIT via scripts/run-lua-tests.py; 12 Node unit checks (Node 24 via Electron) including the 213-image route table; the overview rendered from the Windows/.NET server in Chromium with the deck panel, artwork and effect text; Windows launcher suite. Not run: the Playwright browser suites (no Playwright available); their assertions were updated for the deck panel.
