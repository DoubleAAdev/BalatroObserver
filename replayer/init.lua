return function(mod,JSON)
    if not G or not G.FUNCS then return end
    local function load(name) return assert(SMODS.load_file('replayer/'..name,mod.id))() end
    local parser=load('parser.lua')(function(text) return require('json').decode(text) end)
    local rec=BalatroActionRecorder
    local driver=load('driver.lua')(parser,rec,JSON)
    local pick_file=load('file-picker.lua')
    local M={status='Replayer: select Load Log to choose a Multiplayer log',index=1,active=false}
    BalatroReplayer=M
    local directory='balatro_replayer'
    local timeout=45
    local elapsed,waiting,reported=0,0,nil
    local previous_config,previous_sp,previous_modifiers,previous_saving,previous_mod_config
    local previous_order
    local function status(text)
        M.status=text
        if sendDebugMessage then sendDebugMessage(text,'BalatroObserver') end
        love.filesystem.createDirectory(directory)
        love.filesystem.write(directory..'/status.json',JSON.encode({status=text,step=M.step or 0,active=M.active}))
    end
    local function phase()
        for name,id in pairs(G.STATES or {}) do if G.STATE==id then return name end end
        return 'unknown state'
    end
    -- The Order prefixes the run seed with "*", so the manifest's seed and the
    -- seed the game ends up using differ by that marker alone.
    local function same_seed(actual,expected)
        local function bare(seed) if type(seed)~='string' then return seed end;local stripped=seed:gsub('^%*','');return stripped end
        return bare(actual)==bare(expected)
    end
    local function protect(fn)
        local ok,message=pcall(fn)
        if not ok then M.active=false;status('Replayer stopped: '..tostring(message):gsub('^.-:%d+: ',''):sub(1,120)) end
    end
    function M.import(text)
        assert(not M.session,'Finish the replay session before importing')
        local runs=parser.parse(text)
        -- Multiplayer owns opponent-score parsing; this adapter owns the local input stream.
        assert(MP and MP.load_mp_file,'Multiplayer is required')
        local log_parser=MP.load_mp_file('lib/log_parser.lua')
        local ghosts={}
        for _,game in ipairs(log_parser.process_log(text)) do ghosts[#ghosts+1]=log_parser.to_replay(game) end
        -- Publish both halves together so a failed ghost pass leaves no stale runs.
        M.runs=runs;M.ghosts=ghosts;M.index=1
        status('Replayer: run 1/'..#M.runs..' - '..#M.runs[1].actions..' actions')
    end
    -- Multiplayer records the lobby deck as a centre key or as its display name,
    -- depending on which side wrote the option; accept either spelling.
    local function deck_key(deck)
        if type(deck)~='string' then return nil end
        if (G.P_CENTERS[deck] or {}).set=='Back' then return deck end
        if MP.UTILS and MP.UTILS.get_deck_key_from_name then
            local key=MP.UTILS.get_deck_key_from_name(deck)
            if key then return key end
        end
        for key,centre in pairs(G.P_CENTERS) do
            if centre.set=='Back' and centre.name==deck then return key end
        end
    end
    local function validate(run)
        assert(G.STAGE==G.STAGES.MAIN_MENU or G.STAGE==G.STAGES.RUN,'Wait for Balatro to finish loading')
        assert(MP and MP.GHOST and MP.SP and MP.LOBBY and not MP.LOBBY.code,'Leave the Multiplayer lobby first')
        assert(rec and rec.ok,'Action Recorder must be enabled')
        local m=run.manifest
        local deck=deck_key(m.deck)
        assert(deck,'Manifest deck is not installed')
        assert(MP.Rulesets[m.ruleset],'Manifest ruleset is not installed')
        assert(not m.challenge or m.challenge=='','Challenge replay is not supported')
        local installed=SMODS.Mods and SMODS.Mods.Multiplayer
        assert(installed and installed.version==m.mod_version,'Install the Multiplayer version named in the manifest')
        if deck=='b_mp_cocktail' then
            local cocktail=(m.lobby_config or {}).cocktail
            assert(type(cocktail)=='string' and cocktail:match('^[012]+[HS]$'),'Manifest missing valid Cocktail settings')
            assert(MP.get_cocktail_decks and #MP.get_cocktail_decks()+1==#cocktail,'Installed Cocktail deck pool differs from the log')
        end
        local ghost
        for _,r in ipairs(M.ghosts) do
            if r.seed==m.seed then assert(not ghost,'Multiple opponent records share this seed');ghost=r end
        end
        assert(ghost and next(ghost.ante_snapshots or {}),'Log has no matching opponent history')
        assert(MP.GHOST.is_ruleset_supported(ghost),'Ghost engine does not support this ruleset')
        return ghost,deck
    end
    function M.start()
        assert(M.runs and not M.session,'Load a log before starting')
        local run=M.runs[M.index];local ghost,deck=validate(run);local m=run.manifest
        previous_config=MP.LOBBY.config;previous_sp=MP.SP;previous_modifiers=MP.MODIFIERS;previous_saving=G.F_NO_SAVING
        previous_mod_config=SMODS.Mods.Multiplayer.config
        M.session=true
        local config={}
        -- Only existing gameplay option names are accepted. Session identifiers are never imported.
        for key,value in pairs(previous_config) do config[key]=value end
        for key,value in pairs(m.lobby_config or {}) do
            if key~='action' and previous_config[key]~=nil and (type(value)=='boolean' or type(value)=='number' or type(value)=='string') then config[key]=value end
        end
        config.ruleset=m.ruleset;config.gamemode=m.gamemode;config.back=m.deck;config.stake=m.stake
        config.cocktail=(m.lobby_config or {}).cocktail or config.cocktail
        if deck=='b_mp_cocktail' then
            local replay_config={}
            for key,value in pairs(previous_mod_config or {}) do replay_config[key]=value end
            replay_config.cocktail=config.cocktail
            SMODS.Mods.Multiplayer.config=replay_config
        end
        MP.LOBBY.config=config;MP.SP={practice=true,ruleset=m.ruleset,unlimited_slots=false,edition_cycling=false}
        -- Practice mode turns The Order on unconditionally, but it prefixes the
        -- seed and reshapes every random pool, so follow what the log recorded.
        local order=m.the_order_enabled
        if type(order)~='boolean' then order=(m.lobby_config or {}).the_order end
        -- Assign in a branch: "type(order)=='boolean' and order or nil" would
        -- turn a recorded false back into nil and fall through to practice mode.
        if type(order)=='boolean' then M.the_order=order else M.the_order=nil end
        if not previous_order and type(MP.should_use_the_order)=='function' then
            previous_order=MP.should_use_the_order
            MP.should_use_the_order=function(...)
                if M.session and M.the_order~=nil then return M.the_order end
                return previous_order(...)
            end
        end
        local ruleset_name=m.ruleset:gsub('^ruleset_mp_','')
        MP.apply_default_modifiers(ruleset_name)
        if m.modifier_layers and m.modifier_layers~='' then MP.modifiers_parse(m.modifier_layers) end
        MP.LoadReworks(ruleset_name)
        ghost.seed=m.seed;ghost.deck=m.deck;ghost.stake=m.stake;ghost.ruleset=m.ruleset;ghost.gamemode=m.gamemode
        M.session=true;M.active=true;M.step=1;M.started=false;M.awaiting_start=true;M.deck=deck;elapsed=0;waiting=0;reported=nil
        driver.ante_key=nil;driver.pending=nil;driver.diverged=0;driver.difference=nil
        MP.GHOST.load(ghost);MP.reset_game_states()
        MP.GAME.lives=config.starting_lives or 4;MP.GAME.enemy.lives=MP.GAME.lives
        G.F_NO_SAVING=true
        G.FUNCS.exit_overlay_menu();G.GAME.viewed_back=G.P_CENTERS[deck]
        G.FUNCS.start_run(nil,{seed=m.seed,stake=m.stake})
        status('Replayer starting - '..#run.actions..' actions')
    end
    function M.stop() M.active=false;status('Replayer stopped at action '..tostring(M.step or 0)) end
    function M.update(dt)
        if M.session and G.STAGE==G.STAGES.MAIN_MENU and (M.started or not M.active) then
            M.active=false;M.session=false;M.started=false
            MP.GHOST.clear();MP.LOBBY.config=previous_config;MP.SP=previous_sp;MP.MODIFIERS=previous_modifiers;G.F_NO_SAVING=previous_saving
            SMODS.Mods.Multiplayer.config=previous_mod_config
            local ruleset_name=(MP.get_active_ruleset() or ''):gsub('^ruleset_mp_','')
            MP.LoadReworks(ruleset_name)
            status('Replayer: returned to menu');return
        end
        if not M.active then return end
        if M.awaiting_start then waiting=waiting+dt;assert(waiting<timeout,'New replay run did not initialize');return end
        if G.STAGE~=G.STAGES.RUN then return end
        M.started=true
        local run=M.runs[M.index];local action=run.actions[M.step]
        -- Finish before the stall timer: the last action can leave the game in a
        -- menu or an overlay that would otherwise look like a hang.
        if not action then
            local drift=(driver.diverged or 0)>0 and (' - '..driver.diverged..' card(s) differed from the log') or ''
            M.active=false;status((run.complete and 'Replayer complete - recording available' or 'Replayer reached end of partial log')..drift);return
        end
        if G.OVERLAY_MENU or G.SETTINGS.paused then return end
        waiting=waiting+dt
        assert(waiting<timeout,'Timed out on action '..M.step..' ('..action.op..') during '..phase()..(driver.pending and ' - waiting for '..driver.pending or ''))
        if not rec.ok then error('Action Recorder stopped writing') end
        if not G.STATE_COMPLETE then return end
        for _,locked in pairs((G.CONTROLLER or {}).locks or {}) do if locked then return end end
        -- Wait for the game event queue before attempting the next input.
        for _,queue in pairs((G.E_MANAGER or {}).queues or {}) do
            for _,event in pairs(queue) do if event.blocking and not event.complete then return end end
        end
        elapsed=elapsed+dt;if elapsed<0.5 then return end;elapsed=0
        local recorded=rec.action_count or 0
        if driver.step(action) then
            assert(rec.ok and (rec.action_count or 0)>recorded,'Action was not accepted by Action Recorder at step '..M.step)
            if action.op=='reorder' and rec.reset_orders then rec.reset_orders() end
            -- A drifted card is reported but never stops the replay; the run
            -- keeps following the log's positions to the end.
            local difference=driver.difference and (' - card differs: '..driver.difference) or ''
            driver.difference=nil
            M.step=M.step+1;waiting=0;reported=nil;status('Replayer '..(M.step-1)..'/'..#run.actions..' - '..action.op..difference)
        elseif driver.pending and driver.pending~=reported then
            -- Report a new hold-up once, so the panel explains a long pause
            -- without writing a status line on every frame.
            reported=driver.pending
            status('Replayer '..M.step..'/'..#run.actions..' ('..action.op..') - waiting for '..driver.pending)
        end
    end
    -- A replay session must never send logged moves to a live server, even through other mod hooks.
    local guarded_client
    local previous_start=Game.start_run
    if previous_start then
        function Game:start_run(...)
            local function pack(...) return {n=select('#',...),...} end
            local result=pack(previous_start(self,...))
            if M.session and M.awaiting_start then
                M.awaiting_start=false;M.started=true;waiting=0
                protect(function()
                    local manifest=M.runs[M.index].manifest
                    local seed=(G.GAME.pseudorandom or {}).seed
                    local deck=((((G.GAME.selected_back or {}).effect or {}).center or {}).key)
                    assert(same_seed(seed,manifest.seed),'New run seed '..tostring(seed)..' differs from the log seed '..tostring(manifest.seed))
                    assert(deck==M.deck,'New run deck '..tostring(deck)..' differs from the log deck '..tostring(M.deck))
                    assert(rec.ok and rec.path,'Action Recorder did not start a recording for the new run')
                end)
            end
            return unpack(result,1,result.n)
        end
    end
    local previous_update=Game.update
    function Game:update(dt)
        if Client and Client~=guarded_client and type(Client.send)=='function' then
            guarded_client=Client;local send=Client.send
            Client.send=function(...) if not M.session then return send(...) end end
        end
        local function pack(...) return {n=select('#',...),...} end
        local result=pack(previous_update(self,dt))
        protect(function() M.update(dt) end)
        return unpack(result,1,result.n)
    end
    local previous_drop=love.filedropped
    love.filedropped=function(file)
        if file:getFilename():lower():match('%.log$') then
            protect(function()
                assert(not M.session,'Finish the replay session before importing')
                assert(file:getSize()<=16*1024*1024,'Log exceeds 16 MB')
                file:open('r');local text=file:read();file:close();M.import(text)
            end)
        elseif previous_drop then return previous_drop(file) end
    end
    G.FUNCS.bobs_replayer_load=function() protect(function()
        assert(not M.session,'Finish the replay session before importing')
        local path=pick_file()
        if not path then return end
        local info=NFS.getInfo(path);assert(info and info.type=='file' and info.size and info.size<=16*1024*1024,'Select a log file smaller than 16 MB')
        local text=assert(NFS.read(path),'Could not read the selected log');M.import(text)
    end) end
    G.FUNCS.bobs_replayer_next=function() if M.runs and not M.session then M.index=M.index%#M.runs+1;status('Replayer: run '..M.index..'/'..#M.runs..' - '..#M.runs[M.index].actions..' actions') end end
    G.FUNCS.bobs_replayer_start=function() protect(M.start) end
    G.FUNCS.bobs_replayer_stop=function() M.stop() end
    local previous_tab=mod.config_tab
    mod.config_tab=function()
        local tab=previous_tab and previous_tab() or {nodes={}}
        tab.nodes[#tab.nodes+1]={n=G.UIT.R,config={align='cm',padding=0.08},nodes={{n=G.UIT.T,config={ref_table=M,ref_value='status',scale=0.25,colour=G.C.WHITE,maxw=9}}}}
        local nodes={}
        for _,item in ipairs({{'Load Log','bobs_replayer_load'},{'Next run','bobs_replayer_next'},{'Start Replayer','bobs_replayer_start'},{'Stop Replayer','bobs_replayer_stop'}}) do
            nodes[#nodes+1]={n=G.UIT.C,config={align='cm',button=item[2],colour=G.C.BLUE,padding=0.12,r=0.1},nodes={{n=G.UIT.T,config={text=item[1],scale=0.28,colour=G.C.WHITE}}}}
        end
        tab.nodes[#tab.nodes+1]={n=G.UIT.R,config={align='cm',padding=0.08},nodes=nodes};return tab
    end
    return M
end
