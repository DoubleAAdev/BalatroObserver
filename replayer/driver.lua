-- Performs one logged input the way the player's click did: the same
-- highlight, the same can_* gate and the same G.FUNCS callback, so Action
-- Recorder and Multiplayer's own log hooks both see a real action.
--
-- Every function returns 'done' when the input was issued, or 'wait' with a
-- reason when the game is not ready for it yet. Anything that can never
-- become right (a different card in the slot, a cost that differs, a
-- selection the game refuses) raises an error, which ends the replay with
-- that message.
return function(log)
    local M = {}
    local areas = {'shop_jokers', 'shop_booster', 'shop_vouchers', 'jokers', 'consumeables', 'hand', 'pack_cards'}
    M.areas = areas

    local function state_name()
        for name, id in pairs(G.STATES or {}) do
            if G.STATE == id then return name end
        end
        return 'unknown state'
    end
    M.state_name = state_name

    local function in_pack()
        for _, name in ipairs({'SMODS_BOOSTER_OPENED', 'TAROT_PACK', 'PLANET_PACK', 'SPECTRAL_PACK', 'STANDARD_PACK', 'BUFFOON_PACK'}) do
            if G.STATES[name] and G.STATE == G.STATES[name] then return true end
        end
        return false
    end
    M.in_pack = in_pack

    -- A removed CardArea keeps its table in G with cards set to nil.
    local function cards_of(area)
        return type(area) == 'table' and area.cards or nil
    end

    local function card_name(card)
        return (card.ability or {}).name or ((card.config or {}).center or {}).key or '?'
    end

    local function describe(area_name, slot)
        local list = cards_of(G[area_name])
        if not list then return area_name .. ' is not open' end
        local card = list[slot]
        if not card then return area_name .. ' has ' .. #list .. ' card(s), no slot ' .. slot end
        return area_name .. ' slot ' .. slot .. ' holds ' .. card_name(card)
    end

    -- The card the log points at, checked by name before anything is done.
    local function card_at(area_name, slot, expected)
        local list = cards_of(G[area_name])
        local card = list and list[slot]
        if not card then return nil, describe(area_name, slot) end
        if expected and card_name(card) ~= expected then
            return nil, describe(area_name, slot) .. ', log says ' .. expected
        end
        return card
    end

    -- Ask one of the game's can_* checks whether the button would be live.
    local function probe(check, card, id)
        local e = {config = {ref_table = card, id = id}, UIBox = {states = {visible = true}, alignment = {offset = {}}}}
        assert(type(G.FUNCS[check]) == 'function', 'Missing game check ' .. check)
        G.FUNCS[check](e)
        return e, e.config.button
    end

    -- Select exactly the logged hand positions, keeping a boss blind's
    -- forced card without adding it twice.
    local function highlight(indices)
        local hand = G.hand
        local list = assert(cards_of(hand), 'the hand is not dealt')
        for _, i in ipairs(indices) do
            if not list[i] then error('the hand has ' .. #list .. ' card(s), the log selects slot ' .. i) end
        end
        hand:unhighlight_all()
        local chosen = {}
        for _, card in ipairs(hand.highlighted or {}) do chosen[card] = true end
        for _, i in ipairs(indices) do
            if not chosen[list[i]] then
                hand:add_to_highlighted(list[i], true)
                chosen[list[i]] = true
            end
        end
        local wanted = {}
        for _, i in ipairs(indices) do wanted[list[i]] = true end
        local count = 0
        for _, card in ipairs(hand.highlighted or {}) do
            count = count + 1
            if not wanted[card] then error('the game keeps a card selected that the log did not select') end
        end
        if count ~= #indices then error('the game accepted ' .. count .. ' of ' .. #indices .. ' selected cards') end
    end
    M.highlight = highlight

    -- Mirror of G.FUNCS.check_for_buy_space without its on-screen alert.
    local function has_buy_space(card)
        local set = (card.ability or {}).set
        if set == 'Voucher' or set == 'Enhanced' or set == 'Default' then return true end
        local extra = 1 + ((card.ability or {}).extra_slots_used or 0)
        local bonus = (card.ability or {}).card_limit or 0
        if set == 'Joker' then return #G.jokers.cards + extra <= G.jokers.config.card_limit + bonus end
        if (card.ability or {}).consumeable then
            return #G.consumeables.cards + extra <= G.consumeables.config.card_limit + bonus
        end
        return false
    end
    M.has_buy_space = has_buy_space

    -- Walk a UIBox the way the game builds it: elements hang off UIRoot and
    -- nested boxes sit in config.object.
    local function find_node(node, accept, seen)
        if type(node) ~= 'table' or seen[node] then return nil end
        seen[node] = true
        local config = node.config
        if config then
            if accept(config) then return node end
            local nested = config.object
            if type(nested) == 'table' and nested.UIRoot then
                local found = find_node(nested.UIRoot, accept, seen)
                if found then return found end
            end
        end
        if node.UIRoot then
            local found = find_node(node.UIRoot, accept, seen)
            if found then return found end
        end
        for _, child in pairs(node.children or {}) do
            local found = find_node(child, accept, seen)
            if found then return found end
        end
        return nil
    end
    M.find_node = find_node

    local function blind_panel()
        local slot = (G.GAME or {}).blind_on_deck
        return slot and (G.blind_select_opts or {})[tostring(slot):lower()], slot
    end

    local function blind_button(name)
        local panel, slot = blind_panel()
        if not panel then return nil, 'the ' .. tostring(slot) .. ' blind panel is not built yet' end
        local node = find_node(panel, function(config) return config.button == name end, {})
        if not node then return nil, 'no ' .. name .. ' button on the ' .. tostring(slot) .. ' blind' end
        return node
    end

    -- Transitions the log never records: Multiplayer logs neither the cash
    -- out button nor the shop's next-round button.
    local function leave_round_eval()
        if G.round_eval then G.FUNCS.cash_out({config = {}}) end
        return 'wait', 'cashing out'
    end
    local function leave_shop()
        G.FUNCS.toggle_shop({config = {}})
        return 'wait', 'leaving the shop'
    end

    local function state_is(name) return G.STATE == G.STATES[name] end

    local function hand_action(entry, check, callback)
        if state_is('ROUND_EVAL') then return leave_round_eval() end
        if not state_is('SELECTING_HAND') then return 'wait', 'not selecting a hand (' .. state_name() .. ')' end
        highlight(log.indices(entry.args[1]))
        local e, button = probe(check, nil)
        if button ~= callback then error('the game refuses to ' .. entry.op .. ' this selection') end
        G.FUNCS[callback](e)
        return 'done'
    end

    local function use_card(card, check, targets)
        if targets then highlight(log.indices(targets))
        elseif G.hand and cards_of(G.hand) and #(G.hand.highlighted or {}) > 0 then G.hand:unhighlight_all() end
        local e, button = probe(check, card)
        if button ~= 'use_card' then
            return nil, 'the game refuses to use ' .. card_name(card) .. ' now (' .. check .. ')'
        end
        G.FUNCS.use_card(e)
        return true
    end

    local function check_for(card)
        local set = (card.ability or {}).set
        if set == 'Booster' then return 'can_open' end
        if set == 'Voucher' then return 'can_redeem' end
        if (card.ability or {}).consumeable then return 'can_use_consumeable' end
        return 'can_select_card'
    end

    local handlers = {}

    handlers.play = function(entry) return hand_action(entry, 'can_play', 'play_cards_from_highlighted') end
    handlers.discard = function(entry) return hand_action(entry, 'can_discard', 'discard_cards_from_highlighted') end

    handlers.reroll = function(entry)
        if state_is('ROUND_EVAL') then return leave_round_eval() end
        if not state_is('SHOP') then return 'wait', 'the shop is not open (' .. state_name() .. ')' end
        local expected = log.expectation(entry).cost
        local cost = ((G.GAME or {}).current_round or {}).reroll_cost
        if expected and cost ~= expected then error('the reroll costs $' .. tostring(cost) .. ', the log paid $' .. expected) end
        local e, button = probe('can_reroll', nil)
        if button ~= 'reroll_shop' then error('the game refuses the reroll (not enough money)') end
        G.FUNCS.reroll_shop(e)
        return 'done'
    end

    handlers.buy = function(entry)
        if state_is('ROUND_EVAL') then return leave_round_eval() end
        if not state_is('SHOP') then return 'wait', 'the shop is not open (' .. state_name() .. ')' end
        local area_name = areas[tonumber(entry.args[1])]
        if not area_name or not area_name:match('^shop_') then error('buy from ' .. tostring(area_name) .. ' is not a shop purchase') end
        local want = log.expectation(entry)
        local card, why = card_at(area_name, tonumber(entry.args[2]), want.name)
        if not card then error(why) end
        if want.cost and card.cost ~= want.cost then
            error(card_name(card) .. ' costs $' .. tostring(card.cost) .. ', the log paid $' .. want.cost)
        end
        -- Multiplayer logs "Buy" and "Buy & Use" alike. A consumable bought
        -- with no free slot can only have been bought and used at once.
        local id, check = 'buy', 'can_buy'
        if not has_buy_space(card) then
            if (card.ability or {}).consumeable and card.can_use_consumeable and card:can_use_consumeable() then
                id, check = 'buy_and_use', 'can_buy_and_use'
            else
                error('no room to buy ' .. card_name(card))
            end
        end
        local e, button = probe(check, card, id)
        if button ~= 'buy_from_shop' then error('the game refuses to buy ' .. card_name(card) .. ' (not enough money)') end
        if G.FUNCS.buy_from_shop(e) == false then error('the game rejected buying ' .. card_name(card)) end
        return 'done'
    end

    handlers.sell = function(entry)
        local area_name = areas[tonumber(entry.args[1])]
        if area_name ~= 'jokers' and area_name ~= 'consumeables' then error('sell from ' .. tostring(area_name) .. ' is not possible') end
        local card, why = card_at(area_name, tonumber(entry.args[2]), log.expectation(entry).name)
        if not card then error(why) end
        if card.can_sell_card and not card:can_sell_card() then
            return 'wait', 'the game does not allow selling ' .. card_name(card) .. ' yet'
        end
        G.FUNCS.sell_card({config = {ref_table = card}})
        return 'done'
    end

    -- "use" names a slot but no area: consumables, shop packs and shop
    -- vouchers all go through use_card. The mirrored card name settles it.
    handlers.use = function(entry)
        local slot = tonumber(entry.args[1])
        local name = log.expectation(entry).name
        if not name then error('the log does not name the card used at slot ' .. slot) end
        local candidates = {'consumeables'}
        if state_is('SHOP') then candidates = {'consumeables', 'shop_booster', 'shop_vouchers'} end
        local card, area_name
        for _, candidate in ipairs(candidates) do
            local list = cards_of(G[candidate])
            local found = list and list[slot]
            if found and card_name(found) == name then
                if card then error(name .. ' sits in both ' .. area_name .. ' and ' .. candidate .. ' slot ' .. slot) end
                card, area_name = found, candidate
            end
        end
        if not card then
            if state_is('ROUND_EVAL') then return leave_round_eval() end
            if not state_is('SHOP') and not state_is('SELECTING_HAND') and not in_pack() and not state_is('BLIND_SELECT') then
                return 'wait', 'nothing to use in ' .. state_name()
            end
            local seen = {}
            for _, candidate in ipairs(candidates) do seen[#seen + 1] = describe(candidate, slot) end
            error('no ' .. name .. ' to use: ' .. table.concat(seen, '; '))
        end
        local ok, why = use_card(card, check_for(card), entry.args[2])
        if not ok then
            -- A shop pack stays closed while the player is marked ready.
            if area_name == 'consumeables' or (MP and MP.GAME and MP.GAME.ready_blind) then error(why) end
            return 'wait', why
        end
        return 'done'
    end
    handlers.pack_pick = function(entry)
        if not in_pack() or not cards_of(G.pack_cards) then return 'wait', 'no booster pack is open (' .. state_name() .. ')' end
        local slot = tonumber(entry.args[1])
        local list = cards_of(G.pack_cards)
        if not list[slot] then return 'wait', 'the pack shows ' .. #list .. ' card(s), the log picks slot ' .. slot end
        local card, why = card_at('pack_cards', slot, log.expectation(entry).name)
        if not card then error(why) end
        local ok, reason = use_card(card, check_for(card), entry.args[2])
        if not ok then error(reason) end
        return 'done'
    end

    handlers.pack_skip = function()
        if not in_pack() or not cards_of(G.pack_cards) then return 'wait', 'no booster pack is open (' .. state_name() .. ')' end
        local e, button = probe('can_skip_booster', nil)
        if button ~= 'skip_booster' then return 'wait', 'the pack cannot be skipped yet' end
        G.FUNCS.skip_booster(e)
        return 'done'
    end

    -- Sorted copy of a list using the game's own comparator, so a logged
    -- permutation that equals a sort result is treated as the sort button.
    local function sorted_like(list, method)
        local copy = {}
        for i, card in ipairs(list) do copy[i] = card end
        if method == 'suit desc' then
            table.sort(copy, function(a, b) return a:get_nominal('suit') > b:get_nominal('suit') end)
        else
            table.sort(copy, function(a, b) return a:get_nominal() > b:get_nominal() end)
        end
        return copy
    end
    local function same_order(a, b)
        if #a ~= #b then return false end
        for i = 1, #a do if a[i] ~= b[i] then return false end end
        return true
    end

    handlers.reorder = function(entry)
        local area_name = areas[tonumber(entry.args[1])]
        local area = G[area_name]
        local list = cards_of(area)
        if not list then return 'wait', tostring(area_name) .. ' is not open' end
        local order = log.indices(entry.args[2])
        if #order ~= #list then
            return 'wait', area_name .. ' holds ' .. #list .. ' card(s), the log reorders ' .. #order
        end
        local before, after = {}, {}
        for i, card in ipairs(list) do before[i] = card end
        for i, j in ipairs(order) do
            if not before[j] then error('reorder names position ' .. j .. ' of ' .. #before) end
            after[i] = before[j]
        end
        -- The hand's sort buttons leave the same permutation as a drag would,
        -- but they also change how every later draw is sorted.
        if area == G.hand and list[1] and list[1].get_nominal then
            for _, method in ipairs({'suit desc', 'desc'}) do
                if same_order(after, sorted_like(list, method)) then
                    area:sort(method)
                    return 'done'
                end
            end
        end
        for i, card in ipairs(after) do list[i] = card end
        if area.set_ranks then area:set_ranks() end
        if area.align_cards then area:align_cards() end
        return 'done'
    end

    local function blind_action(entry, name, expected_key)
        if state_is('ROUND_EVAL') then return leave_round_eval() end
        if state_is('SHOP') then return leave_shop() end
        if not state_is('BLIND_SELECT') or not G.blind_select then return 'wait', 'blind select is not open (' .. state_name() .. ')' end
        local node, why = blind_button(name)
        if not node then
            if name == 'select_blind' and select(1, blind_button('mp_toggle_ready')) then
                error('this blind needs Ready first, but the log selects it directly')
            end
            return 'wait', why
        end
        if expected_key then
            local key = (node.config.ref_table or {}).key
            if key ~= expected_key then error('the ' .. tostring(G.GAME.blind_on_deck) .. ' blind is ' .. tostring(key) .. ', the log chose ' .. expected_key) end
        end
        G.FUNCS[name](node)
        return 'done'
    end

    handlers.select_blind = function(entry) return blind_action(entry, 'select_blind', log.expectation(entry).blind) end
    handlers.skip_blind = function(entry) return blind_action(entry, 'skip_blind') end

    handlers.ready_blind = function(entry)
        if state_is('ROUND_EVAL') then return leave_round_eval() end
        if state_is('SHOP') then return leave_shop() end
        if not state_is('BLIND_SELECT') or not G.blind_select then return 'wait', 'blind select is not open (' .. state_name() .. ')' end
        local node, why = blind_button('mp_toggle_ready')
        if not node then return 'wait', why end
        local ready = entry.args[1] == '1'
        if (MP.GAME.ready_blind and true or false) == ready then
            error('the player is already ' .. (ready and 'ready' or 'not ready'))
        end
        G.FUNCS.mp_toggle_ready(node)
        return 'done'
    end

    -- Perform one input. Returns 'done' or 'wait', reason.
    function M.perform(entry)
        local handler = handlers[entry.op]
        if not handler then error('the replay cannot perform ' .. tostring(entry.op)) end
        return handler(entry)
    end

    -- A signature of everything an input could be waiting on. The session
    -- acts only after it has held still for a moment.
    function M.signature()
        local parts = {tostring(G.STATE), tostring((G.GAME or {}).dollars), tostring(((G.GAME or {}).round_resets or {}).ante),
            tostring((G.GAME or {}).blind_on_deck), tostring(MP and MP.GAME and MP.GAME.lives), tostring(G.blind_select ~= nil), tostring(G.round_eval ~= nil)}
        for _, name in ipairs(areas) do
            local list = cards_of(G[name])
            parts[#parts + 1] = list and tostring(#list) or '-'
        end
        return table.concat(parts, '|')
    end

    return M
end
