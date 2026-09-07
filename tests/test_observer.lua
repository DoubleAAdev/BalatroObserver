-- Run from repository root: lua tests/test_observer.lua
local JSON = dofile('json.lua')
local observer = dofile('observer.lua')(JSON)
local function card(rank, facing)
    return {base = {value = rank, suit = 'Spades'}, facing = facing or 'front',
        config = {center = {key = 'c_base'}}, ability = {set = 'Default', extra = {seed = 'SECRET'}},
        sort_id = 891, playing_card = 932}
end
local a, b = card('Ace'), card('King', 'back')
local G = {STAGE = 1, STAGES = {RUN = 1}, STATE = 2, STATES = {SELECTING_HAND = 2, SHOP = 3},
    STATE_COMPLETE = true, GAME = {seed = 'SECRET', pseudorandom = {seed = 'SECRET'},
        current_round = {hands_left = 3, discards_left = 2}, hands = {}},
    hand = {cards = {b}}, playing_cards = {a, b}, deck = {cards = {a}},
    shop_jokers = {cards = {card('FUTURE')}}}
local state = observer.snapshot(G)
assert(state.available and state.round.hands_left == 3 and state.round.discards_left == 2)
assert(state.hand.cards[1].visible == false and state.hand.cards[1].rank == nil)
assert(state.deck.draw_count == 1 and #state.deck.cards == 2 and not state.shop)
local encoded = JSON.encode(state)
assert(not encoded:find('SECRET') and not encoded:find('FUTURE'))
assert(not encoded:find('sort_id') and not encoded:find('playing_card'))
G.playing_cards = {b, a}
assert(JSON.encode(observer.snapshot(G)) == encoded, 'roster order leaked')
G.deck.cards = {b} -- Membership must not affect the export, only count.
assert(JSON.encode(observer.snapshot(G)) == encoded, 'draw membership leaked')
G.STATE = 3
assert(observer.snapshot(G).shop.cards.cards[1].rank == 'FUTURE')
G.OVERLAY_MENU = {}
assert(not observer.snapshot(G).available)
G.OVERLAY_MENU = nil
G.STATE_COMPLETE = false
assert(not observer.snapshot(G).available)
assert(not observer.snapshot(nil).available)
assert(JSON.encode(JSON.array()) == '[]')
assert(JSON.encode({}) == '{}')
assert(JSON.encode('a\n"\\') == '"a\\u000a\\u0022\\u005c"')
local cycle = {}; cycle.x = cycle
assert(not pcall(JSON.encode, cycle))
assert(not pcall(JSON.encode, math.huge))

-- Exercise the actual update hook with fake SMODS and LÖVE objects.
_G.G = G
SMODS = {current_mod = {id = 'BalatroObserver'}, load_file = function(file) return loadfile(file) end}
local writes, called, fail = {}, 0, false
love = {timer = {getTime = function() return 1 end}, filesystem = {
    createDirectory = function() return true end,
    write = function(path, data) if fail then return nil end; writes[path] = data; return true end}}
Game = {update = function() called = called + 1 end}
dofile('main.lua')
Game:update(0.1)
assert(next(writes) == nil)
Game:update(0.1)
Game:update(0.2)
assert(called == 3 and writes['balatro_observer/state-0.json'] and writes['balatro_observer/state-1.json'])
assert(BalatroObserver.last_export_ok)
fail = true
Game:update(0.2)
assert(not BalatroObserver.last_export_ok and called == 4)
print('PASS: observation privacy, phase gating, JSON and export hook')
