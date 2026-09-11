local JSON=dofile('mod/json.lua')
local writes,started,sends={},nil,0
love={filesystem={createDirectory=function()return true end,write=function(p,t)writes[p]=t;return true end},timer={getTime=function()return 0 end}}
G={STAGE=0,STAGES={MAIN_MENU=0,RUN=1},FUNCS={},GAME={},P_CENTERS={b_red={key='b_red',set='Back'}},SETTINGS={},UIT={},C={}}
local original_config={ruleset='old',cocktail='old',starting_lives=4};local original_sp={practice=false}
MP={LOBBY={config=original_config},SP=original_sp,MODIFIERS={},Rulesets={ruleset_mp_test={}},GAME={enemy={}},GHOST={}}
function MP.GHOST.load(r)MP.GHOST.replay=r end
function MP.GHOST.clear()MP.GHOST.replay=nil end
function MP.GHOST.is_ruleset_supported()return true end
function MP.apply_default_modifiers()end
local rework_calls=0
function MP.LoadReworks(...)
    assert(select('#',...)==1,'LoadReworks received an unintended center key')
    assert((...)=='test');rework_calls=rework_calls+1
end
function MP.reset_game_states()MP.GAME={enemy={}}end
function MP.get_active_ruleset()return 'ruleset_mp_test'end
MP.load_mp_file=function()return {process_log=function()return {{}}end,to_replay=function()return {seed='TEST',ante_snapshots={[1]={}}}end}end
local manifest={seed='TEST',deck='b_red',stake=1,ruleset='ruleset_mp_test',gamemode='gamemode_mp_attrition',mod_version='0.5.5',lobby_config={cocktail='NEW',starting_lives=6,action='bad',lobby_code='PRIVATE'}}
package.loaded.json={decode=function()return manifest end}
Client={send=function()sends=sends+1 end}
-- The Order prefixes the seed with "*", exactly as Multiplayer's patch does.
function MP.is_practice_mode()return MP.SP.practice==true end
function MP.should_use_the_order()return MP.is_practice_mode()end
Game={update=function()return nil,42 end,start_run=function(self,args)
    local seed=MP.should_use_the_order() and ('*'..args.seed) or args.seed
    G.GAME.pseudorandom={seed=seed};G.GAME.selected_back={effect={center=G.GAME.viewed_back}}
    BalatroActionRecorder.path='new-recording';return nil,7
end}
BalatroActionRecorder={ok=true}
local chosen_file,picks='selected.log',0
SMODS={Mods={Multiplayer={version='0.5.5',config={cocktail='OLD'}}},load_file=function(path)
    if path=='replayer/file-picker.lua' then return function()return function()picks=picks+1;return chosen_file end end end
    return loadfile(path)
end}
local log='MP_RLOG: MANIFEST {}\nMP_RLOG: 1 reroll\nMP_RLOG: END {}'
NFS={getInfo=function()return{type='file',size=#log}end,read=function(path)assert(path=='selected.log');return log end}
local mod={id='BalatroObserver',config_tab=function()return{nodes={{original=true}}}end}
function G.FUNCS.exit_overlay_menu()G.OVERLAY_MENU=nil end
function G.FUNCS.start_run(_,args)started=args;assert(G.GAME.viewed_back.key==BalatroReplayer.deck);G.STAGE=1 end
local replay=dofile('replayer/init.lua')(mod,JSON)
local function pack(...)return{n=select('#',...),...}end
local result=pack(Game:update(0));assert(result.n==2 and result[2]==42)
G.FUNCS.bobs_replayer_load();assert(picks==1 and replay.runs)
local selected=replay.runs;chosen_file=nil;G.FUNCS.bobs_replayer_load();assert(replay.runs==selected and picks==2)
assert(mod.config_tab().nodes[1].original)
assert(#mod.config_tab().nodes==3 and G.FUNCS.bobs_replayer_start)
MP.LOBBY.code='LIVE';assert(not pcall(replay.start));MP.LOBBY.code=nil
assert(not replay.session and MP.LOBBY.config==original_config)
replay.start();assert(started.seed=='TEST' and started.stake==1)
Game:update(0.1);assert(replay.awaiting_start and replay.step==1)
local start_result=pack(Game:start_run(started));assert(start_result.n==2 and start_result[2]==7 and replay.active and not replay.awaiting_start)
assert(G.GAME.pseudorandom.seed=='*TEST','a seed differing only by The Order marker still matches the log')
assert(MP.LOBBY.config.cocktail=='NEW' and MP.LOBBY.config.starting_lives==6)
assert(MP.LOBBY.config.lobby_code==nil and MP.LOBBY.config.action==nil and G.F_NO_SAVING)
Client.send({});assert(sends==0)
G.OVERLAY_MENU={};Game:update(1);assert(replay.active)
replay.stop();G.STAGE=0;Game:update(0)
assert(not replay.session and MP.LOBBY.config==original_config and MP.SP==original_sp and not G.F_NO_SAVING)
Client.send({});assert(sends==1)
manifest.deck='b_mp_cocktail';manifest.lobby_config.cocktail='12H'
G.P_CENTERS.b_mp_cocktail={key='b_mp_cocktail',set='Back'};MP.get_cocktail_decks=function()return{'b_red','b_blue'}end
local saved_mod_config=SMODS.Mods.Multiplayer.config
G.STAGE=1;G.OVERLAY_MENU=nil
replay.start();assert(SMODS.Mods.Multiplayer.config.cocktail=='12H')
assert(saved_mod_config.cocktail=='OLD')
Game:start_run(started);assert(replay.active and G.GAME.selected_back.effect.center.key=='b_mp_cocktail')
replay.stop();G.STAGE=0;Game:update(0)
assert(SMODS.Mods.Multiplayer.config==saved_mod_config)
assert(rework_calls==4,'Both startup and restoration must load reworks')
manifest.lobby_config.cocktail='1H';assert(not pcall(replay.start))
-- The host writes the lobby deck as a display name, a guest as a centre key.
G.P_CENTERS.b_red.name='Red Deck'
manifest.deck='Red Deck';manifest.lobby_config.cocktail='12H'
MP.UTILS={get_deck_key_from_name=function(name)return name=='Red Deck' and 'b_red' or nil end}
G.STAGE=1;replay.start();assert(replay.deck=='b_red' and G.GAME.viewed_back.key=='b_red')
assert(SMODS.Mods.Multiplayer.config==saved_mod_config,'A named deck is not the Cocktail deck')
Game:start_run(started);assert(replay.active,'A display-name deck must still match the started run')
replay.stop();G.STAGE=0;Game:update(0)
-- Without Multiplayer's helper the centre list still resolves the name.
MP.UTILS=nil;G.STAGE=1;replay.start();assert(replay.deck=='b_red')
Game:start_run(started);assert(replay.active)
replay.stop();G.STAGE=0;Game:update(0)
manifest.deck='b_red'
-- Practice mode forces The Order on; a log recorded without it must not be
-- replayed with a "*" seed and a different card pool.
manifest.the_order_enabled=false
G.STAGE=1;replay.start();assert(MP.should_use_the_order()==false)
Game:start_run(started);assert(replay.active and G.GAME.pseudorandom.seed=='TEST')
replay.stop();G.STAGE=0;Game:update(0)
original_sp.practice=true
assert(MP.should_use_the_order()==true,'the override lasts only for the replay session')
manifest.deck='b_nonexistent';assert(not pcall(replay.start))
print('PASS: config controls, manifest setup, deck name resolution, The Order seed marker and session scoping, live-lobby refusal, network isolation, return values, pause and session restoration')
