-- Wrap the game's accepted-action callbacks; always preserve arguments, results and errors.
return function(rec,JSON)
    local M={}
    local depth, current=0,nil
    local orders=setmetatable({},{__mode='k'})
    local function pack(...) return {n=select('#',...),...} end
    local function target(e) return type(e)=='table' and (e.config or {}).ref_table end
    local function prepare(token,e,hook,nosave)
        if token=='use' and nosave then return end
        if token=='discard' and hook then return end -- e.g. The Hook's forced discard is not a player discard.
        local event=rec.capture(token)
        if not event then return end
        if token=='play' or token=='discard' then
            if token=='play' and #((G.play or {}).cards or {})>0 then return end
            event.area='hand';event.cards=rec.area(G.hand,true)
            if token=='discard' then
                local limit=((G.discard or {}).config or {}).card_limit
                if type(limit)=='number' then
                    local count=math.max(0,limit-#((G.play or {}).cards or {}))
                    while #event.cards>count do table.remove(event.cards) end
                end
            end
            if #event.cards==0 then return end
            event.options=rec.area(G.hand)
        elseif token=='buy' or token=='use' or token=='sell' then
            local c=token=='sell' and e or target(e)
            if type(c)~='table' then return end
            local area,index=rec.location(c)
            if not area then return end
            event.area=area;event.cards=JSON.array({rec.card(c,index)})
            if token=='use' and area=='pack_cards' then event.type='pack_pick' end
            if token=='use' then event.targets=rec.area(G.hand,true) end
            if area:match('^shop_') or area=='pack_cards' then event.options=rec.area(G[area]) end
            local amount=token=='sell' and c.sell_cost or (area:match('^shop_') and c.cost)
            if type(amount)=='number' and amount==amount and math.abs(amount)~=math.huge then event.price=amount end
            if token=='buy' and (e.config or {}).id=='buy_and_use' then event.use_after_buy=true;event.targets=rec.area(G.hand,true) end
        elseif token=='reroll' then
            if G.STATE~=G.STATES.SHOP then return end
            event.area='shop_jokers';event.options=rec.area(G.shop_jokers)
            event.price=(G.GAME.current_round or {}).reroll_cost
        elseif token=='pack_skip' then
            if not G.pack_cards then return end
            event.area='pack_cards';event.options=rec.area(G.pack_cards)
        elseif token=='select_blind' or token=='skip_blind' then
            if not G.blind_select then return end
            local slot=G.GAME.blind_on_deck
            local key=((G.GAME.round_resets or {}).blind_choices or {})[slot]
            local definition=target(e)
            if token=='select_blind' and type(definition)=='table' then key=definition.key or key end
            event.blind={slot=slot,key=key}
            if token=='skip_blind' then event.blind.tag=((G.GAME.round_resets or {}).blind_tags or {})[slot] end
        end
        return event
    end
    local function wrap(owner,name,token)
        local original=owner and owner[name]
        if type(original)~='function' then return end
        owner[name]=function(...)
            local outer=depth==0
            local event=outer and rec.safe(prepare,token,...) or nil
            local previous=current
            if outer then current={blocked=false} end
            depth=depth+1
            local results=pack(pcall(original,...))
            depth=depth-1
            local blocked=current and current.blocked
            current=previous
            if not results[1] then error(results[2],0) end
            if event and results[2]~=false and not blocked then rec.safe(rec.record,event) end
            return unpack(results,2,results.n)
        end
    end
    function M.install()
        for name,token in pairs({play_cards_from_highlighted='play',discard_cards_from_highlighted='discard',buy_from_shop='buy',use_card='use',reroll_shop='reroll',skip_booster='pack_skip',select_blind='select_blind',skip_blind='skip_blind'}) do wrap(G.FUNCS,name,token) end
        wrap(Card,'sell_card','sell')
        -- Observe the game's own use check once, rather than invoking it a second time.
        if Card and Card.check_use then
            local original=Card.check_use
            Card.check_use=function(...)
                local result=pack(original(...))
                if current and result[1] then current.blocked=true end
                return unpack(result,1,result.n)
            end
        end
    end
    function M.reorders()
        if not G or not G.GAME then return end
        for _,name in ipairs({'hand','jokers','consumeables'}) do
            local area=G[name]
            if area then
                local now,dragging={},false
                for i,c in ipairs(area.cards or {}) do
                    now[i]=c
                    if (((c.states or {}).drag or {}).is) then dragging=true end
                end
                if not dragging then
                    local before=orders[area];orders[area]=now
                    if before and #before==#now and G.STATE_COMPLETE then
                        local positions={};for i,c in ipairs(before) do positions[c]=i end
                        local permutation,changed,complete=JSON.array(),false,true
                        for i,c in ipairs(now) do
                            if not positions[c] then complete=false;break end
                            permutation[i]=positions[c];if positions[c]~=i then changed=true end
                        end
                        if complete and changed then
                            local event=rec.capture('reorder')
                            if event then event.area=name;event.order=permutation;event.cards=rec.area(area);rec.record(event) end
                        end
                    end
                end
            end
        end
    end
    function M.reset() orders=setmetatable({},{__mode='k'}) end
    return M
end
