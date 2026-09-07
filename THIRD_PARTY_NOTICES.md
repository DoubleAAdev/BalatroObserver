# Third-party notices

The viewer reuses sprite atlases and adapts the card-layer rendering approach from Balatro Calculator by Saffron Haas (efhiii):

https://efhiii.github.io/balatro-calculator/
https://github.com/efhiii/balatro-calculator

Pinned reference commit: 55322d59197ba08c16874a54b59ac0d443c8ab32.

Reused files: assets/8BitDeck_opt2.png, assets/Enhancers.png, assets/Editions.png, assets/Jokers.png. Vanilla joker coordinates are derived from the reference cards.js definitions. Enhancement, edition and seal coordinates and compositing are adapted from main.js and style.css. The full upstream MIT notice follows and is also preserved in assets/LICENSE-balatro-calculator.txt.

Balatro and its original game artwork belong to their respective owners. This attribution describes the source of the reused assets and does not claim authorship of that artwork or endorsement by its owners.

---
MIT License

Copyright (c) 2024 Saffron Haas

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


## Balatro Wiki artwork

Additional images are sourced from Balatro Wiki contributors: https://balatrowiki.org/w/Tarot_cards, https://balatrowiki.org/w/Planet_cards, https://balatrowiki.org/w/Spectral_cards, https://balatrowiki.org/w/Vouchers, https://balatrowiki.org/w/Stakes, https://balatrowiki.org/w/Blinds_and_Antes.

The 208 original image files are bundled unchanged in assets/wiki/. assets/wiki-art.json records each image URL and its source articles. Retrieved 2026-09-07. Wiki content is offered under CC BY-NC-SA 3.0 (https://creativecommons.org/licenses/by-nc-sa/3.0/); additional terms may apply (https://meta.weirdgloop.org/w/Licensing). Original Balatro artwork remains the property of its respective owners. These images are not covered by this repository’s code license. Viewer styling (scaling and edition effects) is applied at display time. Balatro Wiki and game creators do not endorse this project.

Booster pack artwork also comes from https://balatrowiki.org/w/Booster_Packs, under the same attribution and licensing terms. All 32 vanilla pack wrapper variants are mapped independently.

Version 0.6.1 omits the six obsolete demo vouchers: Magnet, Electromagnet, Pattern, Tesselation, Silver Spoon (BigSpoon), and Heirloom (BigGoldSpoon).
