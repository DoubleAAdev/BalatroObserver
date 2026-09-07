# v0.6.1 — Joker values and artwork fixes

- Fix nested joker field names containing underscores. Wee Joker, suit jokers such as Greedy Joker, Runner, Green Joker, Mystic Summit and other existing adapters now show their exported live values correctly. Missing/non-scalar custom values still remain unknown; no values are invented.
- Remove the six obsolete demo vouchers from the image library, source assets and installed mod. The library now contains 208 credited Balatro Wiki images.
- Give all 32 booster pack wrappers their native 114:186 proportions and taller containers on desktop and mobile.

Validation: Lua collector/privacy regression checks, HTTP tests, existing browser checks, 225 card-art combinations, and all 208 wiki images decoded. Pack geometry checked on desktop/mobile; demo vouchers verified absent.

Install the ZIP into %APPDATA%/Balatro/Mods. Restart Balatro to load the fixed collector, restart node viewer-server.js, and refresh http://127.0.0.1:8765.
