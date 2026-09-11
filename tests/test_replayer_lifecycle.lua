local JSON=dofile('mod/json.lua')
local writes,started,sends={},nil,0
love={filesystem={createDirectory=function()return true end,write=function(p,t)writes[p]=t;return true end},timer={getTime=function()return 0 end}}
G={STAGE=0,STAGES={MAIN_MENU=0,RUN=1},FUNCS={},GAME={},P_CENTERS={b_red={key='b_red'}},SETTINGS={},UIT={},C={}}
local original_config={ruleset='old',cocktail='old',starting_lives=4};local original_sp={practice=false}
MP={LOBBY={config=original_config},SP=original_sp,MODIFIERS={},Rulesets={ruleset_mp_test={}},GAME={enemy={}},GHOST={}}
function MP.GHOST.load(r)MP.GHOST.replay=r end
function MP.GHOST.clear()MP.GHOST.replay=nil end
function MP.GHOST.is_ruleset_supported()return true end
function MP.apply_default_modifiers()end
function MP.LoadReworks()end
function MP.reset_game_states()MP.GAME={enemy={}}end
function MP.get_active_ruleset()return 'ruleset_mp_test'end
MP.load_mp_file=function()return {process_log=function()return {{}}end,to_replay=function()return {seed='TEST',ante_snapshots={[1]={}}}end}end
local manifest={seed='TEST',deck='b_red',stake=1,ruleset='ruleset_mp_test',gamemode='gamemode_mp_attrition',mod_version='0.5.5',lobby_config={cocktail='NEW',starting_lives=6,action='bad',lobby_code='PRIVATE'}}
package.loaded.json={decode=function()return manifest end}
Client={send=function()sends=sends+1 end}
Game={update=function()return nil,42 end}
BalatroActionRecorder={ok=true}
SMODS={Mods={Multiplayer={version='0.5.5'}},load_file=function(path)return loadfile(path)end}
local mod={id='BalatroObserver',config_tab=function()return{nodes={{original=true}}}end}
function G.FUNCS.exit_overlay_menu()G.OVERLAY_MENU=nil end
function G.FUNCS.start_run(_,args)started=args;assert(G.GAME.viewed_back.key=='b_red');G.STAGE=1 end
local replay=dofile('replayer/init.lua')(mod,JSON)
local function pack(...)return{n=select('#',...),...}end
local result=pack(Game:update(0));assert(result.n==2 and result[2]==42)
replay.import('MP_RLOG: MANIFEST {}\nMP_RLOG: 1 reroll\nMP_RLOG: END {}')
assert(mod.config_tab().nodes[1].original)
assert(#mod.config_tab().nodes==3 and G.FUNCS.bobs_replayer_start)
MP.LOBBY.code='LIVE';assert(not pcall(replay.start));MP.LOBBY.code=nil
assert(not replay.session and MP.LOBBY.config==original_config)
replay.start();assert(started.seed=='TEST' and started.stake==1)
assert(MP.LOBBY.config.cocktail=='NEW' and MP.LOBBY.config.starting_lives==6)
assert(MP.LOBBY.config.lobby_code==nil and MP.LOBBY.config.action==nil and G.F_NO_SAVING)
Client.send({});assert(sends==0)
G.OVERLAY_MENU={};Game:update(1);assert(replay.active)
replay.stop();G.STAGE=0;Game:update(0)
assert(not replay.session and MP.LOBBY.config==original_config and MP.SP==original_sp and not G.F_NO_SAVING)
Client.send({});assert(sends==1)
print('PASS: config controls, manifest setup, live-lobby refusal, network isolation, return values, pause and session restoration')
