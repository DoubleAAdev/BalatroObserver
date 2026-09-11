-- Button lookup must match how Balatro builds UI: a UIBox keeps its elements on
-- UIRoot (never in children) and embeds other boxes as config.object.
local JSON=dofile('mod/json.lua')
local parser=dofile('replayer/parser.lua')(function() return {} end)
local files,now={},0
love={timer={getTime=function()return now end},filesystem={createDirectory=function()return true end,
    write=function(p,t)files[p]=t;return true end,append=function(p,t)files[p]=(files[p] or '')..t;return true end}}

local function element(config,children) return {config=config or {},children=children or {}} end
local function uibox(root) local box={config={},children={},UIRoot=root};root.parent=box;return box end

G={STAGES={RUN=1},STAGE=1,STATE_COMPLETE=true,SETTINGS={},FUNCS={},CONTROLLER={locks={}},
    STATES={SELECTING_HAND=1,SHOP=2,ROUND_EVAL=3,BLIND_SELECT=4},STATE=4,
    P_BLINDS={bl_small={key='bl_small'},bl_big={key='bl_big'},bl_boss={key='bl_boss'}},
    GAME={current_round={},blind_on_deck='Small',round_resets={blind_choices={Small='bl_small',Big='bl_big',Boss='bl_boss'},blind_tags={}}},
    I={UIBOX={}}}
Card={}
MP={GAME={}}

-- Every blind column carries its own select/skip button, so an unscoped search
-- can press the wrong blind; the boss column is listed first on purpose.
local panels,selects={},{}
for _,slot in ipairs({'Boss','Big','Small'}) do
    local key=({Boss='bl_boss',Big='bl_big',Small='bl_small'})[slot]
    local select_node=element({id='select_blind_button',button='select_blind',ref_table=G.P_BLINDS[key]})
    local skip_node=element({button='skip_blind',ref_table={slot=slot}})
    local box=uibox(element({},{element({},{select_node}),element({},{skip_node})}))
    panels[slot:lower()]=box;selects[slot]=select_node
    G.I.UIBOX[#G.I.UIBOX+1]=box
end
G.blind_select_opts=panels
-- The parent box reaches each column through config.object, like the real one.
G.blind_select=uibox(element({},{element({object=panels.small}),element({object=panels.big}),element({object=panels.boss})}))
G.I.UIBOX[#G.I.UIBOX+1]=G.blind_select

local rec=dofile('action-recorder/mod/recorder.lua')(JSON,'test')
local hooks=dofile('action-recorder/mod/hooks.lua')(rec,JSON)
local chosen,skipped,cashed,packs=nil,nil,0,0
G.FUNCS.select_blind=function(e) chosen=e.config.ref_table.key end
G.FUNCS.skip_blind=function(e) skipped=e.config.ref_table.slot end
G.FUNCS.cash_out=function(e) cashed=cashed+1;e.config.button=nil end
G.FUNCS.skip_booster=function() packs=packs+1 end
hooks.install();rec.begin(false)
local driver=dofile('replayer/driver.lua')(parser,rec,JSON)

-- The whole tree is reachable only through UIRoot; children alone find nothing.
assert(driver.button('select_blind'),'select_blind button must be reachable from a UIBox')
assert(driver.button('select_blind',G.blind_select),'nested boxes must be reached through config.object')
assert(driver.button('select_blind',panels.small)==selects.Small)
assert(not driver.button('select_blind',element({})),'a bare element holds no buttons')

assert(driver.step({op='select_blind',args={'0'}}))
assert(chosen=='bl_small','the on-deck blind decides which column is pressed, not UIBox order')
assert(files[rec.path]:find('"key":"bl_small"'))
assert(MP.GAME.ready_blind==false)

G.GAME.blind_on_deck='Boss'
assert(driver.step({op='skip_blind',args={'0'}}) and skipped=='Boss')

-- A missing column falls back to the blind the manifest is on.
G.blind_select_opts=nil
chosen=nil;G.GAME.blind_on_deck='Big'
assert(driver.step({op='select_blind',args={'0'}}) and chosen=='bl_big')

-- Booster skip: the button sits inside a box nested two levels deep.
local skip_pack=element({button='skip_booster'})
local inner=uibox(element({},{skip_pack}))
G.I.UIBOX={uibox(element({},{element({object=inner})}))}
G.STATE=1
assert(driver.step({op='pack_skip',args={'0'}}) and packs==1)

-- Cash-out is inferred, never logged, and must not depend on a live button node.
G.STATE=3;G.round_eval={};G.I.UIBOX={}
assert(driver.step({op='play',args={'1'}})==false and cashed==1)
G.round_eval=nil
assert(driver.step({op='play',args={'1'}})==false and cashed==1)

-- A cycle through config.object must not trap the search.
local loop=element({});loop.config.object={UIRoot=loop}
assert(driver.button('nothing',loop)==nil)

print('PASS: UIRoot traversal, nested boxes, on-deck blind scoping, booster skip, inferred cash-out and cycle safety')
