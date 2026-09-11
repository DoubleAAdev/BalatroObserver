# Replayer

Replays a Multiplayer game from its Lovely log so Action Recorder can record every move again with card identities.

## Use

1. Open **Mods > Balatro Observer > Config**. Choose **Load Log** and pick the Lovely log of the game (`%APPDATA%\Balatro\Mods\lovely\log`). Dropping a `.log` onto Balatro also works. A log holding several games shows one run at a time; **Next Run** cycles through them.
2. From the main menu, choose **Start Replay**. The game joins a copy of the recorded lobby, starts the recorded seed, deck, stake, ruleset and options, and plays the log through. Watch the status line in the config tab, or the Balatro log, or `%APPDATA%\Balatro\balatro_replayer\status.json`.
3. When the status says the replay is complete, open **Open Action Recorder** and export the run named in the status.
4. Return to the main menu. The lobby copy is dismantled and Multiplayer is left as it was.

**Stop Replay** ends playback and returns to the menu. Pausing or opening a menu only pauses the replay.

## What is replayed

The log carries three streams. `MP_RLOG:` lines are the player's inputs, positional: plays, discards, buys, sells, uses, pack picks and skips, rerolls, reorders, blind selection, skipping and readiness. `Client sent message: action:` lines mirror each input with the card, cost or blind it touched. `Client got ... message:` lines are what the server and opponent sent: opponent scores and hands, PvP round results, lives, the start of each PvP blind, asteroids and other joker effects.

The replay performs the inputs through the same game callbacks the buttons use and delivers the received messages back to Multiplayer's own handlers in the recorded order. Nothing is sent to the server. The lobby copy is needed because Multiplayer's jokers, rulesets and PvP resolution only exist inside a lobby; practice and ghost modes draw from different pools, so an earlier practice-mode replayer could not reproduce even the first shop.

## Checks

Before an input is performed, the card in the logged slot must carry the name the log mirrored, a purchase or reroll must cost what the log paid, and the blind must be the one the log chose. After it is performed, Multiplayer writes its own `MP_RLOG:` line for what actually happened; the replay compares that line and its mirrored line with the log, word for word, before moving on. The same check covers what the game does by itself: the ante key of every blind (put back to the logged value), the PvP blind the server starts after Ready, and received asteroids. Any difference stops the replay with both lines in the status, and the run is left open so it can be inspected. Only a complete, unbroken replay is reported as complete.

Transitions Multiplayer does not log are inferred: cashing out when the next input needs the shop or blind select, and leaving the shop when the next input is on the blind select screen.

## Limits

- The Multiplayer version, ruleset, game mode, deck and Cocktail deck pool must match the log. Other installed mods should match the original game; a different mod set changes card pools and is reported at the first differing card.
- Challenge runs are not replayed.
- Multiplayer logs "Buy" and "Buy & Use" the same way. A consumable bought with no free slot is bought and used at once; one bought with a free slot is bought only, which is what the log shows in every other case.
- A hand reorder that leaves the hand exactly as the sort-by-suit or sort-by-rank button would is applied as that button, so later draws sort the same way.
- The Multiplayer round timer is off during a replay, since a replay runs at animation speed. It changes no card.
- Replayed wins and losses are not written to Multiplayer's match history. Career statistics count as in practice mode.
