# v0.6.0 — Wiki artwork, live joker values, and shop history

- Bundle all 177 unique article images from the six requested Balatro Wiki pages. Add mapped artwork for Tarot, Planet and Spectral cards, vouchers, blinds and stakes. Edition overlays, including negative, apply to consumable artwork.
- Add a searchable image library with six page filters. This is a reference catalog, separate from the current run. All artwork loads locally.
- Credit Balatro Wiki visibly and include per-image sources and licensing information. Preserve the Balatro Calculator credit and MIT notice.
- Expand explicit vanilla joker tooltip adapters: Mail-In Rebate payout and target rank, Gros Michel and Cavendish odds, Bull and Bootstraps totals, Castle and Ancient Joker targets, The Idol, and additional supported counters. Hidden cards remain redacted; no tooltip callbacks or RNG functions are invoked.
- Retain the last observed shop inventory after leaving, with its observation time and an information notice that the shop is currently inaccessible. A newly observed empty shop replaces the old inventory; new sessions clear shop history. History lasts for the current browser page session.

Validation: Lua collector/privacy checks, HTTP/static-route tests, existing browser regression checks, 225 edition/enhancement/seal combinations, and new tests decoding all 177 images, filtering, mobile layout, and shop-history transitions.

Limitations: custom tooltip callbacks and unsupported dynamic values still show ?. Negative artwork is a CSS approximation. Restart Balatro to load the installed collector; refresh the viewer after updating.

Install: extract BalatroObserver-v0.6.0.zip into %APPDATA%/Balatro/Mods so that BalatroObserver/BalatroObserver.json is directly inside that folder. Lovely and Steamodded are required. Run node viewer-server.js from BalatroObserver and open http://127.0.0.1:8765.
