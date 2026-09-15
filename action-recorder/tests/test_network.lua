local JSON=dofile('mod/json.lua')
local adapter=dofile('../mod/multiplayer.lua')
local files,now={},1
love={timer={getTime=function()return now end},filesystem={createDirectory=function()return true end,write=function(p,t)files[p]=t;return true end,append=function(p,t)files[p]=(files[p] or '')..t;return true end}}
G={STAGE=1,STAGES={RUN=1},STATE=1,STATES={SELECTING_HAND=1},STATE_COMPLETE=true,GAME={pseudorandom={seed='MPSEED'},stake=1,selected_back={effect={center={key='b_red'}}},current_round={hands_played=0},blind={config={blind={key='bl_mp_nemesis'}}}},hand={cards={}}}
MP={LOBBY={connected=true,code='PRIVATE',config={hide_score_until_played=true},is_host=true,username='Me',guest={username='Them'}},GAME={lives=3,enemy={lives=2,location='Shop',location_blind='bl_big',score_text='PRIVATE_SCORE',hands_text='4'}}}
local rec=dofile('mod/recorder.lua')(JSON,'2.0.0',adapter)
rec.begin(false)
local calls=0
sendTraceMessage=function(...)calls=calls+1;return nil,7 end
dofile('mod/network.lua')(rec)
local a,b=sendTraceMessage('Client got enemyInfo message: (score: PRIVATE_SCORE) (handsLeft: 3) (lives: 2)','MULTIPLAYER')
assert(a==nil and b==7 and calls==1)
rec.observe()
local text=files[rec.path]
assert(text:find('"noScore":true') and not text:find('PRIVATE'))
assert(text:find('"nemesis_location":"Shop"') and text:find('"nemesis_score":"???"'))
rec.observe();assert(files[rec.path]==text,'unchanged state must not generate journal spam')
G.GAME.current_round.hands_played=1;MP.GAME.enemy.score_text='4200'
sendTraceMessage('Client got enemyInfo message: (score: 4200) (handsLeft: 2)','MULTIPLAYER')
rec.observe();assert(files[rec.path]:find('"score":"4200"') and files[rec.path]:find('"nemesis_score":"4200"'))
text=files[rec.path]
sendTraceMessage('Client got receiveNemesisDeck message: (cards: PRIVATE)','MULTIPLAYER')
sendTraceMessage('Client got enemyInfo message: (score: PRIVATE)','OTHER')
assert(files[rec.path]==text)
MP.LOBBY.config.enemy_location_disabled=true
sendTraceMessage('Client got enemyLocation message: (location: PRIVATE)','MULTIPLAYER')
assert(files[rec.path]==text)
rec.observe();assert(not files[rec.path]:find('PRIVATE'))
print('PASS: ordered Multiplayer events, visible opponent changes, hidden-score/location gates, trace returns and no unrelated data')
