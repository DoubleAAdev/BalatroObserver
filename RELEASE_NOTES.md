# v0.7.2 — Start the viewer from the in-game button

Fixes the connection-refused error when clicking Balatro Observer while its local server is stopped.

On Windows the button now starts a hidden Node.js helper without blocking the game. The helper reuses a healthy viewer or starts it, waits for an identifying health response, and only then opens the browser. Repeated clicks do not start duplicate healthy servers. A conflicting application on port 8765 is left alone and reported. Startup errors open a local explanatory page; server output is saved to viewer-server.log.

Node.js 18+ remains required. No firewall changes are needed: the server stays on 127.0.0.1. Non-Windows platforms retain the URL shortcut and manual server startup.

Validation: cold-start/readiness, existing-server reuse, occupied-port and timeout tests; collector and launcher regressions; actual native Windows launch from a stopped server verified healthy at v0.7.2, followed by successful reuse.

Restart Balatro after installing to load the updated button. The website is then started automatically when the button is clicked.
