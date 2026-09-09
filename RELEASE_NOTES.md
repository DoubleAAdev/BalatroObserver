# v1.2.0 — Multiplayer observation support

- Keep the existing folder layout and add a small, optional mod/multiplayer.lua adapter.
- Add 21 attributed Multiplayer wiki images for seven decks, nine jokers, consumables, the Giga Standard Pack, Nemesis blind and Planet stake.
- Display current localized deck/joker descriptions, reviewed dynamic values, standard rework portraits, Phantom labels and revealed Cocktail components.
- Show public match HUD data while preserving hidden-score rules and excluding opponent cards, seeds, lobby codes and network state.
- Explain unsupported Multiplayer scoring and callback-derived tooltip values instead of guessing. Vanilla scoring and retained previews remain available outside Multiplayer.

Validated with Lua collector/privacy tests, Node server and score tests, browser rendering and artwork decoding, and Windows server route parity. Compatibility definitions checked against Multiplayer 0.5.5; the wiki currently documents 0.5.2. A live two-player match has not been exercised by the automated tests.

Restart Balatro to load the new collector and refresh the website.
