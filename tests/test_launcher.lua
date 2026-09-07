local opened,draws,created=0,0,0
G={FUNCS={},STAGE=1,STAGES={RUN=1},UIT={ROOT=1,R=2,T=3},C={CLEAR={},BLUE={},WHITE={}}}
love={system={openURL=function(url) assert(url=='http://127.0.0.1:8765');opened=opened+1;return true end}}
BalatroObserver={}
CardArea={draw=function() draws=draws+1 end}
UIBox=function(config)
 created=created+1
 assert(config.config.major==G.deck and config.config.offset.y<0)
 assert(config.definition.nodes[1].config.button=='bobs_open_viewer')
 return {draw=function() end}
end
local deck=setmetatable({children={}},{__index=CardArea});G.deck=deck
dofile('launcher.lua')()
deck:draw();deck:draw()
assert(draws==2 and created==1 and opened==0)
assert(BalatroObserver.launcher_ok)
G.FUNCS.bobs_open_viewer();assert(opened==1)
local other=setmetatable({children={}},{__index=CardArea});other:draw();assert(created==1)
G.STAGE=0;deck:draw();assert(created==1)
print('PASS: one button above deck, click-only local URL, normal drawing preserved')
