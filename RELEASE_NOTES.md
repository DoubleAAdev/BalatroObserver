# v0.7.0 — Selected-hand score preview and in-game launcher

- Add a Balatro Observer button above the deck pile. Clicking it opens http://127.0.0.1:8765 in the default browser; the local Node viewer server must be running.
- Remove the Image library navigation and gallery while retaining artwork used by cards, vouchers, stakes, blinds and booster packs.
- Set the website title and branding to Balatro Observer. The visible release indicator remains v0.7.0.
- Add a selected-hand score estimate in Overview and Current hand, powered locally by the credited Balatro Calculator engine. It follows selected-card, held-card and joker order, uses exported hand scoring values, handles supported editions/seals/bonuses, and displays a low-to-high range for random effects. Stale and unavailable snapshots suppress the live estimate. No run data is sent to the external calculator.
- Complete the vanilla joker-description adapter audit: all 150 initialized vanilla joker descriptions resolve their dynamic placeholders. Diet Cola now resolves its localized Double Tag name. Existing round targets and counters remain live. Arbitrary custom-mod callbacks remain unsupported and are never invoked.

Validation: collector privacy/export tests; all-150 vanilla description audit against local game definitions/localization; launcher placement/click-hook tests; scoring unit tests; live-selection and stale-state browser tests; existing responsive/card-art checks; all 208 wiki images decoded; 225 enhancement/edition/seal combinations.

Limits: score previews are calculator estimates, not game-engine predictions. Modded cards/jokers and some special combinations are explicitly withheld (including hidden cards, Vampire with Stone Cards, and Glass Joker with played Glass Cards). Other modded effects and blind rules can change the final score. No hidden ranks or RNG are accessed. The in-game button still needs a live-game visual check after restart; its lifecycle and click behavior were tested with UI stubs.

Install: extract BalatroObserver-v0.7.0.zip into %APPDATA%/Balatro/Mods. Restart Balatro to load the new collector and button. Run node viewer-server.js from the mod folder and refresh the website. Lovely and Steamodded are required.
