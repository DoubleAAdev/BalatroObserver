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
    -- A UIBox keeps its elements on UIRoot rather than in children, and embeds
    -- other boxes as config.object, so walking children alone finds no buttons.
    local function search(node,callback,accept,seen)
        if type(node)~='table' or seen[node] then return end
        seen[node]=true
        local config=node.config
        if config then
            if config.button==callback and (not accept or accept(node)) then return node end
            local nested=config.object
            if type(nested)=='table' and nested.UIRoot then
                local found=search(nested.UIRoot,callback,accept,seen);if found then return found end
            end
        end
        if node.UIRoot then local found=search(node.UIRoot,callback,accept,seen);if found then return found end end
        for _,child in pairs(node.children or {}) do
            local found=search(child,callback,accept,seen);if found then return found end
        end
    end
    -- Without a root every live UIBox is searched; pass one to stay inside a
    -- single panel, because the three blind columns share button names.
    local function button(callback,root,accept)
        if root~=nil then return search(root,callback,accept,{}) end
        for _,box in pairs((G.I or {}).UIBOX or {}) do
            local found=search(box,callback,accept,{});if found then return found end
        end
    end
    M.button=button
    local function call(name,e,check)
        assert(type(G.FUNCS[name])=='function','Missing game callback '..name)
        e=e or {config={}}
        if check and G.FUNCS[check] then G.FUNCS[check](e);assert(e.config.button,'Game rejected '..name) end
        assert(G.FUNCS[name](e)~=false,'Game rejected '..name)
        return true
    end
    -- The blind on deck decides which of the Small/Big/Boss panels to press.
    local function blind_panel()
        local slot=(G.GAME or {}).blind_on_deck
        if not slot then return nil end
        return (G.blind_select_opts or {})[tostring(slot):lower()]
    end
    local function blind_definition()
        local slot=(G.GAME or {}).blind_on_deck
        local key=slot and (((G.GAME or {}).round_resets or {}).blind_choices or {})[slot]
        return key and (G.P_BLINDS or {})[key]
    end
    function M.step(action)
        local op,a=action.op,action.args
        local function auxiliary()
            local event=assert(recorder.capture(op),'Recorder unavailable');event.value=a[1];recorder.record(event);return true
        end
        if op=='set_ante_key' then M.ante_key=a[1];MP.GAME.ante_key=a[1];return auxiliary() end
        if op=='net_asteroid' then assert(MP.UI and MP.UI.show_asteroid_hand_level_up,'Missing asteroid handler');MP.UI.show_asteroid_hand_level_up();return auxiliary() end
        if G.STATE==G.STATES.ROUND_EVAL then
            -- Cash-out is never logged; a synthetic event also bypasses keybind
            -- helpers that suppress the real button after a skipped cash-out.
            if G.round_eval then call('cash_out',{config={}}) end
            return false
        end
        local blind_action=op=='select_blind' or op=='skip_blind' or op=='ready_blind'
        if blind_action and G.STATE==G.STATES.SHOP then call('toggle_shop');return false end
        if blind_action then
            if G.STATE~=G.STATES.BLIND_SELECT or not G.blind_select then return false end
            -- Readiness precedes a separate select_blind record; it must not select twice.
            if op=='ready_blind' then MP.GAME.ready_blind=a[1]=='1';return auxiliary() end
            local callback=op=='skip_blind' and 'skip_blind' or 'select_blind'
            local definition=blind_definition()
            local panel=blind_panel()
            -- Prefer the on-deck column; without it, match the blind itself so a
            -- global search cannot press a different column's identical button.
            local e=panel and button(callback,panel) or nil
            if not e and definition then e=button(callback,nil,function(node) return node.config.ref_table==definition end) end
            if not e and not panel then e=button(callback) end
            if not e and op=='select_blind' then e=button('mp_toggle_ready',panel) end
            if not e then return false end
            -- Ghost games select locally; never send ready messages to a live lobby.
            if e.config.button=='mp_toggle_ready' then
                e={config={ref_table=assert(definition,'Unknown blind')},UIBox=e.UIBox}
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
        local set=(card.ability or {}).set
        -- Multiplayer gives shop packs and vouchers their own opcodes, but the
        -- game itself redeems both through use_card, as the shop buttons do.
        if op=='buy' or ((op=='open_pack' or op=='voucher') and set~='Booster' and set~='Voucher') then
            return call('buy_from_shop',{config={ref_table=card,id='buy'}},'can_buy')
        end
        if not select_cards(a[2] and (op=='use' or op=='pack_pick') and a[2] or nil) then return false end
        local check=set=='Booster' and 'can_open' or set=='Voucher' and 'can_redeem' or (op=='pack_pick' and not card.ability.consumeable) and 'can_select_card' or 'can_use_consumeable'
        return call('use_card',{config={ref_table=card}},check)
    end
    return M
end
