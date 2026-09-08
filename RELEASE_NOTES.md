# v0.8.0 — Windows viewer without Node.js

- Open the live website from the in-game mod settings or double-click start-viewer.cmd; Windows PowerShell 5.1 and .NET Framework supply the server, with no Node installation needed.
- Preserve live two-slot snapshot selection, raw JSON, running mod_version, card artwork, score scripts and third-party credits. No new game information is collected.
- Keep HTTP traffic on 127.0.0.1 and expose only viewer assets, health and state routes. Reuse a matching viewer; report occupied ports without stopping other processes.
- Include all assets, Balatro Calculator attribution and its MIT notice in the installable ZIP.

Extract the BalatroObserver folder into %APPDATA%/Balatro/Mods. Restart Balatro to load v0.8.0 and close any older viewer server before starting the new viewer. The optional Node server remains available for other platforms. PowerShell-restricted Windows environments may require policy configuration or the optional Node server.

Validation: 12 Node unit checks; collector and launcher Lua suites; four existing Chromium suites (including 225 card-art combinations and 208 wiki images); Windows/.NET HTTP and browser integration with Node absent from PATH; hidden cold startup, readiness, version mismatch and occupied-port handling. Installation verifies all 234 release files by SHA-256. Live in-game clicking after restart remains to be confirmed.
