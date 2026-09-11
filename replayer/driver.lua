-- Invoke the same game callbacks as the UI, so Action Recorder sees real actions.
return function(parser,recorder,JSON)
    local M={};local names={'shop_jokers','shop_booster','shop_vouchers','jokers','consumeables','hand','pack_cards'}
    -- A removed CardArea stays referenced from G with its cards table set to
    -- nil: closing the shop or a booster pack does exactly that, and the game's
    -- own CardArea methods guard against it, so never index .cards directly.
    local function cards_of(area) return type(area)=='table' and area.cards or nil end
    local function card_at(area,index)
        local list=cards_of(area)
        if not list or not index then return nil end
        return list[index]
    end
    local function select_cards(text)
        local indices=text and parser.indices(text) or {}
        local hand=G.hand
        local list=cards_of(hand)
        if #indices>0 and not list then return false end
        if not hand then return true end
        for _,i in ipairs(indices) do assert(list[i],'Selected card position is unavailable') end
        hand:unhighlight_all()
        -- A boss blind can force a card to stay highlighted; adding it a second
        -- time would double it and make the selection look rejected.
        local highlighted={}
        for _,c in ipairs(hand.highlighted or {}) do highlighted[c]=true end
        for _,i in ipairs(indices) do
            if not highlighted[list[i]] then highlighted[list[i]]=true;hand:add_to_highlighted(list[i],true) end
        end
        assert(#(hand.highlighted or {})==#indices,'Game rejected card selection')
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
    -- Every refusal names what the driver is still waiting for, so a stall
    -- reports the missing precondition instead of just a step number.
    -- `transient` marks a hold-up the driver itself set in motion, where the
    -- game is expected to move on by itself; everything else is a standing
    -- refusal that another identical attempt cannot change.
    local function pending(reason,transient) M.pending=reason;M.transient=transient==true;return false end
    -- The game's own gate for putting this card into play, matching the button
    -- the real UI would show for it.
    local function check_name(card,op)
        local set=(card.ability or {}).set
        if set=='Booster' then return 'can_open' end
        if set=='Voucher' then return 'can_redeem' end
        if op=='pack_pick' and not card.ability.consumeable then return 'can_select_card' end
        return 'can_use_consumeable'
    end
    -- Ask the game whether it would accept this card right now, without acting.
    local function accepts(card)
        local check=check_name(card,'use')
        if type(G.FUNCS[check])~='function' then return true end
        local probe={config={ref_table=card}}
        local ok=pcall(G.FUNCS[check],probe)
        return ok and probe.config.button~=nil
    end
    -- `use` records a slot but not an area. Resolve what each one meant before
    -- playback, from the action stream alone: a use carrying hand targets is a
    -- consumable, and one whose next meaningful action opens a pack came from
    -- the booster shelf. Actions that can happen with a pack already open do
    -- not break that pairing.
    local transparent={reorder=true,set_ante_key=true,net_asteroid=true,ready_blind=true,sell=true}
    function M.resolve(actions)
        for index,action in ipairs(actions) do
            if action.op=='use' then
                action.area=nil
                if action.args[2] then action.area='consumeables'
                else
                    local following=index+1
                    while actions[following] and transparent[actions[following].op] do following=following+1 end
                    local next_action=actions[following]
                    if next_action and (next_action.op=='pack_pick' or next_action.op=='pack_skip') then action.area='shop_booster' end
                end
            end
        end
        return actions
    end
    -- The opcodes M.step knows how to perform. Checked over the whole log before
    -- playback starts, so no action can surprise the run half way through.
    local handled={play=true,discard=true,buy=true,sell=true,reroll=true,use=true,pack_pick=true,
        pack_skip=true,reorder=true,select_blind=true,skip_blind=true,open_pack=true,voucher=true,
        ready_blind=true,set_ante_key=true,net_asteroid=true}
    function M.supports(op) return handled[op]==true end
    function M.step(action)
        local op,a=action.op,action.args
        M.pending=nil;M.transient=false
        local function auxiliary()
            local event=assert(recorder.capture(op),'Recorder unavailable');event.value=a[1];recorder.record(event);return true
        end
        if op=='set_ante_key' then M.ante_key=a[1];MP.GAME.ante_key=a[1];return auxiliary() end
        if op=='net_asteroid' then assert(MP.UI and MP.UI.show_asteroid_hand_level_up,'Missing asteroid handler');MP.UI.show_asteroid_hand_level_up();return auxiliary() end
        if G.STATE==G.STATES.ROUND_EVAL then
            -- Cash-out is never logged; a synthetic event also bypasses keybind
            -- helpers that suppress the real button after a skipped cash-out.
            if G.round_eval then call('cash_out',{config={}}) end
            return pending('cashing out before the next action',G.round_eval~=nil)
        end
        local blind_action=op=='select_blind' or op=='skip_blind' or op=='ready_blind'
        if blind_action and G.STATE==G.STATES.SHOP then call('toggle_shop');return pending('leaving the shop',true) end
        if blind_action then
            if G.STATE~=G.STATES.BLIND_SELECT or not G.blind_select then return pending('blind select is not open') end
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
            if not e then return pending('no '..callback..' button on the '..tostring((G.GAME or {}).blind_on_deck)..' blind') end
            -- Ghost games select locally; never send ready messages to a live lobby.
            if e.config.button=='mp_toggle_ready' then
                e={config={ref_table=assert(definition,'Unknown blind')},UIBox=e.UIBox}
            end
            MP.GAME.ready_blind=false;call(callback,e);if M.ante_key then MP.GAME.ante_key=M.ante_key end;return true
        end
        if op=='play' or op=='discard' then
            if G.STATE~=G.STATES.SELECTING_HAND then return pending('not selecting a hand yet') end
            select_cards(a[1]);return call(op=='play' and 'play_cards_from_highlighted' or 'discard_cards_from_highlighted',nil,op=='play' and 'can_play' or 'can_discard')
        end
        if op=='reroll' then if G.STATE~=G.STATES.SHOP then return pending('the shop is not open') end;return call('reroll_shop',nil,'can_reroll') end
        if op=='pack_skip' then local e=button('skip_booster');if not e then return pending('no booster skip button') end;return call('skip_booster',e) end
        if op=='reorder' then
            local area=G[names[tonumber(a[1])]];local list=cards_of(area)
            if not list then return pending(tostring(names[tonumber(a[1])])..' does not exist yet') end
            local order=parser.indices(a[2]);assert(#order==#list,'Reorder card count differs')
            local before={};for i,c in ipairs(list) do before[i]=c end
            for i,j in ipairs(order) do assert(before[j],'Invalid reorder position');list[i]=before[j] end
            if area.align_cards then area:align_cards() end
            local event=recorder.capture('reorder');assert(event,'Recorder unavailable');event.area=names[tonumber(a[1])];event.order=JSON.array(order);event.cards=recorder.area(area);recorder.record(event)
            return true
        end
        local card
        if op=='use' then
            local candidates={}
            for _,area in ipairs({'consumeables','shop_booster','shop_vouchers','shop_jokers'}) do
                local c=card_at(G[area],tonumber(a[1]))
                if c and (not a[2] or G.hand) and (area=='consumeables' or G.STATE==G.STATES.SHOP) then candidates[#candidates+1]={area=area,card=c} end
            end
            if #candidates==1 then card=candidates[1].card
            elseif #candidates>1 then
                -- The area worked out before playback wins; otherwise let the
                -- game rule out what it would refuse, then take the commonest
                -- meaning of a bare use slot.
                for _,entry in ipairs(candidates) do if entry.area==action.area then card=entry.card;break end end
                if not card then
                    local allowed={}
                    for _,entry in ipairs(candidates) do if accepts(entry.card) then allowed[#allowed+1]=entry end end
                    if #allowed==0 then allowed=candidates end
                    for _,area in ipairs({'consumeables','shop_vouchers','shop_booster','shop_jokers'}) do
                        for _,entry in ipairs(allowed) do if entry.area==area then card=entry.card;break end end
                        if card then break end
                    end
                end
            end
        elseif op=='pack_pick' then card=card_at(G.pack_cards,tonumber(a[1]))
        else card=card_at(G[names[tonumber(a[1])]],tonumber(a[2])) end
        if not card then return pending('no card in '..(op=='pack_pick' and 'pack_cards' or op=='use' and 'any use area' or tostring(names[tonumber(a[1])]))..' slot '..tostring(op=='use' and a[1] or op=='pack_pick' and a[1] or a[2])) end
        if op=='sell' then assert(not card.can_sell_card or card:can_sell_card(),'Game rejected sell');assert(card:sell_card()~=false,'Game rejected sell');return true end
        local set=(card.ability or {}).set
        -- Multiplayer gives shop packs and vouchers their own opcodes, but the
        -- game itself redeems both through use_card, as the shop buttons do.
        if op=='buy' or ((op=='open_pack' or op=='voucher') and set~='Booster' and set~='Voucher') then
            return call('buy_from_shop',{config={ref_table=card,id='buy'}},'can_buy')
        end
        if not select_cards(a[2] and (op=='use' or op=='pack_pick') and a[2] or nil) then return pending('the hand is not dealt yet') end
        return call('use_card',{config={ref_table=card}},check_name(card,op))
    end
    return M
end
