-- Append-only recording: one write per action, no 200 ms snapshot stream.
-- The export server assembles journal records into a single compact JSON document.
return function(JSON, version)
    local M = {ok=true}
    local directory='balatro_action_recorder'
    local game, path, started, sequence, counter = nil,nil,0,0,0
    local catalog, identities, next_card, next_identity = {},{},0,0
    local areas={'hand','jokers','consumeables','shop_jokers','shop_vouchers','shop_booster','pack_cards'}
    local descriptions=setmetatable({},{__mode='k'})
    local pending_observation=false
    local observe_after=0
    local function scalar(v)
        if type(v)=='string' or type(v)=='boolean' then return v end
        if type(v)=='number' and v==v and math.abs(v)~=math.huge then return v end
    end
    local function fields(t, names)
        local out={}
        for _,name in ipairs(names) do out[name]=scalar((t or {})[name]) end
        return out
    end
    local function running()
        return G and G.GAME and G.STAGE and G.STAGE==((G.STAGES or {}).RUN)
    end
    local function context()
        local out=fields(G.GAME,{'dollars','chips','round'})
        local round=G.GAME.current_round or {}
        out.ante=scalar((G.GAME.round_resets or {}).ante)
        out.blind=scalar(((((G.GAME.blind or {}).config or {}).blind or {}).key))
        out.hands_left=scalar(round.hands_left);out.discards_left=scalar(round.discards_left)
        out.hands_played=scalar(round.hands_played);out.discards_used=scalar(round.discards_used)
        for name,id in pairs(G.STATES or {}) do if G.STATE==id then out.phase=name;break end end
        return out
    end
    function M.card(c,index)
        if c.facing~='front' then return {index=index,hidden=true} end
        local center=(c.config or {}).center or {}
        local a=c.ability or {}
        local d={key=scalar(center.key),set=scalar(a.set or center.set),name=scalar(a.name or center.name)}
        if center.key~='m_stone' then
            d.rank=scalar((c.base or {}).value);d.suit=scalar((c.base or {}).suit)
        end
        d.edition=fields(c.edition,{'foil','holo','polychrome','negative','mp_phantom'})
        if (c.edition or {}).type=='mp_phantom' then d.edition.mp_phantom=true end
        d.seal=scalar(c.seal);d.debuff=c.debuff==true or nil
        d.stickers=fields(a,{'eternal','perishable','rental','perish_tally'})
        d.perma_bonus=scalar(a.perma_bonus)
        return {index=index,descriptor=d,object=c}
    end
    function M.area(a, selected)
        local list=JSON.array()
        local highlighted={}
        for _,c in ipairs((a or {}).highlighted or {}) do highlighted[c]=true end
        for i,c in ipairs((a or {}).cards or {}) do
            if not selected or highlighted[c] or c.highlighted then list[#list+1]=M.card(c,i) end
        end
        return list
    end
    function M.location(c)
        for _,name in ipairs(areas) do
            for i,item in ipairs((G[name] or {}).cards or {}) do if item==c then return name,i end end
        end
    end
    function M.capture(token)
        if not running() or (G.SETTINGS or {}).paused or G.OVERLAY_MENU then return end
        return {type=token,context=context()}
    end
    local function append(record)
        assert(path,'No recording file')
        assert(love.filesystem.append(path,JSON.encode(record)..'\n'))
    end
    function M.begin(resumed)
        if not running() then return end
        counter=counter+1
        game=G.GAME;started=love.timer.getTime();sequence=0
        catalog={};identities=setmetatable({},{__mode='k'});next_card=0;next_identity=0
        descriptions=setmetatable({},{__mode='k'})
        pending_observation=false
        assert(love.filesystem.createDirectory(directory))
        local id=tostring(os.time())..'-'..tostring(math.floor(started*1000000))..'-'..counter
        path=directory..'/run-'..id..'.jsonl'
        -- A fresh game process can have the same clock tick; never overwrite an existing recording.
        while love.filesystem.getInfo and love.filesystem.getInfo(path) do
            counter=counter+1;id=tostring(os.time())..'-'..tostring(math.floor(started*1000000))..'-'..counter
            path=directory..'/run-'..id..'.jsonl'
        end
        local metadata={schema_version=1,recording={id=id,version=version,started_at=os.time(),partial=resumed==true,
            deck=scalar((((game.selected_back or {}).effect or {}).center or {}).key),stake=scalar(game.stake)},
            index_base=1}
        assert(love.filesystem.write(path,JSON.encode(metadata)..'\n'))
        M.path=path;M.ok=true
        love.filesystem.write(directory..'/status.json',JSON.encode({ok=true,recording=id}))
    end
    -- Descriptors are interned once; instance IDs distinguish duplicate physical cards.
    -- Neither descriptor nor instance IDs are emitted for face-down cards.
    local function refs(list,definitions)
        local out=JSON.array()
        for _,entry in ipairs(list or {}) do
            if entry.hidden then out[#out+1]={index=entry.index,hidden=true}
            else
                local encoded=JSON.encode(entry.descriptor)
                local id=catalog[encoded]
                if not id then next_card=next_card+1;id=tostring(next_card);catalog[encoded]=id;definitions[id]=entry.descriptor end
                local instance=identities[entry.object]
                if not instance then next_identity=next_identity+1;instance=next_identity;identities[entry.object]=instance end
                descriptions[entry.object]=encoded
                out[#out+1]={index=entry.index,card=id,instance=instance}
            end
        end
        return out
    end
    function M.record(event)
        if not event then return end
        if game~=G.GAME or not path then M.begin(true) end
        local definitions={}
        for _,key in ipairs({'cards','targets'}) do if event[key] then event[key]=refs(event[key],definitions) end end
        sequence=sequence+1;event.n=sequence;event.ms=math.floor((love.timer.getTime()-started)*1000+.5)
        append({cards=definitions,action=event})
        pending_observation=true
        observe_after=love.timer.getTime()+0.3
    end
    -- Shared outcome, explicitly tied to the latest accepted action. Intermediate animations are omitted.
    function M.observe()
        if love.timer.getTime()<observe_after or not pending_observation or not running() or game~=G.GAME or not G.STATE_COMPLETE or G.OVERLAY_MENU then return end
        local stable=false
        for _,name in ipairs({'SELECTING_HAND','SHOP','BLIND_SELECT','ROUND_EVAL','SMODS_BOOSTER_OPENED','TAROT_PACK','PLANET_PACK','SPECTRAL_PACK','STANDARD_PACK','BUFFOON_PACK','GAME_OVER'}) do
            if (G.STATES or {})[name] and G.STATE==G.STATES[name] then stable=true end
        end
        local locks=((G.CONTROLLER or {}).locks or {})
        if not stable or locks.shop_reroll or locks.selling_card or locks.use or (G.SETTINGS or {}).paused then return end
        local definitions,visible={},{}
        local pack_phase=false
        for _,name in ipairs({'SMODS_BOOSTER_OPENED','TAROT_PACK','PLANET_PACK','SPECTRAL_PACK','STANDARD_PACK','BUFFOON_PACK'}) do
            if (G.STATES or {})[name] and G.STATE==G.STATES[name] then pack_phase=true end
        end
        for _,name in ipairs(areas) do
            local shop=name:match('^shop_');local pack=name=='pack_cards'
            local include=(not shop and not pack) or (shop and G.STATE==G.STATES.SHOP) or (pack and pack_phase)
            if include and G[name] then
                local changed=JSON.array()
                for _,entry in ipairs(M.area(G[name])) do
                    if not entry.hidden and descriptions[entry.object] and descriptions[entry.object]~=JSON.encode(entry.descriptor) then changed[#changed+1]=entry end
                end
                if #changed>0 then visible[name]=refs(changed,definitions) end
            end
        end
        if next(visible) then append({cards=definitions,observation={after_action=sequence,areas=visible}}) end
        pending_observation=false
    end
    function M.safe(fn,...)
        if not M.ok then return end -- A partial failed append must never be followed by more journal records.
        local ok,result=pcall(fn,...)
        if not ok then
            M.ok=false
            pcall(love.filesystem.write,directory..'/status.json',JSON.encode({ok=false,message='Recording stopped after an error. Restart Balatro to start a new recording segment.'}))
            return
        end
        return result
    end
    return M
end
