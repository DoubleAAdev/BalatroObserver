-- Run from the repository root: python scripts/run-lua-tests.py tests/test_replayer_log.lua
local decoded = {}
local log = dofile('replayer/log.lua')(function(text)
    decoded[#decoded + 1] = text
    if text:find('"seed":"TESTSEED"') then
        return {seed = 'TESTSEED', deck = 'b_red', ruleset = 'ruleset_mp_standard_ranked', gamemode = 'gamemode_mp_attrition',
            lobby_config = {stake = 1, the_order = true}, lobby_code = 'ABCDE', is_host = true, player = 'Me', opponent = 'Them'}
    end
    if text:find('"result"') then return {result = 'win'} end
    if text:find('"action":"') then
        local fields = {action = text:match('"action":"(%w+)"'), score = text:match('"score":"([^"]*)"')}
        for key, value in text:gmatch('"(%w+)":(%-?%d+)') do fields[key] = tonumber(value) end
        return fields
    end
    return {seed = 'SECOND', deck = 'b_red', ruleset = 'r', gamemode = 'g', stake = 2}
end)

local P = 'INFO - [G] 2026-09-09 18:12:21 :: TRACE :: MULTIPLAYER :: '
local lines = {
    P .. 'Client got lobbyInfo message:  (host: Me~7)  (guest: Them~1)  (guestReady: true)  (action: lobbyInfo)  (isHost: true) ',
    P .. 'Client got enemyLocation message:  (location: Blind Select)  (action: enemyLocation) ',
    P .. 'Client got startGame message:  (deck: c_multiplayer_1)  (action: startGame) ',
    P .. 'MP_RLOG: MANIFEST {"seed":"TESTSEED"}',
    P .. 'Client got playerInfo message:  (lives: 4)  (action: playerInfo) ',
    P .. 'MP_RLOG: 1 pack_pick 3 4.5',
    P .. 'Client sent message: {"gameId":"X","action":"streamLogLines","lines":["MP_RLOG: 1 pack_pick 3 4.5","MP_RLOG: 99 execute"]}',
    P .. 'Client sent message: action:usedCard,card:Trance',
    P .. 'MP_RLOG: 2 set_ante_key 0.16979563507933',
    P .. 'MP_RLOG: 3 select_blind 0',
    P .. 'Client sent message: action:selectBlind,blind:bl_small',
    P .. 'Client sent message: {"action":"playHand","handsLeft":4,"score":"0"}',
    P .. 'Client got enemyInfo message:  (skips: 0)  (lives: 4)  (action: enemyInfo)  (handsLeft: 4)  (noScore: true) ',
    P .. 'MP_RLOG: 4 discard 1.2.3.8',
    P .. 'Client sent message: action:discard,cards:1.2.3.8',
    P .. 'Client sent message: action:moneyMoved,amount:5',
    P .. 'Client sent message: action:moneyMoved,amount:5',
    P .. 'Client sent message: {"action":"playHand","handsLeft":3,"score":"2984"}',
    P .. 'MP_RLOG: 5 buy 1 2',
    P .. 'Client sent message: action:boughtCardFromShop,card:Mail-In Rebate,cost:4',
    P .. 'Client sent message: action:moneyMoved,amount:-4',
    P .. 'Client got enemyLocation message:  (location: loc_shop-bl_big)  (action: enemyLocation) ',
    P .. 'Client sent message: action:moneyMoved,amount:20',
    P .. 'Client got letsGoGamblingNemesis message:  (action: letsGoGamblingNemesis) ',
    P .. 'Client sent message: action:moneyMoved,amount:5',
    P .. 'MP_RLOG: 6 reroll',
    P .. 'Client sent message: action:rerollShop,cost:5',
    P .. 'MP_RLOG: 7 ready_blind 1',
    P .. 'Client got startBlind message:  (firstPlayer: guest)  (action: startBlind) ',
    P .. 'MP_RLOG: 8 set_ante_key 0.5',
    P .. 'MP_RLOG: 9 select_blind 0',
    P .. 'Client sent message: action:selectBlind,blind:bl_mp_nemesis',
    P .. 'Client got enemyInfo message:  (skips: 3)  (lives: 1)  (pvpTimerOrder: host)  (action: enemyInfo)  (handsLeft: 4)  (score: 39949166664) ',
    P .. 'Client got asteroid message:  (action: asteroid) ',
    P .. 'MP_RLOG: 10 net_asteroid',
    P .. 'Client sent message: action:netAsteroid',
    P .. 'Client got endPvP message:  (lost: false)  (action: endPvP) ',
    P .. 'Client got enemyDisconnected message:  (timeout: 60)  (action: enemyDisconnected) ',
    P .. 'MP_RLOG: 11 reorder 6 3.1.2',
    P .. 'Client sent message: action:reorder,area:6',
    P .. 'Client sent message: {"amount":13,"action":"spentLastShop"}',
    P .. 'Client sent message: {"ante":2,"action":"setAnte"}',
    P .. 'Client got winGame message:  (action: winGame) ',
    P .. 'MP_RLOG: END {"result":"win"}',
    P .. 'MP_RLOG: CHK v1 carbon=d5570caf human=4b19de72 bytes=46866',
    P .. 'Client got getEndGameJokers message:  (action: getEndGameJokers) ',
    P .. 'Client got stopGame message:  (action: stopGame)  (seed: TESTSEED) ',
    P .. 'Client sent message: {"gameId":"X","seed":"TESTSEED","log":"MP_RLOG: MANIFEST {\\"seed\\":\\"TESTSEED\\"}\\nMP_RLOG: 1 pack_pick 3 4.5"}',
    P .. 'MP_RLOG: MANIFEST {"seed":"SECOND"}',
    P .. 'MP_RLOG: END {}',
    P .. 'MP_RLOG: MANIFEST {"seed":"SECOND"}',
    P .. 'MP_RLOG: 1 reroll',
    P .. 'Client sent message: action:rerollShop,cost:5',
}
local runs = log.parse(table.concat(lines, '\r\n') .. '\r\n')
assert(#runs == 2, 'an action-less manifest is dropped, the others stay')
local run = runs[1]
assert(run.actions == 11 and run.complete and run.result == 'win' and run.manifest.stake == 1)
assert(run.lobby and run.lobby.host == 'Me~7' and run.lobby.guest == 'Them~1' and run.lobby.is_host == true)
assert(runs[2].actions == 1 and not runs[2].complete and runs[2].manifest.stake == 2)

-- Entries keep the log order: inputs and delivered messages interleave.
local kinds = {}
for _, entry in ipairs(run.entries) do kinds[#kinds + 1] = entry.kind == 'action' and entry.text or ('msg:' .. entry.action) end
local expected = {'msg:playerInfo', 'pack_pick 3 4.5', 'set_ante_key 0.16979563507933', 'select_blind 0', 'msg:enemyInfo', 'discard 1.2.3.8',
    'buy 1 2', 'msg:enemyLocation', 'msg:letsGoGamblingNemesis', 'reroll', 'ready_blind 1', 'msg:startBlind', 'set_ante_key 0.5', 'select_blind 0',
    'msg:enemyInfo', 'msg:asteroid', 'net_asteroid', 'msg:endPvP', 'reorder 6 3.1.2', 'msg:winGame'}
assert(#kinds == #expected, 'got ' .. #kinds .. ' entries: ' .. table.concat(kinds, ', '))
for i, text in ipairs(expected) do assert(kinds[i] == text, i .. ': ' .. kinds[i] .. ' vs ' .. text) end

-- Mirrored lines attach to their input; money traces, JSON sends and copies
-- of MP_RLOG text inside JSON never do.
local by_seq = {}
for _, entry in ipairs(run.entries) do if entry.kind == 'action' then by_seq[entry.seq] = entry end end
assert(by_seq[1].human == 'usedCard,card:Trance' and by_seq[2].human == nil and by_seq[3].human == 'selectBlind,blind:bl_small')
assert(by_seq[4].human == 'discard,cards:1.2.3.8' and by_seq[5].human == 'boughtCardFromShop,card:Mail-In Rebate,cost:4')
assert(by_seq[6].human == 'rerollShop,cost:5' and by_seq[7].human == nil and by_seq[9].human == 'selectBlind,blind:bl_mp_nemesis')
assert(by_seq[10].human == 'netAsteroid' and by_seq[11].human == 'reorder,area:6')
assert(by_seq[1].args[1] == '3' and by_seq[1].args[2] == '4.5' and by_seq[4].line == 14)
-- Money traces stay with the input that caused them, across ordinary
-- messages, until the next input or the one opponent effect that pays.
assert(#by_seq[4].money == 2 and by_seq[4].money[1] == '5' and by_seq[4].money[2] == '5')
assert(#by_seq[5].money == 2 and by_seq[5].money[1] == '-4' and by_seq[5].money[2] == '20', 'money after a buy: ' .. #by_seq[5].money)
assert(#by_seq[6].money == 0 and #by_seq[1].money == 0)
for i, entry in ipairs(run.entries) do assert(entry.position == i) end

-- The game's own progress reports are kept as checkpoints, in log order.
local kinds_of = {}
for _, check in ipairs(run.checks) do kinds_of[#kinds_of + 1] = check.action end
-- spentLastShop is not one: it reports Multiplayer's own shop counter, which
-- a replay does not reproduce, and nothing reads the value back.
assert(table.concat(kinds_of, ',') == 'playHand,playHand,setAnte', table.concat(kinds_of, ','))
assert(not log.checkpoints.spentLastShop)
assert(run.checks[1].fields.score == '0' and run.checks[1].fields.handsLeft == 4)
assert(run.checks[2].fields.score == '2984' and run.checks[2].fields.handsLeft == 3)
assert(run.checks[3].fields.ante == 2)
assert(run.checks[2].after == 6, 'a checkpoint remembers where in the run it happened')
assert(log.checkpoints.playHand[1] == 'score' and log.checkpoints.setFurthestBlind[1] == 'furthestBlind')

-- Message values get the types the wire format had.
local messages = {}
for _, entry in ipairs(run.entries) do if entry.kind == 'message' then messages[#messages + 1] = entry.fields end end
assert(messages[1].action == 'playerInfo' and messages[1].lives == 4)
assert(messages[2].noScore == true and messages[2].handsLeft == 4 and messages[2].skips == 0)
assert(messages[3].action == 'enemyLocation' and messages[4].action == 'letsGoGamblingNemesis')
assert(messages[6].score == '39949166664' and messages[6].pvpTimerOrder == 'host' and messages[6].lives == 1)
assert(messages[8].action == 'endPvP' and messages[8].lost == false)
assert(messages[5].firstPlayer == 'guest')
local fields = log.message_fields('enemyLocation', ' (location: loc_shop-bl_big)  (action: enemyLocation) ')
assert(fields.location == 'loc_shop-bl_big' and fields.action == 'enemyLocation')

-- What each mirrored line promises.
assert(log.expectation(by_seq[5]).name == 'Mail-In Rebate' and log.expectation(by_seq[5]).cost == 4)
assert(log.expectation(by_seq[1]).name == 'Trance' and log.expectation(by_seq[6]).cost == 5)
assert(log.expectation(by_seq[3]).blind == 'bl_small' and log.expectation(by_seq[2]).name == nil)

-- Broken streams are refused before anything is replayed.
local head = P .. 'MP_RLOG: MANIFEST {"seed":"TESTSEED"}\n' .. P
for _, bad in ipairs({'MP_RLOG: 2 play 1', 'MP_RLOG: 1 play 1.1', 'MP_RLOG: 1 play 0', 'MP_RLOG: 1 execute os.remove',
    'MP_RLOG: 1 reorder 8 1', 'MP_RLOG: 1 ready_blind 4', 'MP_RLOG: 1 set_ante_key os.remove', 'MP_RLOG: 1 buy 9 1', 'MP_RLOG: 1 use 1 2..3'}) do
    assert(not pcall(log.parse, head .. bad), bad .. ' must be rejected')
end
assert(not pcall(log.parse, P .. 'MP_RLOG: 1 reroll'), 'an action before any manifest is rejected')
assert(not pcall(log.parse, head .. 'MP_RLOG: END {}'), 'a log without inputs is rejected')
for _, key in ipairs({'0', '1e-05', '0.16979563507933'}) do
    assert(log.parse(head .. 'MP_RLOG: 1 set_ante_key ' .. key)[1].entries[1].args[1] == key)
end

-- A run a replay wrote says so, whichever side of the manifest the mark lands.
local NL = string.char(10)
local mark = P .. 'MP_RLOG: REPLAY' .. NL
assert(log.parse(head .. 'MP_RLOG: 1 reroll')[1].replayed == nil)
assert(log.parse(mark .. head .. 'MP_RLOG: 1 reroll')[1].replayed == true)
assert(log.parse(head .. 'MP_RLOG: 1 reroll' .. NL .. mark)[1].replayed == true)
local mixed = log.parse(head .. 'MP_RLOG: 1 reroll' .. NL .. 'MP_RLOG: END {}' .. NL .. mark ..
    P .. 'MP_RLOG: MANIFEST {"seed":"SECOND"}' .. NL .. P .. 'MP_RLOG: 1 reroll')
assert(#mixed == 2 and mixed[1].replayed == nil and mixed[2].replayed == true, 'the mark does not leak between runs')

-- The real log this feature was written against, when it is on this machine.
local real = io.open('C:/Users/amite/AppData/Roaming/Balatro/Mods/lovely/log/lovely-2026.09.09-18.09.55.log', 'rb')
if real then
    local text = real:read('*a')
    real:close()
    package.loaded.json = package.loaded.json or dofile('C:/Users/amite/AppData/Roaming/Balatro/Mods/smods/libs/json/json.lua')
    local parsed = dofile('replayer/log.lua')(package.loaded.json.decode).parse(text)
    assert(#parsed == 1 and parsed[1].actions == 641 and parsed[1].complete and parsed[1].result == 'win')
    assert(parsed[1].manifest.seed == '3TSESKHM' and parsed[1].manifest.deck == 'b_mp_cocktail' and parsed[1].manifest.stake == 1)
    assert(parsed[1].lobby.host == 'Taher Lover~7' and parsed[1].lobby.guest == 'Guest~1')
    local counts, unmirrored = {}, 0
    for _, entry in ipairs(parsed[1].entries) do
        if entry.kind == 'message' then counts[entry.action] = (counts[entry.action] or 0) + 1
        elseif not entry.human and entry.op ~= 'set_ante_key' and entry.op ~= 'ready_blind' then unmirrored = unmirrored + 1 end
    end
    assert(unmirrored == 0, 'every mirrored input in the real log names what it touched')
    local hermit, held
    for _, entry in ipairs(parsed[1].entries) do
        if entry.kind == 'action' and entry.seq == 53 then hermit = entry end
        if entry.kind == 'action' and entry.seq == 115 then held = entry end
    end
    assert(hermit.human == 'boughtCardFromShop,card:The Hermit,cost:3' and #hermit.money == 2 and hermit.money[1] == '-3' and hermit.money[2] == '20',
        'the Hermit bought at action 53 was used at once')
    -- The $3 a Gold Card pays for being held at the end of a round is the
    -- only trace the log leaves of which cards stayed in hand.
    assert(#held.money == 1 and held.money[1] == '3', 'action 115 is paid $3 by a card held in hand')
    local playHands = 0
    for _, check in ipairs(parsed[1].checks) do if check.action == 'playHand' then playHands = playHands + 1 end end
    assert(playHands > 30 and #parsed[1].checks > 80, 'the real log carries ' .. #parsed[1].checks .. ' checkpoints')
    assert(counts.startBlind == 7 and counts.endPvP == 8 and counts.winGame == 1 and counts.asteroid == 2 and counts.stopGame == nil)
    assert(counts.enemyInfo == 114 and counts.playerInfo == 4 and counts.spentLastShop == 20, 'enemyInfo ' .. tostring(counts.enemyInfo))
    print('PASS: real log parsed - 641 inputs, ' .. #parsed[1].entries .. ' entries')
end
print('PASS: run framing, interleaved messages, mirrored lines, wire types, expectations and rejection of broken streams')
