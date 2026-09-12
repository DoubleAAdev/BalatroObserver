-- One replay session: the game is put into the lobby the log was played in,
-- the log's inputs are performed and the opponent's messages are delivered
-- again in the recorded order, and every MP_RLOG line the game writes while
-- doing so is compared with the line the original game wrote.
--
-- Multiplayer only draws from its own card pools, applies its rulesets and
-- resolves PvP rounds while MP.LOBBY.code is set, so the session emulates the
-- lobby instead of using practice mode. Nothing reaches the server: Client
-- messages are dropped for the whole session.
return function(log, driver, JSON, deps)
    local S = {phase = 'idle', text = 'Replayer: choose Load Log to pick a Multiplayer log', index = 1,
        strict = false, strict_label = 'On a difference: skip it'}
    local directory = 'balatro_replayer'
    local clock = deps.clock
    local session, saved
    local auto_ops = {set_ante_key = true, net_asteroid = true, net_pizza = true, net_magnet = true, net_phantom_add = true, net_phantom_remove = true}
    -- Messages a replay may still send: none change a game.
    local allowed_sends = {username = true, version = true, keepAliveAck = true, connect = true}
    local SETTLE, STALL, RECORD, BLOCKED = 0.4, 45, 20, 10
    -- Dollars are reconciled over this many inputs: see S.money.
    local WINDOW = 3

    local function debug(text)
        if sendDebugMessage then sendDebugMessage(text, 'BalatroObserver') end
    end

    local function recorder() return BalatroActionRecorder end

    local function write_status()
        local state = {phase = S.phase, status = S.text, step = session and session.done or 0,
            total = session and session.run.actions or 0, recording = recorder() and recorder().path or nil,
            strict = S.strict}
        if session and session.failure then state.failure = session.failure end
        if session and session.differences and #session.differences > 0 then
            state.differences = JSON.array()
            for _, item in ipairs(session.differences) do state.differences[#state.differences + 1] = item end
        end
        pcall(function()
            love.filesystem.createDirectory(directory)
            love.filesystem.write(directory .. '/status.json', JSON.encode(state))
        end)
    end

    function S.status(text)
        S.text = text
        debug(text)
        write_status()
    end

    local function progress()
        return (session.done or 0) .. '/' .. session.run.actions
    end

    local function list(items)
        local parts = {}
        for _, item in ipairs(items) do parts[#parts + 1] = '$' .. tostring(item) end
        if #parts == 0 then return 'nothing' end
        return table.concat(parts, ', ')
    end

    local function clean(message)
        return tostring(message):gsub('^.-:%d+: ', '')
    end

    local function fail(message)
        if not session or session.failure then return end
        local entry = session.entries[session.cursor]
        local where = entry and entry.kind == 'action' and (' at action ' .. entry.seq .. ' (' .. entry.text .. ')') or ''
        session.failure = {step = session.done, message = clean(message), action = entry and entry.text or nil, line = entry and entry.line or nil}
        S.phase = 'failed'
        S.status('Replay stopped' .. where .. ': ' .. clean(message) .. ' - ' .. progress() .. ' inputs done, the run is left open')
    end
    S.fail = fail

    -- A difference between the log and what the game did. Strict stops at it;
    -- otherwise it is counted and reported and the replay carries on, so the
    -- recording still covers the rest of the log.
    local function difference(message, entry, skip)
        if not session or session.failure then return end
        if S.strict then return fail(message) end
        local text = clean(message)
        session.differences[#session.differences + 1] = {step = session.done, message = text,
            action = entry and entry.text or nil, line = entry and entry.line or nil}
        debug('Replay difference' .. (entry and entry.seq and (' at action ' .. entry.seq) or '') .. ': ' .. text)
        if skip and entry and entry.kind == 'action' then
            session.cursor = session.cursor + 1
            session.done = session.done + 1
            session.skipped = (session.skipped or 0) + 1
            session.previous = nil
            session.owed, session.seen = {}, {}
            session.issued, session.waiting_since, session.wait_reason = nil, nil, nil
            session.consumed = clock()
        end
        S.status('Replay ' .. progress() .. ' - ' .. #session.differences .. ' difference(s), latest: ' .. text)
    end

    -- Multiplayer's positional argument formatting, token for token.
    local function format_args(args)
        if args == nil then return '' end
        if type(args) ~= 'table' then return tostring(args) end
        local parts = {}
        for _, token in ipairs(args) do
            if type(token) == 'table' then
                local sub = {}
                for _, value in ipairs(token) do sub[#sub + 1] = tostring(value) end
                parts[#parts + 1] = table.concat(sub, '.')
            else
                parts[#parts + 1] = tostring(token)
            end
        end
        return table.concat(parts, ' ')
    end
    S.format_args = format_args

    -- Every dollar the game moves. The log records the same stream, so the
    -- two together catch a run that has drifted in ways the log cannot
    -- otherwise show: a card held at the end of a round, a joker that did not
    -- pay. The game credits a joker's dollars a second or two after the input
    -- that earned them, and the log, written by a player who paused between
    -- clicks, files them with that input - so the two are reconciled over a
    -- window of a few inputs instead of demanded of the input they sit under.
    function S.money(amount)
        if not session or S.phase ~= 'running' or session.failure then return end
        session.seen[#session.seen + 1] = {amount = tostring(amount), at = session.done,
            -- The cash out and the shop exit are not inputs, so the log files
            -- their money with whichever input the player made around them.
            soft = driver.transition and true or nil,
            entry = session.previous or session.entries[session.cursor]}
    end

    -- What the log says this input moved, to be matched as the money arrives.
    local function owe_money(entry)
        if not entry or entry.kind ~= 'action' or not entry.money or #entry.money == 0 then return end
        local want = {}
        for _, amount in ipairs(entry.money) do want[#want + 1] = amount end
        session.owed[#session.owed + 1] = {entry = entry, at = session.done, want = want}
    end

    -- Cancel what matches, then report whatever has outlived the window.
    local function settle_money(force)
        for index = #session.seen, 1, -1 do
            local amount = session.seen[index].amount
            for _, item in ipairs(session.owed) do
                local hit
                for slot, want in ipairs(item.want) do
                    if want == amount then table.remove(item.want, slot); hit = true; break end
                end
                if hit then table.remove(session.seen, index); break end
            end
        end
        for index = #session.owed, 1, -1 do
            local item = session.owed[index]
            if #item.want == 0 or force or session.done - item.at > WINDOW then
                if #item.want > 0 then
                    difference('the log moves ' .. list(item.want) .. ' for "' .. item.entry.text .. '" and the game never did', item.entry, false)
                end
                table.remove(session.owed, index)
            end
        end
        for index = #session.seen, 1, -1 do
            local item = session.seen[index]
            if force or session.done - item.at > WINDOW then
                local where = item.entry and item.entry.text
                if not item.soft then
                    difference('the game moved $' .. item.amount .. ' the log does not record' ..
                        (where and (' around "' .. where .. '"') or ''), item.entry, false)
                end
                table.remove(session.seen, index)
            end
        end
    end

    -- Installed over MP.RLOG.record for the session. The game reports what
    -- it just did in the same words the original game used; the next
    -- expected line must match, otherwise the replay has diverged.
    function S.record(op, args, human)
        local original = saved and saved.record
        if not session or (S.phase ~= 'running' and S.phase ~= 'starting') or session.failure then
            return original(op, args, human)
        end
        local entry = session.entries[session.cursor]
        local argstr = format_args(args)
        local actual = op .. (argstr ~= '' and (' ' .. argstr) or '')
        if not entry or entry.kind ~= 'action' then
            difference('the game recorded "' .. actual .. '" while the log expects ' .. (entry and ('the message ' .. entry.action) or 'nothing more'), entry, false)
            return original(op, args, human)
        end
        local matched
        if op == 'set_ante_key' and entry.op == 'set_ante_key' then
            -- The key is rolled with math.random when a blind starts; the
            -- logged one is put back so the run reads exactly like the log.
            matched = true
            args = entry.args[1]
            if MP and MP.GAME then MP.GAME.ante_key = entry.args[1] end
        else
            matched = actual == entry.text
        end
        -- Multiplayer passes the mirrored payload with its "action:" prefix.
        local mirrored = human and tostring(human):gsub('^action:', '') or nil
        if matched and (entry.human or mirrored) and entry.human ~= mirrored then matched = false end
        if matched then
            session.previous = entry
            session.cursor = session.cursor + 1
            session.done = session.done + 1
            owe_money(entry)
            settle_money()
            if session.failure then return original(op, args, human) end
            session.issued, session.waiting_since, session.wait_reason = nil, nil, nil
            session.consumed = clock()
            S.status('Replay ' .. progress() .. ' - ' .. actual .. (mirrored and (' - ' .. mirrored) or ''))
        else
            -- The log may simply be a few inputs ahead of what the game just
            -- did; look for it before calling the run drifted.
            local found
            for i = session.cursor + 1, math.min(session.cursor + 10, #session.entries) do
                local later = session.entries[i]
                if later.kind == 'action' and later.text == actual and later.human == mirrored then found = i break end
            end
            if found and not S.strict then
                local missed = 0
                for i = session.cursor, found - 1 do
                    if session.entries[i].kind == 'action' then missed = missed + 1 end
                end
                session.differences[#session.differences + 1] = {step = session.done,
                    message = missed .. ' input(s) the game never performed, up to "' .. actual .. '"', line = entry.line}
                session.skipped = (session.skipped or 0) + missed
                session.done = session.done + missed + 1
                session.cursor = found + 1
                session.previous = session.entries[found]
                session.owed, session.seen = {}, {}
                session.issued, session.waiting_since, session.wait_reason = nil, nil, nil
                session.consumed = clock()
                S.status('Replay ' .. progress() .. ' - resumed at "' .. actual .. '" after ' .. missed .. ' skipped')
            else
                local expected = entry.text .. (entry.human and (' | ' .. entry.human) or '')
                difference('the game did "' .. actual .. (mirrored and (' | ' .. mirrored) or '') .. '", the log says "' .. expected .. '"', entry, true)
            end
        end
        return original(op, args, human)
    end

    -- The game reports its own progress to the server as it plays: the score
    -- of every hand of a PvP round, the ante, what was spent in each shop,
    -- how far the run has come. Each is a pure function of the run's state,
    -- so each is compared with the next one of its kind in the log.
    function S.checkpoint(message)
        if not session or S.phase ~= 'running' or session.failure then return end
        local fields = log.checkpoints[message.action]
        if not fields then return end
        local from = session.checked[message.action] or 1
        local expected
        for i = from, #session.checks do
            if session.checks[i].action == message.action then
                expected = session.checks[i]
                session.checked[message.action] = i + 1
                break
            end
        end
        if not expected then
            return difference('the game reported ' .. message.action .. ' more often than the log did', nil, false)
        end
        for _, key in ipairs(fields) do
            local got, want = message[key], expected.fields[key]
            if tostring(got) ~= tostring(want) then
                local what = message.action == 'playHand' and key == 'score' and 'the hand scored ' or ('the game reported ' .. message.action .. ' ' .. key .. ' ')
                return difference(what .. tostring(got) .. ', the log says ' .. tostring(want) .. ' (log line ' .. expected.line .. ')', nil, false)
            end
        end
    end

    local function deck_key(deck)
        if type(deck) ~= 'string' then return nil end
        if ((G.P_CENTERS or {})[deck] or {}).set == 'Back' then return deck end
        for key, centre in pairs(G.P_CENTERS or {}) do
            if centre.set == 'Back' and centre.name == deck then return key end
        end
        return nil
    end

    local function split_name(text, fallback)
        if type(text) ~= 'string' then return fallback, 1 end
        local name, col = text:match('^(.-)~(%d+)$')
        return name or text, tonumber(col) or 1
    end

    local function describe_run()
        local run = S.runs[S.index]
        return 'Replayer: run ' .. S.index .. '/' .. #S.runs .. ' - ' .. run.actions .. ' inputs, seed ' ..
            run.manifest.seed .. (run.replayed and ' (recorded by a replay, not a game)' or '')
    end

    function S.load(text)
        assert(S.phase == 'idle', 'Finish the current replay before loading another log')
        S.runs = log.parse(text)
        S.index = 1
        S.status(describe_run())
    end

    function S.next_run()
        if not S.runs or S.phase ~= 'idle' then return end
        S.index = S.index % #S.runs + 1
        S.status(describe_run())
    end

    local function validate(run)
        local m = run.manifest
        assert(MP and MP.LOBBY and MP.RLOG and MP.Rulesets and MP.Gamemodes and MP.GAME, 'Multiplayer is required')
        assert(G.STAGE == G.STAGES.MAIN_MENU, 'Return to the main menu first')
        assert(not MP.LOBBY.code, 'Leave the Multiplayer lobby first')
        assert(recorder() and recorder().ok, 'Action Recorder must be enabled')
        assert(Client and type(Client.send) == 'function', 'Multiplayer networking is not loaded')
        assert(MP.Rulesets[m.ruleset], 'Ruleset ' .. m.ruleset .. ' is not installed')
        assert(MP.Gamemodes[m.gamemode], 'Game mode ' .. m.gamemode .. ' is not installed')
        assert(not m.challenge or m.challenge == '', 'Challenge runs cannot be replayed')
        local installed = SMODS.Mods and SMODS.Mods.Multiplayer
        assert(installed and installed.version == m.mod_version, 'Install Multiplayer ' .. tostring(m.mod_version) .. ' (installed: ' .. tostring(installed and installed.version) .. ')')
        local key = assert(deck_key(m.deck), 'Deck ' .. m.deck .. ' is not installed')
        local name = G.P_CENTERS[key].name or key
        assert(MP.UTILS and MP.UTILS.get_deck_key_from_name(name) == key, 'Multiplayer cannot resolve deck ' .. name)
        if key == 'b_mp_cocktail' then
            local cocktail = m.lobby_config.cocktail
            assert(type(cocktail) == 'string' and cocktail:match('^[012]+[HS]$'), 'Manifest missing Cocktail settings')
            assert(MP.get_cocktail_decks and #MP.get_cocktail_decks() + 1 == #cocktail, 'The installed Cocktail deck pool differs from the log')
        end
        return key, name
    end

    -- Consequences the game produces by itself: the ante key of every blind,
    -- the PvP blind that the server starts after Ready, and opponent effects.
    local function classify(entries)
        local previous
        for _, entry in ipairs(entries) do
            if entry.kind == 'action' then
                if auto_ops[entry.op] then
                    entry.auto = true
                elseif entry.op == 'select_blind' then
                    entry.auto = previous ~= nil and previous.op == 'ready_blind' and previous.args[1] == '1'
                end
                if entry.op ~= 'set_ante_key' then previous = entry end
            end
        end
    end
    S.classify = classify

    function S.start()
        assert(S.runs, 'Load a log first')
        assert(S.phase == 'idle', 'A replay is already running')
        local run = S.runs[S.index]
        local m = run.manifest
        local key, deck_name = validate(run)
        classify(run.entries)
        saved = {send = Client.send, record = MP.RLOG.record, record_match = MP.STATS and MP.STATS.record_match,
            modifiers = MP.MODIFIERS, sp = {}, lobby = {}}
        for k, v in pairs(MP.SP or {}) do saved.sp[k] = v end
        for _, field in ipairs({'code', 'connected', 'is_host', 'username', 'blind_col', 'host', 'guest', 'config', 'deck', 'type'}) do
            saved.lobby[field] = MP.LOBBY[field]
        end
        -- The lobby options exactly as the host had them, on top of the
        -- mod's current defaults for anything the manifest does not carry.
        MP.reset_lobby_config()
        local config = MP.LOBBY.config
        for k, v in pairs(m.lobby_config) do
            if k ~= 'action' and (type(v) == 'boolean' or type(v) == 'number' or type(v) == 'string') then config[k] = v end
        end
        config.ruleset, config.gamemode, config.back, config.stake, config.challenge = m.ruleset, m.gamemode, deck_name, m.stake, ''
        config.modifier_layers = m.modifier_layers or config.modifier_layers or ''
        if type(m.the_order_enabled) == 'boolean' then config.the_order = m.the_order_enabled end
        -- A replay runs at animation speed, not at the original pace, so the
        -- round timer would expire on its own. It changes no card.
        config.timer = false
        MP.LOBBY.deck = {back = deck_name, stake = m.stake, challenge = '', sleeve = config.sleeve, cocktail = config.cocktail}
        local lobby = run.lobby or {}
        local host_name, host_col = split_name(lobby.host, m.is_host and m.player or m.opponent or 'Host')
        local guest_name, guest_col = split_name(lobby.guest, m.is_host and (m.opponent or 'Guest') or m.player)
        MP.LOBBY.host = {username = host_name, blind_col = host_col, hash_str = '', hash = '', cached = true, config = {}}
        MP.LOBBY.guest = {username = guest_name, blind_col = guest_col, hash_str = '', hash = '', cached = true, config = {}}
        MP.LOBBY.is_host = m.is_host == true
        MP.LOBBY.username = m.player or (MP.LOBBY.is_host and host_name or guest_name)
        MP.LOBBY.blind_col = MP.LOBBY.is_host and host_col or guest_col
        MP.LOBBY.connected = true
        MP.modifiers_parse(config.modifier_layers)
        if MP.SP then MP.SP.practice = false end
        if MP.GHOST and MP.GHOST.clear then MP.GHOST.clear() end
        Client.send = function(msg)
            if type(msg) ~= 'table' or not msg.action then return end
            S.checkpoint(msg)
            if allowed_sends[msg.action] then return saved.send(msg) end
            -- Keep the trace line the real client writes, so a replay's log
            -- reads like the log it came from and the two can be compared.
            local ok, text = pcall(deps.encode, msg)
            if ok and sendTraceMessage then sendTraceMessage('Client sent message: ' .. text, 'MULTIPLAYER') end
        end
        saved.ease_dollars = ease_dollars
        ease_dollars = function(amount, instant)
            S.money(amount)
            return saved.ease_dollars(amount, instant)
        end
        MP.RLOG.record = S.record
        if MP.STATS then MP.STATS.record_match = function() end end
        session = {run = run, entries = run.entries, checks = run.checks or {}, checked = {}, cursor = 1, done = 0,
            key = key, began = clock(), tick = 0, owed = {}, seen = {}, previous = nil, differences = {}, skipped = 0}
        session.code = m.lobby_code or 'REPLAY'
        -- Setting the code is what joining a lobby does; Multiplayer notices
        -- on its next update and re-enters the menu as a lobby member.
        MP.LOBBY.code = session.code
        if G.FUNCS.exit_overlay_menu then G.FUNCS.exit_overlay_menu() end
        S.phase = 'joining'
        S.status('Replay joining lobby ' .. session.code .. ' - ' .. run.actions .. ' inputs, ' .. #run.entries .. ' entries')
    end

    local function cleanup()
        if not saved then return end
        Client.send = saved.send
        MP.RLOG.record = saved.record
        if saved.ease_dollars then ease_dollars = saved.ease_dollars end
        if MP.STATS then MP.STATS.record_match = saved.record_match end
        for field, value in pairs(saved.lobby) do MP.LOBBY[field] = value end
        MP.LOBBY.code = saved.lobby.code
        MP.MODIFIERS = saved.modifiers
        if MP.SP then for k, v in pairs(saved.sp) do MP.SP[k] = v end end
        if MP.reset_game_states then MP.reset_game_states() end
        saved = nil
    end

    local function finish()
        settle_money(true)
        if session.failure then return end
        S.phase = 'finished'
        local rec = recorder()
        local text = session.run.complete and ('Replay complete - ' .. progress() .. ' inputs') or ('Replay reached the end of a partial log - ' .. progress() .. ' inputs')
        local tally = ''
        if #session.differences > 0 then
            tally = ', ' .. #session.differences .. ' difference(s) and ' .. (session.skipped or 0) .. ' skipped input(s)'
        end
        S.status(text .. tally .. ', ' .. tostring(rec and rec.action_count or 0) .. ' recorded actions in ' .. tostring(rec and rec.path or 'no recording'))
    end

    function S.stop()
        if S.phase == 'idle' then return end
        S.phase = 'stopped'
        S.status('Replay stopped by the player - ' .. (session and progress() or ''))
        if G.STAGE == G.STAGES.RUN then
            -- Multiplayer leaves a run and returns to the menu when the lobby
            -- code goes away; the menu hook restores the rest.
            MP.LOBBY.code = nil
        else
            cleanup()
            S.phase = 'idle'
            session = nil
        end
    end

    -- Game.main_menu: the lobby transition on joining, and the way out.
    function S.on_main_menu()
        if not session then return end
        if S.phase == 'joining' then
            session.rejoined = session.rejoined or clock()
        elseif S.phase == 'running' or S.phase == 'finished' or S.phase == 'failed' or S.phase == 'stopped' then
            cleanup()
            S.phase = 'idle'
            S.status('Replayer: returned to the menu (' .. progress() .. ' inputs)')
            session = nil
        end
    end

    -- Game.start_run, after the run exists.
    function S.on_run_started()
        if not session then return end
        if S.phase == 'running' then return fail('a new run started during the replay') end
        if S.phase ~= 'starting' then return end
        local m = session.run.manifest
        local seed = ((G.GAME or {}).pseudorandom or {}).seed
        if seed ~= m.seed and seed ~= '*' .. m.seed then return fail('the run started with seed ' .. tostring(seed) .. ', the log has ' .. m.seed) end
        local deck = ((((G.GAME or {}).selected_back or {}).effect or {}).center or {}).key
        if deck ~= session.key then return fail('the run started with deck ' .. tostring(deck) .. ', the log has ' .. session.key) end
        local rec = recorder()
        if not (rec and rec.ok and rec.path) then return fail('Action Recorder did not start a recording') end
        S.phase = 'running'
        session.run_started = clock()
        session.signature, session.signature_at = nil, nil
        -- Stamp the log this replay is writing, so loading it back says so
        -- instead of looking like another game of the same seed.
        if sendTraceMessage then sendTraceMessage('MP_RLOG: REPLAY', 'MULTIPLAYER') end
        S.status('Replay running - ' .. progress() .. ' inputs')
    end

    -- The player may pause or open a menu without ending the replay.
    local function paused()
        if G.OVERLAY_MENU then return 'an overlay menu is open' end
        if (G.SETTINGS or {}).paused then return 'the game is paused' end
        return nil
    end

    local function busy()
        if not G.STATE_COMPLETE then return driver.state_name() .. ' is not complete' end
        for name, locked in pairs((G.CONTROLLER or {}).locks or {}) do
            if locked then return 'controller lock ' .. tostring(name) end
        end
        if ((G.GAME or {}).STOP_USE or 0) > 0 then return 'cards cannot be used yet' end
        if MP.GAME and MP.GAME.pvp_countdown_in_progress then return 'the PvP countdown' end
        for name, queue in pairs((G.E_MANAGER or {}).queues or {}) do
            for _, event in ipairs(queue) do
                if event.blocking and not event.complete then return 'events in the ' .. name .. ' queue' end
            end
        end
        return nil
    end

    local function deliver(entry)
        deps.channel('networkToUi'):push(deps.encode(entry.fields))
        session.delivered = clock()
        debug('Replay delivers ' .. entry.action .. ' (log line ' .. entry.line .. ')')
    end

    local function next_action(from)
        for i = from, #session.entries do
            if session.entries[i].kind == 'action' then return session.entries[i] end
        end
        return nil
    end

    -- The log's round and the game's did not end together: the log is buying
    -- in a shop the game has not reached, or playing a hand in a round the
    -- game has already won. Nothing after this point can be replayed - every
    -- later input belongs to a round that no longer lines up - so the replay
    -- stops here and says how far the recording is good for. Carrying on
    -- would perform the next round's hands inside this one.
    local function desync(entry)
        local playing = driver.state_name() == 'SELECTING_HAND'
        local why = playing
            and 'the log left this round after the hands it played and the game has not - the blind was not beaten here'
            or 'the game left this round before the log did - the blind was beaten sooner here'
        fail(why .. '. Nothing past this input lines up, so the replay stops; the recording is faithful up to input ' .. session.done)
    end

    local function waiting(reason, limit)
        local now = clock()
        session.waiting_since = session.waiting_since or now
        if reason ~= session.wait_reason then
            session.wait_reason = reason
            debug('Replay ' .. progress() .. ' waiting: ' .. reason)
        end
        local entry = session.entries[session.cursor]
        local blocked = not driver.reachable(entry)
        if now - session.waiting_since > (limit or (blocked and BLOCKED or STALL)) then
            if blocked then return desync(entry) end
            difference('waited ' .. math.floor(now - session.waiting_since) .. ' s for ' .. reason, entry, true)
        end
    end

    function S.update(dt)
        if not session then return end
        local now = clock()
        if S.phase == 'joining' then
            if not session.rejoined and G.F_NO_SAVING then session.rejoined = now end
            if not session.rejoined then
                if now - session.began > 20 then fail('Multiplayer did not enter the lobby') end
                return
            end
            local wiping = ((G.CONTROLLER or {}).locks or {}).wipe
            if G.STAGE == G.STAGES.MAIN_MENU and now - session.rejoined > 0.8 and not wiping and not G.OVERLAY_MENU then
                S.phase = 'starting'
                session.started_at = now
                deliver({action = 'startGame', fields = {action = 'startGame', seed = session.run.manifest.seed, stake = session.run.manifest.stake}, line = session.run.line})
                S.status('Replay starting run ' .. session.run.manifest.seed)
            elseif now - session.rejoined > STALL then
                fail('the menu did not settle after joining the lobby')
            end
            return
        end
        if S.phase == 'starting' then
            if now - session.started_at > STALL then fail('the run did not start') end
            return
        end
        if S.phase ~= 'running' then return end
        if MP.LOBBY.code ~= session.code then MP.LOBBY.code = session.code end
        if G.STAGE ~= G.STAGES.RUN then
            S.phase = 'stopped'
            S.status('Replay stopped: the run ended - ' .. progress() .. ' inputs')
            return
        end
        local rec = recorder()
        if not (rec and rec.ok) then return fail('Action Recorder stopped writing') end
        local entry = session.entries[session.cursor]
        if not entry then return finish() end
        if entry.kind == 'message' then
            while entry and entry.kind == 'message' do
                deliver(entry)
                session.cursor = session.cursor + 1
                entry = session.entries[session.cursor]
            end
            return
        end
        if session.issued then
            if now - session.issued > RECORD then
                difference('the game did not record "' .. entry.text .. '" after it was performed', entry, true)
            end
            return
        end
        local target = entry
        if entry.op == 'set_ante_key' then
            local following = next_action(session.cursor + 1)
            if following and following.op == 'select_blind' and not following.auto then target = following end
        end
        local halted = paused()
        if halted then
            session.waiting_since = nil
            if halted ~= session.wait_reason then session.wait_reason = halted; debug('Replay paused: ' .. halted) end
            return
        end
        if target.auto then return waiting('the game to produce "' .. target.text .. '"') end
        local reason = busy()
        if reason then return waiting(reason) end
        local signature = driver.signature()
        if signature ~= session.signature then
            session.signature, session.signature_at = signature, now
            return
        end
        if now - session.signature_at < SETTLE or now - (session.consumed or 0) < SETTLE or now - (session.delivered or 0) < SETTLE then return end
        if now - session.tick < 0.1 then return end
        session.tick = now
        -- Most callbacks write their MP_RLOG line before returning, so the
        -- cursor may already have moved on by the time perform comes back.
        local cursor = session.cursor
        local ok, result, detail = pcall(driver.perform, target, session.entries)
        if driver.note then debug('Replay ' .. progress() .. ' ' .. driver.note) end
        if not ok then return difference(result, target, true) end
        if result == 'done' then
            if session.cursor == cursor and not session.failure then session.issued = now end
            session.waiting_since, session.wait_reason = nil, nil
        else
            waiting(detail or 'the game')
        end
    end

    function S.current()
        return session and session.entries[session.cursor] or nil
    end

    function S.progress()
        return session and progress() or ''
    end

    return S
end
