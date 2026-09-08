# Changelog

## 1.0.0 — Organized layout

- The mod folder is sorted by role: `mod/` (in-game collector and launcher), `viewer/` (dashboard), `server/` (Windows PowerShell/.NET and Node servers), `assets/`, `scripts/`, `tests/`. `BalatroObserver.json`, `main.lua` and `start-viewer.cmd` stay at the root.
- The dashboard is split into `observer.html`, `observer.css`, `observer.js` and `joker-sprites.js`. Every URL the servers expose is unchanged.
- The Node launcher now reuses a running viewer only when its version matches the release, exactly like the Windows launcher; both servers report their runtime in `/health`, and the Node server answers non-GET requests with 405.
- `scripts/sync-mod.ps1` removes files from the installed mod folder that are not part of the release, so older layouts cannot linger. `scripts/build-release.ps1` stages and zips a release from the same manifest (`scripts/release-files.ps1`).
- Documentation: README rewritten as a user and developer guide; release history moved here.
- No change to the exported schema, the visibility boundary, or the information collected.

## 0.8.0 — Windows viewer without Node.js

- In-game launcher and new `start-viewer.cmd` use built-in Windows PowerShell 5.1 / .NET Framework (`viewer-server.cs`). The server binds only to 127.0.0.1, serves explicitly allowed assets and reads the two snapshot slots without altering their JSON. Node remains optional for other platforms.

## 0.7.5 — Keep the last selected score

- The selected-hand estimate stays visible after playing, deselecting, shop transitions or connection interruptions until another selection replaces it. A new session clears it.

## 0.7.4 — Settings shortcut and number formatting

- The viewer opens from Mods → Balatro Observer → configuration; the draw-pile button is removed. Floating-point values display with two decimals; raw snapshots keep full precision.

## 0.7.3 — Reliable in-game browser handoff

- The launcher waits for a request-specific readiness file, then opens the browser through LÖVE. The button shows progress and allows retry after failure or a 15-second timeout.

## 0.7.2 — Automatic viewer startup on Windows

- The in-game button starts the local server, waits until it responds and opens the browser, reusing an existing healthy viewer. Failures produce a local explanation page; an unrelated application on port 8765 is never terminated.

## 0.7.1

- Corrects Caino's key in the portrait and calculator mappings, including its legendary face layer.

## 0.7.0 — Score preview and deck launcher

- Overview and Current hand show a **Selected hand score** estimate from the bundled Balatro Calculator engine using the actual selection and joker order, held cards, public counters, hand chips/mult, editions, seals and supported bonuses. Random effects show a range.
- The collector exports `score_vars` (reviewed public tooltip scalars), visible `perma_bonus`, `run.deck_key` and `scoring_context.loyalty_remaining`. The vanilla description audit covers all 150 jokers.
- The image-library gallery is removed; artwork used in run views stays bundled and credited.

## 0.6.1

- Removes six obsolete demo vouchers from the image library (208 wiki images remain), gives booster wrappers their native proportions and fixes nested joker fields containing underscores.

## 0.6.0 — Wiki artwork, live joker values, shop history

- Bundles credited Balatro Wiki images for consumables, vouchers, blinds, stakes and booster packs. Shop previews retain the last observed inventory for the browser session. More vanilla tooltip values get explicit scalar adapters.

## 0.5.0 — Card rendering

- Reuses the card, enhancement, edition, seal and vanilla joker sprite atlases from Balatro Calculator and adapts its layer compositing. Custom cards without a mapped sprite keep a labeled fallback.

## 0.4.1

- Full deck and Remaining cards are arranged like the in-game deck viewer: one overlapping row per suit, Ace to 2, duplicates preserved.

## 0.4.0 — Remaining cards, tooltips, stable previews

- Adds the public remaining-cards view (`deck.remaining_cards`), viewer-only sorting, joker descriptions with supported live values, boss effect text (`blind.loc_debuff_text`) and a persistent last preview.

## 0.3.0 — Blinds, tags, vouchers, packs

- Adds Blinds & tags and Vouchers sections and fixes opened-pack exports for Steamodded's booster phase.

## 0.2.2

- Documents the raw JSON and local HTML views.

## 0.2.1

- Removes buy/sell labels from displayed cards; release workflow automated.

## 0.2.0 and earlier

- Initial read-only collector with alternating snapshot files and the first dashboard.
