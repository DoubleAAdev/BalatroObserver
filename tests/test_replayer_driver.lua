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
local used=nil
G.FUNCS.use_card=function(e) used=e.config.ref_table end
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

-- A refusal names the missing precondition, so a stall is self-explaining.
G.STATE=4;G.blind_select=nil
assert(driver.step({op='select_blind',args={'0'}})==false)
assert(driver.pending=='blind select is not open',driver.pending)
G.blind_select={};G.GAME.blind_on_deck='Small';G.I.UIBOX={}
assert(driver.step({op='select_blind',args={'0'}})==false)
assert(driver.pending:find('select_blind button on the Small blind'),driver.pending)
G.STATE=2;G.shop_jokers={cards={}}
assert(driver.step({op='buy',args={'1','2'}})==false)
assert(driver.pending=='no card in shop_jokers slot 2',driver.pending)
-- A completed action clears the reason it was previously waiting on.
G.STATE=4;G.blind_select={};G.blind_select_opts=panels;G.I.UIBOX={panels.small}
assert(driver.step({op='select_blind',args={'0'}}) and driver.pending==nil)

-- `use` logs a slot but no area. When the run's contents have drifted off the
-- log, the kind of card the log names still resolves the area.
local function card(rank) return {facing='front',base={value=rank,suit='Spades'},config={center={key='c_base'}},ability={set='Default'},states={drag={is=false}}} end
local function shop_card(name,set) return {facing='front',config={center={key='x'}},ability={name=name,set=set},base={},states={drag={is=false}}} end
G.P_CENTERS={p_buffoon={name='Buffoon Pack',set='Booster'},c_fool={name='The Fool',set='Tarot'}}
G.STATE=2
G.consumeables={cards={shop_card('The Fool','Tarot')}}
G.shop_booster={cards={shop_card('Arcana Pack','Booster')}}
driver.diverged=0
assert(driver.step({op='use',args={'1'},name='Buffoon Pack'}))
assert(used==G.shop_booster.cards[1],'a Booster name picks the booster slot even when the pack drifted')
assert(driver.diverged==1 and driver.difference=='log Buffoon Pack, run Arcana Pack',tostring(driver.difference))
-- An exact name still wins over the kind-of-card fallback, and matches are silent.
G.shop_booster.cards[1]=shop_card('Buffoon Pack','Booster')
assert(driver.step({op='use',args={'1'},name='Buffoon Pack'}) and used==G.shop_booster.cards[1])
assert(driver.diverged==1)
-- A different card in a position the log is sure of is replayed, not refused.
G.shop_jokers={cards={shop_card('Blueprint','Joker')}}
G.FUNCS.buy_from_shop=function() return nil end
assert(driver.step({op='buy',args={'1','1'},name='Mail-In Rebate'}))
assert(driver.diverged==2 and driver.difference=='log Mail-In Rebate, run Blueprint')
-- Without any name a two-area slot stays genuinely ambiguous.
assert(not pcall(driver.step,{op='use',args={'1'}}))

-- Closing the shop or a pack leaves the CardArea in G with cards set to nil,
-- exactly as CardArea:remove does; scanning it must not crash.
G.shop_booster.cards=nil;G.shop_vouchers={cards=nil};G.shop_jokers.cards=nil;G.pack_cards={cards=nil}
G.STATE=1
assert(driver.step({op='use',args={'1'},name='The Fool'}) and used==G.consumeables.cards[1])
assert(driver.step({op='pack_pick',args={'1'}})==false and driver.pending=='no card in pack_cards slot 1')
assert(driver.step({op='buy',args={'1','1'}})==false)
G.jokers={cards=nil}
assert(driver.step({op='reorder',args={'4','2.1'}})==false and driver.pending=='jokers does not exist yet')

-- A boss blind keeps a forced card highlighted through unhighlight_all; the
-- driver must not add it twice and read that back as a rejected selection.
local forced=card('Ace')
G.hand={cards={forced,card('King'),card('Queen')},highlighted={}}
function G.hand:unhighlight_all() self.highlighted={forced} end
function G.hand:add_to_highlighted(c) table.insert(self.highlighted,c) end
G.STATE=1;G.FUNCS.play_cards_from_highlighted=function() end
assert(driver.step({op='play',args={'1.2'}}))
assert(#G.hand.highlighted==2,'a forced card is kept, not duplicated')

print('PASS: UIRoot traversal, nested boxes, on-deck blind scoping, booster skip, inferred cash-out, cycle safety, named waiting reasons, drift-tolerant card resolution, removed card areas and forced selections')
