local files={}
G={FUNCS={},STAGE=1,STAGES={RUN=1},STATES={SHOP=1},STATE=1,STATE_COMPLETE=true,GAME={current_round={},round_resets={}},UIT={},C={}}
Card={}
love={timer={getTime=function() return 1 end},filesystem={createDirectory=function() return true end,write=function(p,t) files[p]=t;return true end,append=function(p,t)files[p]=(files[p] or '')..t;return true end,getInfo=function(p)return files[p] and {} end}}
Game={start_run=function(self,args) G.GAME={current_round={},round_resets={}};return nil,9 end,update=function(self,dt)return 'updated',nil,dt end}
SMODS={current_mod={id='BalatroObserver',version='1.3.0',path='.'},load_file=function(name)return loadfile((name:gsub("^action%-recorder/","")))end}
BalatroObserver={}
dofile('../mod/launcher.lua')(function() return true end,SMODS.current_mod)
dofile('init.lua')(SMODS.current_mod,dofile('mod/json.lua'))
local function pack(...)return{n=select('#',...),...}end
local result=pack(Game:start_run({}));assert(result.n==2 and result[1]==nil and result[2]==9)
local first=BalatroActionRecorder.path;assert(files[first]:find('"partial":false'))
local update=pack(Game:update(.2));assert(update.n==3 and update[1]=='updated' and update[2]==nil and update[3]==.2)
Game:start_run({savetext={}});assert(BalatroActionRecorder.path~=first and files[BalatroActionRecorder.path]:find('"partial":true'))
assert(type(SMODS.current_mod.config_tab)=='function')
assert(SMODS.current_mod.config_tab().nodes[1].config.button=='bobs_open_viewer')
assert(SMODS.current_mod.config_tab().nodes[3].config.button=='barec_open_recorder')
assert(#SMODS.current_mod.config_tab().nodes==4)
print('PASS: integrated entry point, game lifecycle, resumed segments, preserved return values and settings integration')
