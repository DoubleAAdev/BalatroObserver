-- Playback must reach the end of the log. An action the drifted run cannot
-- perform is skipped and counted; only a dead recorder ends the session.
local JSON=dofile('mod/json.lua')
local writes={}
love={filesystem={createDirectory=function()return true end,write=function(p,t)writes[p]=t;return true end},timer={getTime=function()return 0 end}}
G={STAGE=0,STAGES={MAIN_MENU=0,RUN=1},STATES={SHOP=2},STATE=2,STATE_COMPLETE=true,
    FUNCS={},GAME={},P_CENTERS={b_red={key='b_red',set='Back'}},SETTINGS={},UIT={},C={},
    CONTROLLER={locks={wipe=false}},E_MANAGER={queues={base={},other={}}}}
MP={LOBBY={config={ruleset='old'}},SP={practice=false},MODIFIERS={},Rulesets={ruleset_mp_test={}},GAME={enemy={}},GHOST={}}
function MP.GHOST.load()end
function MP.GHOST.clear()end
function MP.GHOST.is_ruleset_supported()return true end
function MP.apply_default_modifiers()end
function MP.LoadReworks()end
function MP.reset_game_states()MP.GAME={enemy={}}end
function MP.get_active_ruleset()return 'ruleset_mp_test'end
MP.load_mp_file=function()return {process_log=function()return {{}}end,to_replay=function()return {seed='TEST',ante_snapshots={[1]={}}}end}end
local manifest={seed='TEST',deck='b_red',stake=1,ruleset='ruleset_mp_test',gamemode='gamemode_mp_attrition',mod_version='0.5.5',lobby_config={}}
package.loaded.json={decode=function()return manifest end}
BalatroActionRecorder={ok=true,action_count=0}

-- A stub driver stands in for the game: action 2 throws, action 3 refuses from a
-- stable state forever, action 4 is a transition the driver set in motion that
-- needs longer than a standing refusal is given, and the rest succeed.
local attempted,tries,stub={},{},{}
function stub.supports() return true end
function stub.resolve(actions) return actions end
function stub.step(action)
    attempted[#attempted+1]=action.n
    tries[action.n]=(tries[action.n] or 0)+1
    stub.transient=false
    if action.n==2 then error('Game rejected buy_from_shop') end
    if action.n==3 then stub.pending='no card in shop_jokers slot 1';return false end
    if action.n==4 and tries[4]<=6 then stub.pending='cashing out before the next action';stub.transient=true;return false end
    BalatroActionRecorder.action_count=BalatroActionRecorder.action_count+1
    return true
end
SMODS={Mods={Multiplayer={version='0.5.5',config={}}},load_file=function(path)
    if path=='replayer/file-picker.lua' then return function()return function()return nil end end end
    if path=='replayer/driver.lua' then return function()return function()return stub end end end
    return loadfile(path)
end}
Game={update=function()end,start_run=function(self,args)
    G.GAME.pseudorandom={seed=args.seed};G.GAME.selected_back={effect={center=G.GAME.viewed_back}}
    BalatroActionRecorder.path='new-recording'
end}
function G.FUNCS.exit_overlay_menu()end
function G.FUNCS.start_run(_,args)G.STAGE=1 end

local replay=dofile('replayer/init.lua')({id='BalatroObserver'},JSON)
replay.import('MP_RLOG: MANIFEST {}\nMP_RLOG: 1 reroll\nMP_RLOG: 2 buy 1 1\nMP_RLOG: 3 reroll\nMP_RLOG: 4 reroll\nMP_RLOG: END {}')
assert(#replay.runs[1].actions==4)
replay.start();Game:start_run({seed='TEST'})
assert(replay.active and replay.step==1)

-- Action 3 refuses identically from a stable state, so it is dropped after a
-- few passes rather than burning the whole budget.
local passes=0
for _=1,40 do if replay.active then passes=passes+1;Game:update(1) end end
assert(not replay.active,'playback must finish rather than hang')
assert(replay.step==5,'every action is stepped past: '..tostring(replay.step))
assert(replay.skipped==2,'the throwing and the impossible action are both skipped')
assert(attempted[1]==1 and attempted[2]==2,'a throwing action does not stop the run')
assert(attempted[#attempted]==4,'the run continues past what it could not do')
assert(replay.status:find('Replayer complete') and replay.status:find('2 skipped'),replay.status)
assert(tries[3]<=3,'a standing refusal is dropped after a few passes, not a dozen: '..tostring(tries[3]))
assert(tries[4]==7,'a transition the driver started gets the longer budget: '..tostring(tries[4]))

-- A dead recorder is the one failure worth ending the session for.
BalatroActionRecorder.action_count=0;attempted={}
G.STAGE=0;Game:update(0);G.STAGE=1
replay.start();Game:start_run({seed='TEST'})
BalatroActionRecorder.ok=false
Game:update(1)
assert(not replay.active and replay.status:find('Action Recorder stopped writing'),replay.status)

print('PASS: playback skips what it cannot perform, counts it, reaches the end of the log, drops standing refusals fast while giving real transitions time, and stops only for a dead recorder')
