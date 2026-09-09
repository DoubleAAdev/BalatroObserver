-- Run from repository root: lua tests/test_observer.lua
local JSON = dofile('mod/json.lua')
local observer = dofile('mod/observer.lua')(JSON)
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
SMODS = {current_mod = {id = 'BalatroObserver', version = '1.4.1'}, load_file = function(file) return loadfile(file) end}
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
assert(BalatroObserver.version == '1.4.1')
assert(BalatroObserver.snapshot().mod_version == '1.4.1')
assert(writes['balatro_observer/state-1.json']:find('1.4.1', 1, true))
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

-- Remaining composition follows the visible unplayed viewer, not draw order.
G.STATE = G.STATES.SELECTING_HAND
a.area, b.area = G.deck, G.hand
b.ability.wheel_flipped = true
G.playing_cards = {a, b}
G.deck.cards = {a}
local remaining = observer.snapshot(G)
assert(#remaining.deck.remaining_cards == 2, 'wheel-flipped ambiguity lost')
assert(remaining.hand.cards[1].rank == nil)
local remaining_json = JSON.encode(remaining.deck.remaining_cards)
G.playing_cards = {b, a}
assert(JSON.encode(observer.snapshot(G).deck.remaining_cards) == remaining_json)
b.ability.wheel_flipped = nil
assert(#observer.snapshot(G).deck.remaining_cards == 1)
assert(observer.snapshot(G).deck.remaining_cards[1].rank == 'Ace')
assert(not remaining_json:find('slot') and not remaining_json:find('selected'))
G.localization = {descriptions = {
    Joker = {
        j_abstract = {text = {'{C:mult}+#1#{} Mult for each Joker card', '{C:inactive}(Currently +#2# Mult)'}},
        j_custom = {text = {'Custom effect #1#'}}
    },
    Blind = {bl_hook = {text = {'Discards {C:attention}2{} random cards per hand'}}}
}}
local abstract = {facing = 'front', config = {center = {key = 'j_abstract', name = 'Abstract Joker'}},
    ability = {set = 'Joker', extra = 3}}
G.jokers = {cards = {abstract, abstract, abstract, abstract}}
G.GAME.blind = {name = 'The Hook', loc_debuff_text = 'Discards 2 random cards per hand', disabled = false}
local descriptions = observer.snapshot(G)
assert(descriptions.jokers.cards[1].description == '+3 Mult for each Joker card (Currently +12 Mult)')
assert(descriptions.jokers.cards[1].description_complete)
assert(descriptions.blinds.boss.description == 'Discards 2 random cards per hand')
assert(descriptions.blind.loc_debuff_text == 'Discards 2 random cards per hand')
-- Current deck: Run Info text from public definition values; nothing else from the Back object.
G.localization.descriptions.Back = {
    b_black = {name = 'Black Deck', text = {'{C:attention}+#1#{} Joker slot', '', '{C:blue}-#2#{} hand', 'every round'}},
    b_magic = {name = 'Magic Deck', text = {'Start run with the', '{C:tarot,T:v_crystal_ball}#1#{} voucher', 'and {C:attention}2{} copies', 'of {C:tarot,T:c_fool}#2#'}}
}
G.localization.descriptions.Voucher = {v_crystal_ball = {name = 'Crystal Ball'}}
G.localization.descriptions.Tarot = {c_fool = {name = 'The Fool'}}
G.GAME.selected_back = {name = 'Black Deck', effect = {center = {key = 'b_black', name = 'Black Deck', set = 'Back',
    config = {hands = -1, joker_slot = 1}, secret = 'SECRET'}, config = {hands = -1, joker_slot = 1}}}
local deck = observer.snapshot(G)
assert(deck.run.deck_key == 'b_black' and deck.run.deck.name == 'Black Deck' and deck.run.deck.set == 'Back')
assert(deck.run.deck.description == '+1 Joker slot -1 hand every round', deck.run.deck.description)
assert(deck.run.deck.description_complete == true)
G.GAME.selected_back.effect.center = {key = 'b_magic', name = 'Magic Deck', set = 'Back', config = {voucher = 'v_crystal_ball'}}
assert(observer.snapshot(G).run.deck.description == 'Start run with the Crystal Ball voucher and 2 copies of The Fool')
G.GAME.selected_back.effect.center = {key = 'b_custom', name = 'Custom Deck', set = 'Back', config = {}}
deck = observer.snapshot(G)
assert(deck.run.deck.description == nil and deck.run.deck.name == 'Custom Deck')
assert(not JSON.encode(deck):find('SECRET'))
G.GAME.selected_back = nil
assert(observer.snapshot(G).run.deck == nil)
print('PASS: current deck name, effect text and placeholder values')
table.remove(G.jokers.cards)
assert(observer.snapshot(G).jokers.cards[1].description:find('+9 Mult', 1, true))
abstract.facing = 'back'
assert(observer.snapshot(G).jokers.cards[1].description == nil)
abstract.facing = 'front'
abstract.config.center.key = 'j_custom'
abstract.config.center.loc_vars = function() error('callback must not run') end
abstract.ability.extra = {secret = 'SECRET'}
local custom = observer.snapshot(G).jokers.cards[1]
assert(custom.description == 'Custom effect ?' and not custom.description_complete)
assert(not JSON.encode(custom):find('SECRET'))
print('PASS: remaining deck ambiguity, dynamic joker descriptions and boss text')

-- Round targets and money are public tooltip values; never read target card IDs.
G.localization.descriptions.Joker.j_mail = {text = {'Earn $#1# for each discarded #2#'}}
G.localization.descriptions.Joker.j_gros_michel = {text = {'+#1# Mult, #2# in #3# chance'}}
G.localization.descriptions.Joker.j_bull = {text = {'+#1# Chips per dollar (Currently +#2#)'}}
G.GAME.current_round.mail_card = {rank = 'Queen', id = 'SECRET'}
G.GAME.probabilities = {normal = 2, seed = 'SECRET'}
abstract.config.center.key = 'j_mail'
abstract.ability.extra = 5
assert(observer.snapshot(G).jokers.cards[1].description == 'Earn $5 for each discarded Queen')
G.GAME.current_round.mail_card.rank = 'Ace'
assert(observer.snapshot(G).jokers.cards[1].description == 'Earn $5 for each discarded Ace')
G.GAME.current_round.mail_card.rank = nil
assert(not observer.snapshot(G).jokers.cards[1].description_complete)
abstract.config.center.key = 'j_gros_michel'
abstract.ability.extra = {mult = 15, odds = 6, secret = 'SECRET'}
assert(observer.snapshot(G).jokers.cards[1].description == '+15 Mult, 2 in 6 chance')
assert(not JSON.encode(observer.snapshot(G)):find('SECRET'))
abstract.config.center.key = 'j_bull'
abstract.ability.extra = 2
G.GAME.dollars = 17
assert(observer.snapshot(G).jokers.cards[1].description == '+2 Chips per dollar (Currently +34)')
G.GAME.dollars = -4
assert(observer.snapshot(G).jokers.cards[1].description == '+2 Chips per dollar (Currently +0)')
G.GAME.dollars = {secret = 'SECRET'}
assert(not observer.snapshot(G).jokers.cards[1].description_complete)
abstract.facing = 'back'
assert(observer.snapshot(G).jokers.cards[1].description == nil)
print('PASS: changing Mail-In Rebate target, payout, Gros Michel odds, Bull totals and scalar privacy')

-- Nested Lua field identifiers can include underscores (the previous parser lost them).
abstract.facing = 'front'
for _, fixture in ipairs({
    {'j_wee', {chips=40,chip_mod=8}, '+#2# per 2; currently +#1#', '+8 per 2; currently +40'},
    {'j_greedy_joker', {s_mult=3,suit='Diamonds'}, '+#1# Mult for #2#', '+3 Mult for Diamonds'},
    {'j_runner', {chips=30,chip_mod=15}, '+#2# per Straight; currently +#1#', '+15 per Straight; currently +30'},
    {'j_green_joker', {hand_add=1,discard_sub=1}, '+#1# per hand; -#2# per discard', '+1 per hand; -1 per discard'},
    {'j_mystic_summit', {mult=15,d_remaining=0}, '+#1# with #2# discards', '+15 with 0 discards'}
}) do
    abstract.config.center.key = fixture[1]
    abstract.ability.extra = fixture[2]
    G.localization.descriptions.Joker[fixture[1]] = {text={fixture[3]}}
    local exported = observer.snapshot(G).jokers.cards[1]
    assert(exported.description == fixture[4], exported.description)
    assert(exported.description_complete)
end
abstract.config.center.key = 'j_wee'
abstract.ability.extra = {chips=40,chip_mod={secret='SECRET'}}
assert(not observer.snapshot(G).jokers.cards[1].description_complete)
assert(not JSON.encode(observer.snapshot(G)):find('SECRET'))
print('PASS: underscore fields resolve Wee, suit jokers, Runner, Green Joker and Mystic Summit; non-scalars remain private')

abstract.config.center.key = 'j_diet_cola'
G.localization.descriptions.Joker.j_diet_cola = {text={'Sell to create a #1#'}}
G.localization.descriptions.Tag = {tag_double={name='Double Tag'}}
local diet = observer.snapshot(G).jokers.cards[1]
assert(diet.description=='Sell to create a Double Tag' and diet.description_complete)
assert(diet.score_vars['1']=='Double Tag')
abstract.facing='back'
assert(observer.snapshot(G).jokers.cards[1].score_vars==nil)
abstract.facing='front'
local playing=card('Ace')
playing.ability.perma_bonus=17
G.hand.cards={playing};G.GAME.selected_back={effect={center={key='b_plasma',seed='SECRET'}}}
local score=observer.snapshot(G)
assert(score.hand.cards[1].perma_bonus==17 and score.run.deck_key=='b_plasma')
assert(not JSON.encode(score):find('SECRET'))
playing.facing='back'
assert(observer.snapshot(G).hand.cards[1].perma_bonus==nil)
print('PASS: Diet Cola tag, score variables and permanent chips are visible-only')
