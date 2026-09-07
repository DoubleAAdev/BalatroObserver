-- Explicit allowlists only: never bulk-copy G.GAME, ability.extra, RNG or MP tables.
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
    -- Render localization text without invoking tooltip, RNG, or mod callbacks.
    -- Only explicitly reviewed per-joker scalar fields may fill dynamic variables.
    local joker_fields = {
        j_joker={'mult'}, j_jolly={'t_mult','type'}, j_zany={'t_mult','type'},
        j_mad={'t_mult','type'}, j_crazy={'t_mult','type'}, j_droll={'t_mult','type'},
        j_sly={'t_chips','type'}, j_wily={'t_chips','type'}, j_clever={'t_chips','type'},
        j_devious={'t_chips','type'}, j_crafty={'t_chips','type'},
        j_half={'extra.mult','extra.size'}, j_chaos={'extra'}, j_drunkard={'d_size'},
        j_green_joker={'extra.hand_add','extra.discard_sub','mult'}, j_credit_card={'extra'},
        j_greedy_joker={'extra.s_mult','extra.suit'}, j_lusty_joker={'extra.s_mult','extra.suit'},
        j_wrathful_joker={'extra.s_mult','extra.suit'}, j_gluttenous_joker={'extra.s_mult','extra.suit'},
        j_faceless={'extra.dollars','extra.faces'}, j_juggler={'h_size'}, j_golden={'extra'},
        j_stencil={'x_mult'}, j_ceremonial={'mult'}, j_banner={'extra'},
        j_mystic_summit={'extra.mult','extra.d_remaining'}, j_fibonacci={'extra'}, j_scary_face={'extra'},
        j_delayed_grat={'extra'}, j_even_steven={'extra'}, j_odd_todd={'extra'},
        j_scholar={'extra.mult','extra.chips'}, j_superposition={'extra'},
        j_ride_the_bus={'extra','mult'}, j_egg={'extra'}, j_burglar={'extra'},
        j_runner={'extra.chips','extra.chip_mod'}, j_ice_cream={'extra.chips','extra.chip_mod'},
        j_dna={'extra'}, j_constellation={'extra','x_mult'}, j_hiker={'extra'},
        j_todo_list={'extra.dollars','to_do_poker_hand'}, j_astronomer={'extra'},
        j_ticket={'extra'}, j_acrobat={'extra'}, j_swashbuckler={'mult'},
        j_certificate={'extra'}, j_throwback={'extra','x_mult'}, j_hanging_chad={'extra'},
        j_duo={'x_mult','type'}, j_trio={'x_mult','type'}, j_family={'x_mult','type'},
        j_order={'x_mult','type'}, j_tribe={'x_mult','type'}, j_card_sharp={'extra.Xmult'},
        j_red_card={'extra','mult'}, j_madness={'extra','x_mult'},
        j_square={'extra.chips','extra.chip_mod'}, j_seance={'extra.poker_hand'},
        j_riff_raff={'extra'}, j_vampire={'extra','x_mult'}, j_hologram={'extra','x_mult'},
        j_vagabond={'extra'}, j_baron={'extra'}, j_rocket={'extra.dollars','extra.increase'},
        j_obelisk={'extra','x_mult'}, j_photograph={'extra'}, j_gift={'extra'},
        j_turtle_bean={'extra.h_size','extra.h_mod'}, j_to_the_moon={'extra'},
        j_lucky_cat={'extra','x_mult'}, j_baseball={'extra'}, j_trading={'extra'},
        j_flash={'extra','mult'}, j_popcorn={'mult','extra'}, j_ramen={'x_mult','extra'},
        j_walkie_talkie={'extra.chips','extra.mult'}, j_selzer={'extra'}, j_smiley={'extra'},
        j_campfire={'extra','x_mult'}, j_stuntman={'extra.chip_mod','extra.h_size'},
        j_invisible={'extra','invis_rounds'}, j_shoot_the_moon={'extra'},
        j_drivers_license={'extra','driver_tally'}, j_caino={'extra','caino_xmult'},
        j_triboulet={'extra'}, j_yorick={'extra.xmult','extra.discards','yorick_discards','x_mult'},
        j_perkeo={'extra'}, j_rough_gem={'extra'}, j_arrowhead={'extra'}, j_onyx_agate={'extra'},
        j_glass={'extra','x_mult'}, j_flower_pot={'extra'}, j_wee={'extra.chips','extra.chip_mod'},
        j_merry_andy={'d_size','h_size'}, j_seeing_double={'extra'}, j_matador={'extra'},
        j_hit_the_road={'extra','x_mult'}
    }
    local function description(G, set, key, vars)
        local item = (((G.localization or {}).descriptions or {})[set] or {})[key]
        if type(item) ~= 'table' then return nil, false end
        local lines, complete = {}, true
        for _, line in ipairs(type(item.text) == 'table' and item.text or {}) do
            if type(line) == 'string' then
                line = line:gsub('{[^}]*}', ''):gsub('#(%d+)#', function(index)
                    local v = scalar((vars or {})[tonumber(index)])
                    if v == nil then complete = false; return '?' end
                    return tostring(v)
                end)
                lines[#lines + 1] = line
            end
        end
        return #lines > 0 and table.concat(lines, ' ') or nil, complete
    end
    local function joker_description(G, c)
        local a, key = c.ability or {}, ((c.config or {}).center or {}).key
        local vars = {}
        for i, path in ipairs(joker_fields[key] or {}) do
            local parent, child = path:match('^(%w+)%.(%w+)$')
            vars[i] = scalar(parent and type(a[parent]) == 'table' and a[parent][child] or (not parent and a[path] or nil))
        end
        local n = type(a.extra) == 'number' and scalar(a.extra) or nil
        local game = G.GAME or {}
        local round = game.current_round or {}
        local extra = type(a.extra) == 'table' and a.extra or {}
        local probability = scalar((game.probabilities or {}).normal)
        -- These are the scalar values used by vanilla's visible tooltip definitions.
        -- Do not invoke loc_vars or calculate callbacks from installed mods.
        if key == 'j_mail' then vars = {n, scalar((round.mail_card or {}).rank)}
        elseif key == 'j_gros_michel' then vars = {scalar(extra.mult), probability, scalar(extra.odds)}
        elseif key == 'j_cavendish' then vars = {scalar(extra.Xmult), probability, scalar(extra.odds)}
        elseif key == 'j_space' or key == 'j_8_ball' or key == 'j_business' or key == 'j_hallucination' then vars = {probability, n}
        elseif key == 'j_reserved_parking' then vars = {scalar(extra.dollars), probability, scalar(extra.odds)}
        elseif key == 'j_bloodstone' then vars = {probability, scalar(extra.odds), scalar(extra.Xmult)}
        elseif key == 'j_ancient' then vars = {n, scalar((round.ancient_card or {}).suit)}
        elseif key == 'j_castle' then vars = {scalar(extra.chip_mod), scalar((round.castle_card or {}).suit), scalar(extra.chips)}
        elseif key == 'j_idol' then vars = {n, scalar((round.idol_card or {}).rank), scalar((round.idol_card or {}).suit)}
        elseif key == 'j_bull' then
            local dollars = scalar(game.dollars)
            vars = {n, type(dollars) == 'number' and n and n * math.max(0, dollars) or nil}
        elseif key == 'j_bootstraps' then
            local mult, dollars, money = scalar(extra.mult), scalar(extra.dollars), scalar(game.dollars)
            local buffer = scalar(game.dollar_buffer) or 0
            vars = {mult, dollars, type(mult) == 'number' and type(dollars) == 'number' and dollars > 0 and type(money) == 'number' and type(buffer) == 'number' and mult * math.floor((money + buffer)/dollars) or nil}
        elseif key == 'j_erosion' then
            local size = scalar(game.starting_deck_size)
            vars = {n, type(size) == 'number' and n and math.max(0,n*(size-#(G.playing_cards or {}))) or nil, size}
        elseif key == 'j_troubadour' then vars = {scalar(extra.h_size), type(extra.h_plays) == 'number' and -extra.h_plays or nil}
        elseif key == 'j_loyalty_card' then
            local remaining, every = scalar(a.loyalty_remaining), scalar(extra.every)
            vars = {scalar(extra.Xmult), type(every) == 'number' and every + 1 or nil, remaining == 0 and 'Active!' or (remaining and tostring(remaining)..' hands remaining' or nil)}
        elseif key == 'j_satellite' then
            local count = 0
            for _, used in pairs(game.consumeable_usage or {}) do if type(used) == 'table' and used.set == 'Planet' then count = count + 1 end end
            vars = {n, n and count*n}
        end
        if key == 'j_abstract' then vars = {n, n and n * #((G.jokers or {}).cards or {})}
        elseif key == 'j_blue_joker' then vars = {n, n and n * #((G.deck or {}).cards or {})}
        elseif key == 'j_fortune_teller' then vars = {n, scalar(((G.GAME or {}).consumeable_usage_total or {}).tarot)}
        elseif key == 'j_steel_joker' then vars = {n, n and 1 + n * (scalar(a.steel_tally) or 0)}
        elseif key == 'j_stone' then vars = {n, n and n * (scalar(a.stone_tally) or 0)}
        elseif key == 'j_cloud_9' then vars = {n, n and n * (scalar(a.nine_tally) or 0)}
        elseif key == 'j_hack' or key == 'j_dusk' or key == 'j_sock_and_buskin' then vars = {n and n + 1}
        elseif key == 'j_blackboard' then vars = {n, 'Spades', 'Clubs'}
        elseif key == 'j_trousers' then vars = {n, 'Two Pair', scalar(a.mult)}
        end
        return description(G, 'Joker', key, vars)
    end
    local function card(c, roster, G)
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
            if ability.set == 'Joker' and G then
                out.name = scalar(center.name)
                out.description, out.description_complete = joker_description(G, c)
            end
            out.debuff = c.debuff == true
            out.selected = c.highlighted == true
            out.cost, out.sell_cost = scalar(c.cost), scalar(c.sell_cost)
            out.stickers = fields(ability, {'eternal', 'perishable', 'rental', 'perish_tally'})
        end
        return out
    end
    local function area(a, G)
        local out = {cards = JSON.array(), capacity = scalar(((a or {}).config or {}).card_limit)}
        for i, c in ipairs((a or {}).cards or {}) do
            out.cards[i] = card(c, false, G)
            out.cards[i].slot = i -- Only current visible area positions, never persistent IDs.
        end
        return out
    end
    -- Match the current-ante blind screen and Run Info voucher pool.
    -- Read existing public definitions only; never call tag constructors or blind rollers.
    local function run_info(G, game)
        local resets = game.round_resets or {}
        local blinds = {choices = JSON.array(), on_deck = scalar(game.blind_on_deck)}
        for _, slot in ipairs({'Small', 'Big', 'Boss'}) do
            local key = (resets.blind_choices or {})[slot]
            local definition = (G.P_BLINDS or {})[key]
            if type(key) == 'string' and type(definition) == 'table' then
                local entry = fields(definition, {'name', 'mult', 'dollars'})
                entry.key, entry.slot = key, slot
                local vars = type(definition.vars) == 'table' and definition.vars or nil
                if key == 'bl_ox' then vars = {scalar((game.current_round or {}).most_played_poker_hand)} end
                entry.description, entry.description_complete = description(G, 'Blind', key, vars)
                entry.status = scalar((resets.blind_states or {})[slot])
                if slot ~= 'Boss' and not definition.unskippable then
                    local tag_key = (resets.blind_tags or {})[slot]
                    local tag = (G.P_TAGS or {})[tag_key]
                    if type(tag_key) == 'string' and type(tag) == 'table' then
                        entry.skip_tag = {key = tag_key, name = scalar(tag.name)}
                    end
                end
                blinds.choices[#blinds.choices + 1] = entry
                if slot == 'Boss' then blinds.boss = entry end
                if not blinds.next and (entry.status == 'Select' or entry.status == 'Upcoming') then
                    blinds.next = entry
                end
            end
        end
        local vouchers = JSON.array()
        for _, definition in ipairs((G.P_CENTER_POOLS or {}).Voucher or {}) do
            local key = definition.key
            if type(key) == 'string' and (game.used_vouchers or {})[key] then
                vouchers[#vouchers + 1] = {key = key, name = scalar(definition.name), set = 'Voucher', visible = true}
            end
        end
        return blinds, vouchers
    end
    local allowed = {'SELECTING_HAND', 'SHOP', 'BLIND_SELECT', 'ROUND_EVAL',
        'TAROT_PACK', 'PLANET_PACK', 'SPECTRAL_PACK', 'STANDARD_PACK', 'BUFFOON_PACK', 'SMODS_BOOSTER_OPENED', 'GAME_OVER'}
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
        result.blinds, result.vouchers = run_info(G, game)
        result.run = fields(game, {'dollars', 'chips', 'round', 'stake'})
        result.round = fields(game.current_round, {'hands_left', 'discards_left', 'hands_played', 'discards_used'})
        result.round.ante = scalar((game.round_resets or {}).ante)
        result.blind = fields(game.blind, {'name', 'chips', 'dollars', 'disabled', 'loc_debuff_text'})
        result.hand, result.jokers, result.consumables = area(G.hand, G), area(G.jokers, G), area(G.consumeables, G)
        result.deck = {cards = JSON.array(), remaining_cards = JSON.array(), draw_count = #((G.deck or {}).cards or {}),
            discard_count = #((G.discard or {}).cards or {}), order = 'canonical_multiset'}
        -- Match the public unplayed deck viewer, including wheel-flipped ambiguity.
        -- Neither list contains draw order, IDs, or links to hidden hand slots.
        local entries, remaining = {}, {}
        for _, c in ipairs(G.playing_cards or {}) do
            local public = card(c, true)
            entries[#entries + 1] = {key = JSON.encode(public), value = public}
            if (G.deck and c.area == G.deck) or (c.ability or {}).wheel_flipped then
                remaining[#remaining + 1] = {key = JSON.encode(public), value = public}
            end
        end
        table.sort(entries, function(a, b) return a.key < b.key end)
        for i, entry in ipairs(entries) do result.deck.cards[i] = entry.value end
        table.sort(remaining, function(a, b) return a.key < b.key end)
        for i, entry in ipairs(remaining) do result.deck.remaining_cards[i] = entry.value end
        result.deck.remaining_kind = 'public_unplayed_including_unknown_discards'
        result.poker_hands = {}
        for name, hand in pairs(game.hands or {}) do
            if hand.visible == true then
                result.poker_hands[name] = fields(hand, {'level', 'chips', 'mult', 'played', 'played_this_round'})
            end
        end
        if phase == 'SHOP' then
            result.shop = {cards = area(G.shop_jokers, G), vouchers = area(G.shop_vouchers, G),
                boosters = area(G.shop_booster, G), reroll_cost = scalar(game.current_round.reroll_cost)}
        end
        if phase:match('_PACK$') or phase == 'SMODS_BOOSTER_OPENED' then
            result.pack = {cards = area(G.pack_cards, G), choices_left = scalar(game.pack_choices)}
        end
        return result
    end
    return M
end
