# v0.7.3 — Reliable in-game browser handoff

The in-game button now asks the helper to start the server and report readiness, then opens the website through Balatro's native browser handler. This removes the hidden helper's browser-opening step that could leave clicks with no visible result.

The button displays Starting viewer while waiting and a retry message on startup failure or timeout. Repeated clicks while starting are ignored, and stale readiness replies cannot open the browser.

Validation: launcher readiness/error/timeout/retry regressions, server startup tests, collector tests, and native Windows helper readiness handshake.

Restart Balatro after installing to load v0.7.3. Node.js remains required on Windows.
