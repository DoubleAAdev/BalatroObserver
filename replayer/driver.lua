-- Invoke the same game callbacks as the UI, so Action Recorder sees real actions.
return function(parser,recorder,JSON)
    local M={};local names={'shop_jokers','shop_booster','shop_vouchers','jokers','consumeables','hand','pack_cards'}
    local function select_cards(text)
        local indices=text and parser.indices(text) or {}
        if #indices>0 and not G.hand then return false end
        for _,i in ipairs(indices) do assert(G.hand.cards[i],'Selected card position is unavailable') end
        if G.hand then
            G.hand:unhighlight_all()
            for _,i in ipairs(indices) do G.hand:add_to_highlighted(G.hand.cards[i],true) end
            assert(#G.hand.highlighted==#indices,'Game rejected card selection')
        end
        return true
    end
    local function button(callback,ref)
        local seen={}
        local function visit(node)
            if type(node)~='table' or seen[node] then return end;seen[node]=true
            if node.config and node.config.button==callback and (not ref or node.config.ref_table==ref) then return node end
            for _,child in pairs(node.children or {}) do local found=visit(child);if found then return found end end
        end
        for _,box in pairs((G.I or {}).UIBOX or {}) do local found=visit(box);if found then return found end end
    end
    local function call(name,e,check)
        assert(type(G.FUNCS[name])=='function','Missing game callback '..name)
        e=e or {config={}}
        if check and G.FUNCS[check] then G.FUNCS[check](e);assert(e.config.button,'Game rejected '..name) end
        assert(G.FUNCS[name](e)~=false,'Game rejected '..name)
        return true
    end
    function M.step(action)
        local op,a=action.op,action.args
        local function auxiliary()
            local event=assert(recorder.capture(op),'Recorder unavailable');event.value=a[1];recorder.record(event);return true
        end
        if op=='set_ante_key' then M.ante_key=a[1];MP.GAME.ante_key=a[1];return auxiliary() end
        if op=='net_asteroid' then assert(MP.UI and MP.UI.show_asteroid_hand_level_up,'Missing asteroid handler');MP.UI.show_asteroid_hand_level_up();return auxiliary() end
        if G.STATE==G.STATES.ROUND_EVAL then
            local e=button('cash_out');if e then call('cash_out',e) end;return false
        end
        local blind_action=op=='select_blind' or op=='skip_blind' or op=='ready_blind'
        if blind_action and G.STATE==G.STATES.SHOP then call('toggle_shop');return false end
        if blind_action then
            if G.STATE~=G.STATES.BLIND_SELECT or not G.blind_select then return false end
            -- Readiness precedes a separate select_blind record; it must not select twice.
            if op=='ready_blind' then MP.GAME.ready_blind=a[1]=='1';return auxiliary() end
            local callback=op=='skip_blind' and 'skip_blind' or 'select_blind'
            local e=button(callback) or (op=='select_blind' and button('mp_toggle_ready'))
            if not e then return false end
            -- Ghost games select locally; never send ready messages to a live lobby.
            if e.config.button=='mp_toggle_ready' then
                local key=G.GAME.round_resets.blind_choices[G.GAME.blind_on_deck]
                e={config={ref_table=assert(G.P_BLINDS[key],'Unknown blind')},UIBox=e.UIBox}
            end
            MP.GAME.ready_blind=false;call(callback,e);if M.ante_key then MP.GAME.ante_key=M.ante_key end;return true
        end
        if op=='play' or op=='discard' then
            if G.STATE~=G.STATES.SELECTING_HAND then return false end
            select_cards(a[1]);return call(op=='play' and 'play_cards_from_highlighted' or 'discard_cards_from_highlighted',nil,op=='play' and 'can_play' or 'can_discard')
        end
        if op=='reroll' then if G.STATE~=G.STATES.SHOP then return false end;return call('reroll_shop',nil,'can_reroll') end
        if op=='pack_skip' then local e=button('skip_booster');if not e then return false end;return call('skip_booster',e) end
        if op=='reorder' then
            local area=G[names[tonumber(a[1])]];if not area then return false end
            local order=parser.indices(a[2]);assert(#order==#area.cards,'Reorder card count differs')
            local before={};for i,c in ipairs(area.cards) do before[i]=c end
            for i,j in ipairs(order) do assert(before[j],'Invalid reorder position');area.cards[i]=before[j] end
            if area.align_cards then area:align_cards() end
            local event=recorder.capture('reorder');assert(event,'Recorder unavailable');event.area=names[tonumber(a[1])];event.order=JSON.array(order);event.cards=recorder.area(area);recorder.record(event)
            return true
        end
        local card
        if op=='use' then
            local candidates={}
            for _,area in ipairs({'consumeables','shop_booster','shop_vouchers','shop_jokers'}) do
                local c=G[area] and G[area].cards[tonumber(a[1])]
                if c and (not a[2] or G.hand) and (not action.name or (c.ability or {}).name==action.name) and (area=='consumeables' or G.STATE==G.STATES.SHOP) then candidates[#candidates+1]=c end
            end
            assert(#candidates<=1,'Use action is ambiguous: log lacks a unique card identity')
            card=candidates[1]
        elseif op=='pack_pick' then card=G.pack_cards and G.pack_cards.cards[tonumber(a[1])]
        else local area=G[names[tonumber(a[1])]];card=area and area.cards[tonumber(a[2])] end
        if not card then return false end
        if action.name then assert((card.ability or {}).name==action.name,'Card identity differs from log') end
        if op=='sell' then assert(not card.can_sell_card or card:can_sell_card(),'Game rejected sell');assert(card:sell_card()~=false,'Game rejected sell');return true end
        if op=='buy' then return call('buy_from_shop',{config={ref_table=card,id='buy'}},'can_buy') end
        if not select_cards(a[2] and (op=='use' or op=='pack_pick') and a[2] or nil) then return false end
        local check=card.ability.set=='Booster' and 'can_open' or card.ability.set=='Voucher' and 'can_redeem' or (op=='pack_pick' and not card.ability.consumeable) and 'can_select_card' or 'can_use_consumeable'
        return call('use_card',{config={ref_table=card}},check)
    end
    return M
end
