# v0.7.1 — Random image fixes

- Fix Caino's missing portrait by using the game's canonical j_caino key instead of the legacy j_Canio spelling. Both the background and legendary face layer now render.
- Correct the same key in the calculator mappings so Caino's current multiplier is included in selected-hand score estimates.
- Preserve the existing Balatro Calculator artwork credit and MIT notice.

Validation: browser regression for Caino's two sprite layers and absence of fallback artwork; calculator regression for its canonical ID and multiplier; existing viewer/card-art tests.

Install: extract BalatroObserver-v0.7.1.zip into %APPDATA%/Balatro/Mods. Refresh the viewer after updating. Restart Balatro to align its loaded version with v0.7.1.
