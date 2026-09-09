-- Run from repository root: lua tests/test_launcher.lua
local opened,draws,launches=0,0,0
local now,response,request=0,nil,nil
G={FUNCS={},STAGE=1,STAGES={RUN=1},UIT={ROOT=1,R=2,T=3},C={CLEAR={},BLUE={},WHITE={}}}
love={system={getOS=function() return 'Windows' end,openURL=function(url) assert(url=='http://127.0.0.1:8766');opened=opened+1;return true end},timer={getTime=function() return now end},filesystem={createDirectory=function() end,getSaveDirectory=function() return 'C:/save' end,read=function() return response end}}
BalatroActionRecorder={}
CardArea={draw=function() draws=draws+1 end}
local original_draw=CardArea.draw
local mod={}
local launch_ok=true
dofile('mod/launcher.lua')(function(id,file) request=id;launches=launches+1;assert(file=='C:/save/balatro_action_recorder/viewer-launch-status.txt');if launch_ok then return true end;return false,'PowerShell missing' end,mod)
assert(CardArea.draw==original_draw)
local tab=mod.config_tab()
assert(tab.nodes[1].config.button=='barec_open_recorder')
assert(tab.nodes[1].nodes[1].config.ref_table==BalatroActionRecorder and tab.nodes[1].nodes[1].config.ref_value=='launch_label')
assert(tab.nodes[2].nodes[1].config.ref_value=='launch_error' and BalatroActionRecorder.launch_error=='')
-- Duplicate clicks launch once; a stale reply from another request is ignored.
G.FUNCS.barec_open_recorder();G.FUNCS.barec_open_recorder();assert(launches==1 and opened==0)
response='stale:ready';BalatroActionRecorder.poll_launch();assert(opened==0)
response=request..':ready';BalatroActionRecorder.poll_launch();BalatroActionRecorder.poll_launch();assert(opened==1 and BalatroActionRecorder.launch_error=='')
-- A plain error, an error with a reason, a timeout and a failed launch each explain themselves.
G.FUNCS.barec_open_recorder();response=request..':error';BalatroActionRecorder.poll_launch()
assert(BalatroActionRecorder.launch_label=='Viewer failed - retry' and opened==1 and BalatroActionRecorder.launch_error:find('recorder%-server%-error%.log'))
G.FUNCS.barec_open_recorder();response=request..':error:Port 8766 is occupied by foo.exe (PID 7), which is not a Action Recorder viewer. Close it and retry.';BalatroActionRecorder.poll_launch()
assert(BalatroActionRecorder.launch_label=='Viewer failed - retry' and BalatroActionRecorder.launch_error:find('^Port 8766 is occupied by foo%.exe'))
assert(#BalatroActionRecorder.launch_error<=90)
G.FUNCS.barec_open_recorder();assert(BalatroActionRecorder.launch_error=='');now=16;response=nil;BalatroActionRecorder.poll_launch()
assert(BalatroActionRecorder.launch_label=='Viewer failed - retry' and BalatroActionRecorder.launch_error:find('No reply'))
launch_ok=false;G.FUNCS.barec_open_recorder();assert(BalatroActionRecorder.launch_label=='Viewer failed - retry' and BalatroActionRecorder.launch_error=='PowerShell missing');launch_ok=true
-- Retry after failure still works.
G.FUNCS.barec_open_recorder();response=request..':ready';BalatroActionRecorder.poll_launch();assert(opened==2 and BalatroActionRecorder.launch_error=='')
print('PASS: native browser handoff waits for matching readiness; duplicate clicks, stale replies, error reasons, timeout, failed launch and retry')
