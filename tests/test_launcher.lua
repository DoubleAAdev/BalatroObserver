local opened,draws,created,launches=0,0,0,0
local now,response,request=0,nil,nil
G={FUNCS={},STAGE=1,STAGES={RUN=1},UIT={ROOT=1,R=2,T=3},C={CLEAR={},BLUE={},WHITE={}}}
love={system={getOS=function() return 'Windows' end,openURL=function(url) assert(url=='http://127.0.0.1:8765');opened=opened+1;return true end},timer={getTime=function() return now end},filesystem={createDirectory=function() end,getSaveDirectory=function() return 'C:/save' end,read=function() return response end}}
BalatroObserver={}
CardArea={draw=function() draws=draws+1 end}
local original_draw=CardArea.draw
local mod={}
dofile('mod/launcher.lua')(function(id,file) request=id;launches=launches+1;assert(file=='C:/save/balatro_observer/viewer-launch-status.txt');return true end,mod)
assert(CardArea.draw==original_draw)
assert(mod.config_tab().nodes[1].config.button=='bobs_open_viewer')
assert(mod.config_tab().nodes[1].nodes[1].config.ref_table==BalatroObserver)
G.FUNCS.bobs_open_viewer();G.FUNCS.bobs_open_viewer();assert(launches==1 and opened==0)
response='stale:ready';BalatroObserver.poll_launch();assert(opened==0)
response=request..':ready';BalatroObserver.poll_launch();BalatroObserver.poll_launch();assert(opened==1)
G.FUNCS.bobs_open_viewer();response=request..':error';BalatroObserver.poll_launch();assert(BalatroObserver.launch_label=='Viewer failed - retry' and opened==1)
G.FUNCS.bobs_open_viewer();now=16;BalatroObserver.poll_launch();assert(BalatroObserver.launch_label=='Viewer failed - retry')
G.FUNCS.bobs_open_viewer();response=request..':ready';BalatroObserver.poll_launch();assert(opened==2)
print('PASS: native browser handoff waits for matching readiness; duplicate clicks, stale replies, errors, timeout and retry')
