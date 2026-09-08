-- Run from repository root: lua tests/test_launcher.lua
local opened,draws,launches=0,0,0
local now,response,request=0,nil,nil
G={FUNCS={},STAGE=1,STAGES={RUN=1},UIT={ROOT=1,R=2,T=3},C={CLEAR={},BLUE={},WHITE={}}}
love={system={getOS=function() return 'Windows' end,openURL=function(url) assert(url=='http://127.0.0.1:8765');opened=opened+1;return true end},timer={getTime=function() return now end},filesystem={createDirectory=function() end,getSaveDirectory=function() return 'C:/save' end,read=function() return response end}}
BalatroObserver={}
CardArea={draw=function() draws=draws+1 end}
local original_draw=CardArea.draw
local mod={}
local launch_ok=true
dofile('mod/launcher.lua')(function(id,file) request=id;launches=launches+1;assert(file=='C:/save/balatro_observer/viewer-launch-status.txt');if launch_ok then return true end;return false,'PowerShell missing' end,mod)
assert(CardArea.draw==original_draw)
local tab=mod.config_tab()
assert(tab.nodes[1].config.button=='bobs_open_viewer')
assert(tab.nodes[1].nodes[1].config.ref_table==BalatroObserver and tab.nodes[1].nodes[1].config.ref_value=='launch_label')
assert(tab.nodes[2].nodes[1].config.ref_value=='launch_error' and BalatroObserver.launch_error=='')
-- Duplicate clicks launch once; a stale reply from another request is ignored.
G.FUNCS.bobs_open_viewer();G.FUNCS.bobs_open_viewer();assert(launches==1 and opened==0)
response='stale:ready';BalatroObserver.poll_launch();assert(opened==0)
response=request..':ready';BalatroObserver.poll_launch();BalatroObserver.poll_launch();assert(opened==1 and BalatroObserver.launch_error=='')
-- A plain error, an error with a reason, a timeout and a failed launch each explain themselves.
G.FUNCS.bobs_open_viewer();response=request..':error';BalatroObserver.poll_launch()
assert(BalatroObserver.launch_label=='Viewer failed - retry' and opened==1 and BalatroObserver.launch_error:find('viewer%-launch%.log'))
G.FUNCS.bobs_open_viewer();response=request..':error:Port 8765 is occupied by foo.exe (PID 7), which is not a Balatro Observer viewer. Close it and retry.';BalatroObserver.poll_launch()
assert(BalatroObserver.launch_label=='Viewer failed - retry' and BalatroObserver.launch_error:find('^Port 8765 is occupied by foo%.exe'))
assert(#BalatroObserver.launch_error<=90)
G.FUNCS.bobs_open_viewer();assert(BalatroObserver.launch_error=='');now=16;response=nil;BalatroObserver.poll_launch()
assert(BalatroObserver.launch_label=='Viewer failed - retry' and BalatroObserver.launch_error:find('No reply'))
launch_ok=false;G.FUNCS.bobs_open_viewer();assert(BalatroObserver.launch_label=='Viewer failed - retry' and BalatroObserver.launch_error=='PowerShell missing');launch_ok=true
-- Retry after failure still works.
G.FUNCS.bobs_open_viewer();response=request..':ready';BalatroObserver.poll_launch();assert(opened==2 and BalatroObserver.launch_error=='')
print('PASS: native browser handoff waits for matching readiness; duplicate clicks, stale replies, error reasons, timeout, failed launch and retry')
