# Replayer

Replays a Multiplayer game from its Lovely log so Action Recorder can record every move again with card identities.

## Use

1. Open **Mods > Balatro Observer > Config**. Choose **Load Log** and pick the Lovely log of the game (`%APPDATA%\Balatro\Mods\lovely\log`). Dropping a `.log` onto Balatro also works. A log holding several games shows one run at a time; **Next Run** cycles through them. A replay writes its own inputs into the current Lovely log, so the newest files in that folder are replays rather than games; a run one of them recorded is named as such when the log is loaded.
2. **On a difference** switches between carrying on past a difference between the log and the game (the default, so the recording covers the whole run) and stopping at the first one (for working out where a run went wrong).
3. From the main menu, choose **Start Replay**. The game joins a copy of the recorded lobby, starts the recorded seed, deck, stake, ruleset and options, and plays the log through. Watch the status line in the config tab, or the Balatro log, or `%APPDATA%\Balatro\balatro_replayer\status.json`.
4. When the status says the replay is complete, open **Open Action Recorder** and export the run named in the status.
5. Return to the main menu. The lobby copy is dismantled and Multiplayer is left as it was.

**Stop Replay** ends playback and returns to the menu. Pausing or opening a menu only pauses the replay.

## What is replayed

The log carries three streams. `MP_RLOG:` lines are the player's inputs, positional: plays, discards, buys, sells, uses, pack picks and skips, rerolls, reorders, blind selection, skipping and readiness. `Client sent message: action:` lines mirror each input with the card, cost or blind it touched. `Client got ... message:` lines are what the server and opponent sent: opponent scores and hands, PvP round results, lives, the start of each PvP blind, asteroids and other joker effects.

The replay performs the inputs through the same game callbacks the buttons use and delivers the received messages back to Multiplayer's own handlers in the recorded order. Nothing is sent to the server. The lobby copy is needed because Multiplayer's jokers, rulesets and PvP resolution only exist inside a lobby; practice and ghost modes draw from different pools, so an earlier practice-mode replayer could not reproduce even the first shop.

## Checks

Before an input is performed, the card in the logged slot must carry the name the log mirrored, a purchase or reroll must cost what the log paid, and the blind must be the one the log chose. After it is performed, Multiplayer writes its own `MP_RLOG:` line for what actually happened; the replay compares that line and its mirrored line with the log, word for word, before moving on. It also compares the dollars the run moved with the dollars the log recorded, and the game's own progress reports: the score of every PvP hand, the ante, how far the run has come. (`spentLastShop` is not compared: it reports Multiplayer's own shop counter, which the emulated lobby does not reproduce, and nothing reads the value back.)

Dollars are matched over a window of a few inputs rather than demanded of the input they sit under: the game credits a joker's dollars a second or two after the input that earned them, and the log, written by a player who paused between clicks, files them with that input. A dollar the log records that the game never moves, or one the game moves that the log never records, is reported with the input and log line it belongs to, a few inputs after the fact. The same check covers what the game does by itself: the ante key of every blind (put back to the logged value), the PvP blind the server starts after Ready, and received asteroids. Every difference is written to the Balatro log and to `balatro_replayer/status.json` with the action and the log line it came from, and the closing status counts them along with the inputs that had to be skipped. With **On a difference: stop** the replay halts at the first one instead and leaves the run open to inspect. A replay that reports no differences reproduced the log exactly.

Transitions Multiplayer does not log are inferred: cashing out when the next input needs the shop or blind select, and leaving the shop when the next input is on the blind select screen.

A round that ends earlier or later here than it did in the log ends the replay. The game is left on a screen the log's next inputs will never be answered from - the log buys in a shop this run never opened, or plays a hand in a round this run has already won - and every input after that belongs to a round that no longer lines up, so replaying them would perform the next round's hands inside the unfinished one. The replay says which way round it went and how far the recording is faithful. Nothing in the log records the score of an ordinary blind, so this is the first place such a drift can be seen.

## Limits

- The Multiplayer version, ruleset, game mode, deck and Cocktail deck pool must match the log. Other installed mods should match the original game; a different mod set changes card pools and is reported at the first differing card.
- Challenge runs are not replayed.
- Multiplayer logs "Buy" and "Buy & Use" the same way. The replay decides from the evidence, in this order: money moving right after the purchase means the card was used at once (a Hermit or Temperance); a consumable the shop cannot use (it needs selected cards) was bought only; no free consumable slot means Buy & Use; otherwise the first later use or sale of the slot the card would occupy tells, since every card the game adds later lands behind it and every removal in front of it is logged. Without any later reference it is a plain buy. A purchase the log shows no payment for is replayed as the refused click it was. The Balatro log names the decision and its evidence for every consumable purchase.
- Multiplayer does not log drag reorders of the consumable rack. A run that reordered consumables by hand is reported at the first use or sale that names a different card.
- The log records positions, never which card sits in one. Two cards of the same rank and suit sit next to each other in the sorted hand and are told apart only by `Card.unique_val`, which comes from the order the game created the two objects in - something the log does not record and a replay cannot set. If the two swap, every position in the log still names a card of the right rank and suit, so hands score the same and the deck reads the same; the run only parts company at the first thing that tells the two apart, such as one of them carrying a seal or an enhancement. That surfaces as a dollar that was not paid or a consumable that was not created, and the money check names the input it happened on. Everything after it is a different run.
- A hand reorder that leaves the hand exactly as the sort-by-suit or sort-by-rank button would is applied as that button, so later draws sort the same way.
- The Multiplayer round timer is off during a replay, since a replay runs at animation speed. It changes no card.
- Replayed wins and losses are not written to Multiplayer's match history. Career statistics count as in practice mode.
