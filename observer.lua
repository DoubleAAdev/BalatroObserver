-- Explicit allowlists only: never copy G.GAME, ability.extra, RNG or MP tables.
return function(JSON)
    local M = {}
    local function scalar(v)
        if type(v) == 'string' or type(v) == 'boolean' then return v end
        if type(v) == 'number' and v == v and math.abs(v) ~= math.huge then return v end
    end
    local function fields(source, names)
        local out = {}
        for _, name in ipairs(names) do out[name] = scalar((source or {})[name]) end
        return out
    end
    local function card(c, roster)
        if not roster and c.facing ~= 'front' then return {visible = false} end
        local base, ability = c.base or {}, c.ability or {}
        local center = (c.config or {}).center or {}
        local out = {visible = true, key = scalar(center.key),
            set = scalar(ability.set), seal = scalar(c.seal)}
        -- Stone Cards do not display their underlying rank or suit.
        if center.key ~= 'm_stone' then
            out.rank, out.suit = scalar(base.value), scalar(base.suit)
        end
        out.edition = fields(c.edition, {'foil', 'holo', 'polychrome', 'negative'})
        if not roster then
            out.debuff = c.debuff == true
            out.selected = c.highlighted == true
            out.cost, out.sell_cost = scalar(c.cost), scalar(c.sell_cost)
            out.stickers = fields(ability, {'eternal', 'perishable', 'rental', 'perish_tally'})
        end
        return out
    end
    local function area(a)
        local out = {cards = JSON.array(), capacity = scalar(((a or {}).config or {}).card_limit)}
        for i, c in ipairs((a or {}).cards or {}) do
            out.cards[i] = card(c, false)
            out.cards[i].slot = i -- Only current visible area positions, never persistent IDs.
        end
        return out
    end
    local allowed = {'SELECTING_HAND', 'SHOP', 'BLIND_SELECT', 'ROUND_EVAL',
        'TAROT_PACK', 'PLANET_PACK', 'SPECTRAL_PACK', 'STANDARD_PACK', 'BUFFOON_PACK', 'GAME_OVER'}
    function M.snapshot(G)
        G = G or {}
        local phase = 'UNAVAILABLE'
        for _, name in ipairs(allowed) do
            if (G.STATES or {})[name] ~= nil and G.STATE == G.STATES[name] then phase = name end
        end
        local result = {schema_version = 1, phase = phase, available = false}
        -- Do not sample animations, overlays, paused games or partially initialized runs.
        if phase == 'UNAVAILABLE' or not G.STAGE or G.STAGE ~= (G.STAGES or {}).RUN
            or not G.STATE_COMPLETE or G.OVERLAY_MENU or (G.SETTINGS or {}).paused then return result end
        local game = G.GAME
        if not game or not game.current_round then return result end
        result.available = true
        result.run = fields(game, {'dollars', 'chips', 'round', 'stake'})
        result.round = fields(game.current_round, {'hands_left', 'discards_left', 'hands_played', 'discards_used'})
        result.round.ante = scalar((game.round_resets or {}).ante)
        result.blind = fields(game.blind, {'name', 'chips', 'dollars', 'disabled'})
        result.hand, result.jokers, result.consumables = area(G.hand), area(G.jokers), area(G.consumeables)
        result.deck = {cards = JSON.array(), draw_count = #((G.deck or {}).cards or {}),
            discard_count = #((G.discard or {}).cards or {}), order = 'canonical_multiset'}
        -- Full deck-view composition, not remaining-pile membership. Never traverse G.deck.cards.
        local entries = {}
        for _, c in ipairs(G.playing_cards or {}) do
            local public = card(c, true)
            entries[#entries + 1] = {key = JSON.encode(public), value = public}
        end
        table.sort(entries, function(a, b) return a.key < b.key end)
        for i, entry in ipairs(entries) do result.deck.cards[i] = entry.value end
        result.poker_hands = {}
        for name, hand in pairs(game.hands or {}) do
            if hand.visible == true then
                result.poker_hands[name] = fields(hand, {'level', 'chips', 'mult', 'played', 'played_this_round'})
            end
        end
        if phase == 'SHOP' then
            result.shop = {cards = area(G.shop_jokers), vouchers = area(G.shop_vouchers),
                boosters = area(G.shop_booster), reroll_cost = scalar(game.current_round.reroll_cost)}
        end
        if phase:match('_PACK$') then
            result.pack = {cards = area(G.pack_cards), choices_left = scalar(game.pack_choices)}
        end
        return result
    end
    return M
end
