-- Observe Multiplayer's public receive trace before its handler runs. Never
-- consume its channel or send a message. Preserve the original logger exactly.
return function(rec)
    if type(sendTraceMessage)~='function' then return end
    local original=sendTraceMessage
    local allowed={enemyInfo={'lives','handsLeft','skips','score','noScore'},enemyLocation={'location'},
        playerInfo={'lives'},startBlind={'firstPlayer'},endPvP={'lost','pvpTimerLost'},winGame={},loseGame={},
        asteroid={},eatPizza={'whole'},soldJoker={},letsGoGamblingNemesis={},spentLastShop={'amount'},
        sendPhantom={'key'},removePhantom={'key'},magnet={},magnetResponse={'key'}}
    local numeric={lives=true,handsLeft=true,skips=true,whole=true,amount=true}
    local function capture(text,logger)
        if logger~='MULTIPLAYER' or type(text)~='string' then return end
        local name,rest=text:match('^Client got (%w+) message:%s*(.*)$')
        if not allowed[name] then return end
        local config=(((MP or {}).LOBBY or {}).config or {})
        if name=='enemyLocation' and config.enemy_location_disabled then return end
        local values={}
        for key,value in rest:gmatch('%((%w+):%s*([^)]*)%)') do values[key]=value:match('^%s*(.-)%s*$') end
        local fields={action=name}
        for _,key in ipairs(allowed[name]) do
            local value=values[key]
            if value~=nil then
                if value=='true' then fields[key]=true
                elseif value=='false' then fields[key]=false
                elseif numeric[key] then fields[key]=tonumber(value)
                else fields[key]=value end
            end
        end
        if name=='enemyInfo' then
            local played=(((G or {}).GAME or {}).current_round or {}).hands_played or 0
            if config.hide_score_until_played and played<=0 then fields.score=nil;fields.noScore=true end
            if not fields.score then fields.noScore=true end
        end
        rec.network(fields)
    end
    sendTraceMessage=function(text,logger,...)
        rec.safe(capture,text,logger)
        return original(text,logger,...)
    end
end
