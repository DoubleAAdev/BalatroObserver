-- Multiplayer 0.5.5 compatibility. Read reviewed tooltip/HUD scalars only.
-- Never call Multiplayer callbacks or traverse networking, seeds, enemy cards or score objects.
return function(scalar, description, array)
    local M = {}
    local paths = {
        j_mp_conjoined_joker={'extra.x_mult_gain','extra.max_x_mult','extra.x_mult'},
        j_mp_pacifist={'extra.x_mult'}, j_mp_penny_pincher={'extra.dollars','extra.nemesis_dollars'},
        j_mp_pizza={'extra.discards','extra.discards_nemesis'},
        j_mp_taxes={'extra.mult_gain','extra.mult'}, j_mp_speedrun={},
        j_mp_skip_off={'extra.extra_hands','extra.extra_discards','extra.hands','extra.discards'},
        j_mp_hanging_chad={'extra'}, j_mp_seltzer={'extra.hands_left'},
        j_mp_turtle_bean={'extra.h_size','extra.h_mod'}, j_mp_ticket={'extra.dollars'},
        j_mp_ticket_experimental={'extra.dollars'}
    }
    local function table_or_empty(v) return type(v)=='table' and v or {} end
    local function context()
        local mp=table_or_empty(rawget(_G,'MP'))
        return mp,table_or_empty(mp.LOBBY),table_or_empty(mp.GAME)
    end
    function M.joker(G,c,key)
        local a=table_or_empty(c.ability)
        local extra=table_or_empty(a.extra)
        local vars={}
        if not paths[key] and key~='j_mp_defensive_joker' and key~='j_mp_lets_go_gambling' and key~='j_mp_bloodstone' and key~='j_mp_cloud_9_sandbox' then return end
        for i,path in ipairs(paths[key] or {}) do
            local parent,child=path:match('^([%w_]+)%.([%w_]+)$')
            vars[i]=scalar(parent and table_or_empty(a[parent])[child] or a[path])
        end
        if key=='j_mp_defensive_joker' then
            vars={scalar((type(G.GAME.stake)=='number' and G.GAME.stake>=6) and extra.highstake or extra.extra),scalar(a.t_chips)}
        elseif key=='j_mp_skip_off' then
            local _,_,game=context()
            local other=scalar(table_or_empty(game.enemy).skips)
            local own=scalar(G.GAME.skips)
            if type(other)=='number' and type(own)=='number' then
                local diff=own-other
                local loc_key=diff==0 and 'a_mp_skips_tied' or diff>0 and 'a_mp_skips_ahead' or 'a_mp_skips_behind'
                local line=table_or_empty(table_or_empty(G.localization).misc).v_dictionary
                line=table_or_empty(line)[loc_key]
                if type(line)=='table' then line=line[1] end
                if type(line)=='string' then vars[5]=line:gsub('#1#',tostring(math.abs(diff))) end
            end
        elseif key=='j_mp_bloodstone' then
            vars={scalar(table_or_empty(G.GAME.probabilities).normal),scalar(extra.odds),scalar(extra.Xmult)}
            key='j_bloodstone' -- The installed loc_vars explicitly uses the vanilla localization key.
        elseif key=='j_mp_lets_go_gambling' then
            -- Probability callbacks can change these odds; do not invoke them or guess their result.
            vars={[3]=scalar(extra.xmult),[4]=scalar(extra.dollars),[7]=scalar(extra.nemesis_dollars)}
        elseif key=='j_mp_cloud_9_sandbox' then
            -- Its probability and rank callbacks are not safe to execute from an observer.
            vars={}
        end
        return vars,key
    end
    function M.card(G,c,out)
        local key=out.key or ''
        local a=table_or_empty(c.ability)
        local vars,set
        if key=='c_mp_asteroid' then vars,set={1},'Planet'
        elseif key=='c_mp_ouija_standard' then vars,set={scalar(table_or_empty(a.extra).destroy)},'Spectral'
        elseif key=='p_mp_standard_giga' then vars,set={scalar(a.choose),scalar(a.extra)},'Other' end
        if set then out.description,out.description_complete=description(G,set,key,vars) end
        if key:match('^[jcp]_mp_') then
            local item=table_or_empty(table_or_empty(table_or_empty(G.localization).descriptions)[set or out.set])[key]
            out.name=scalar(table_or_empty(item).name) or out.name
        end
        if table_or_empty(c.edition).mp_phantom==true or table_or_empty(c.edition).type=='mp_phantom' then
            out.edition.mp_phantom=true
        end
    end
    function M.deck(G,deck)
        if deck.key~='b_mp_cocktail' then return end
        -- Only the component stickers actually revealed by Cocktail; never the hidden component list.
        local shown=table_or_empty(table_or_empty(G.GAME.modifiers).mp_cocktail_sticker)
        local components=array()
        for i=1,3 do
            local key=scalar(shown[i])
            if type(key)=='string' then
                local item=table_or_empty(table_or_empty(table_or_empty(G.localization).descriptions).Back)[key]
                components[#components+1]={key=key,name=scalar(table_or_empty(item).name)}
            end
        end
        if #components>0 then deck.components=components end
    end
    function M.snapshot(G)
        local mp,lobby,game=context()
        if not lobby.connected or not lobby.code then return end
        local config=table_or_empty(lobby.config)
        local blind=table_or_empty(G.GAME.blind)
        local key=table_or_empty(table_or_empty(blind.config).blind).key
        local pvp=key=='bl_mp_nemesis' or blind.pvp==true
        local mode=scalar(config.gamemode)
        local mode_names={gamemode_mp_attrition='Attrition',gamemode_mp_showdown='Showdown',gamemode_mp_survival='Survival'}
        local out={active=true,pvp=pvp,mode=mode_names[mode] or mode,ruleset=scalar(config.ruleset)}
        local enemy=table_or_empty(game.enemy)
        if not config.disable_live_and_timer_hud then
            out.lives=scalar(game.lives);out.nemesis_lives=scalar(enemy.lives)
        end
        if pvp then
            out.nemesis_hands=scalar(enemy.hands_text)
            -- Mirror the HUD's masking gate even if its cached text has not refreshed yet.
            local played=G.GAME.current_round.hands_played
            if config.hide_score_until_played and (type(played)~='number' or played<=0) then
                out.nemesis_score='???'
            else out.nemesis_score=scalar(enemy.score_text) end
        end
        return out
    end
    return M
end
