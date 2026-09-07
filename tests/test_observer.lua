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
SMODS = {current_mod = {id = 'BalatroObserver', version = '0.3.0'}, load_file = function(file) return loadfile(file) end}
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
assert(BalatroObserver.version == '0.3.0')
assert(BalatroObserver.snapshot().mod_version == '0.3.0')
assert(writes['balatro_observer/state-1.json']:find('0.3.0', 1, true))
fail = true
Game:update(0.2)
assert(not BalatroObserver.last_export_ok and called == 4)
print('PASS: observation privacy, phase gating, JSON and export hook')
-- Player-visible checklist coverage uses the same registries as the game UI.
G.STATE_COMPLETE = true
G.STATE = G.STATES.SHOP
G.GAME.round_resets = {
    blind_choices = {Small = 'bl_small', Big = 'bl_big', Boss = 'bl_hook'},
    blind_states = {Small = 'Current', Big = 'Upcoming', Boss = 'Upcoming'},
    blind_tags = {Small = 'tag_double', Big = 'tag_coupon'}
}
G.P_BLINDS = {
    bl_small = {name = 'Small Blind', mult = 1, dollars = 3, secret = 'SECRET'},
    bl_big = {name = 'Big Blind', mult = 1.5, dollars = 4},
    bl_hook = {name = 'The Hook', mult = 2, dollars = 5, callback = function() error('must not run') end}
}
G.P_TAGS = {tag_double = {name = 'Double Tag'}, tag_coupon = {name = 'Coupon Tag'}}
G.P_CENTER_POOLS = {Voucher = {{key = 'v_overstock', name = 'Overstock'}, {key = 'v_clearance_sale', name = 'Clearance Sale'}}}
G.GAME.used_vouchers = {v_overstock = true, v_clearance_sale = false, secret = 'SECRET'}
local info = observer.snapshot(G)
assert(#info.blinds.choices == 3 and info.blinds.next.key == 'bl_big')
assert(info.blinds.boss.name == 'The Hook')
assert(info.blinds.choices[1].skip_tag.name == 'Double Tag')
assert(#info.vouchers == 1 and info.vouchers[1].key == 'v_overstock')
assert(not JSON.encode(info):find('SECRET'))
G.P_BLINDS.bl_small.unskippable = true
assert(observer.snapshot(G).blinds.choices[1].skip_tag == nil)
G.GAME.round_resets.blind_states.Big = 'Skipped'
assert(observer.snapshot(G).blinds.next.key == 'bl_hook')
G.STATES.SMODS_BOOSTER_OPENED = 999
G.STATES.TAROT_PACK = 4
G.pack_cards = {cards = {card('Ace'), card('King', 'back')}}
G.GAME.pack_choices = 1
for _, phase in ipairs({4, 999}) do
    G.STATE = phase
    local pack = observer.snapshot(G)
    assert(pack.available and #pack.pack.cards.cards == 2 and pack.pack.choices_left == 1)
    assert(pack.pack.cards.cards[2].rank == nil and pack.pack.cards.cards[2].visible == false)
end
G.STATE = G.STATES.SHOP
assert(observer.snapshot(G).pack == nil, 'unopened pack contents leaked')
G.SETTINGS = {paused = true}
assert(observer.snapshot(G).blinds == nil and observer.snapshot(G).vouchers == nil)
G.SETTINGS = nil
print('PASS: visible blinds, skip tags, vouchers, Steamodded packs and visibility guards')
