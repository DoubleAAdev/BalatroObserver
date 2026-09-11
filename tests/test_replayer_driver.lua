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
local used,bought=nil,nil
G.FUNCS.use_card=function(e) used=e.config.ref_table end
G.FUNCS.buy_from_shop=function(e) bought=e.config.ref_table end
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
G.STATE=2
G.consumeables={cards={shop_card('The Fool','Tarot')}}
G.shop_booster={cards={shop_card('Arcana Pack','Booster')}}
G.shop_vouchers={cards={shop_card('Overstock','Voucher')}}
G.shop_jokers={cards={shop_card('Blueprint','Joker')}}

-- Resolution happens over the whole stream before playback: a use answered by a
-- pack action opened the booster shelf, and a use carrying hand targets is a
-- consumable. Actions that can happen with a pack open do not break the pairing.
local resolved=driver.resolve({
    {n=1,op='use',args={'1'}},{n=2,op='reorder',args={'4','2.1'}},{n=3,op='pack_skip',args={'0'}},
    {n=4,op='use',args={'1','2.3'}},{n=5,op='use',args={'1'}},{n=6,op='reroll',args={}}})
assert(resolved[1].area=='shop_booster','a pack action after a use means a booster was opened')
assert(resolved[4].area=='consumeables','hand targets mean a consumable')
assert(resolved[5].area==nil,'nothing in the stream settles this one')
assert(driver.step(resolved[1]) and used==G.shop_booster.cards[1])

-- With nothing resolved, the game rules out what it would refuse right now.
G.FUNCS.can_use_consumeable=function(e) e.config.button=nil end
G.FUNCS.can_redeem=function(e) e.config.button='use_card' end
G.FUNCS.can_open=function(e) e.config.button=nil end
assert(driver.step(resolved[5]) and used==G.shop_vouchers.cards[1],'only the voucher was acceptable')
-- When the game would take either, a bare slot means the consumable.
G.FUNCS.can_use_consumeable=function(e) e.config.button='use_card' end
assert(driver.step({op='use',args={'1'}}) and used==G.consumeables.cards[1])
-- A slot only one area has is never ambiguous in the first place.
G.consumeables={cards={}};G.shop_vouchers={cards={}};G.shop_jokers={cards={}}
G.FUNCS.can_open=function(e) e.config.button='use_card' end
assert(driver.step({op='use',args={'1'}}) and used==G.shop_booster.cards[1])

-- The point of the mirrored name: a drifted shop still holds the card the run
-- bought, one slot over, and the log's slot must not win over the card itself.
G.STATE=2
G.shop_jokers={cards={shop_card('Square Joker','Joker'),shop_card('Mail-In Rebate','Joker')}}
G.consumeables={cards={}};G.shop_vouchers={cards={}};G.shop_booster={cards={}}
driver.moved=0
assert(driver.step({op='buy',args={'1','1'},name='Mail-In Rebate'}))
assert(bought==G.shop_jokers.cards[2],'the named card wins over the logged slot')
assert(driver.moved==1 and driver.movement=='buy found at slot 2, log said 1',tostring(driver.movement))
-- A card sitting where the log said is not reported as moved.
assert(driver.step({op='buy',args={'1','1'},name='Square Joker'}) and bought==G.shop_jokers.cards[1])
assert(driver.moved==1)
-- Modded cards are logged by centre key, and match on that too.
G.shop_jokers={cards={shop_card('Blueprint','Joker'),shop_card('Hanging Chad','Joker')}}
G.shop_jokers.cards[2].config.center.key='j_mp_hanging_chad'
assert(driver.step({op='buy',args={'1','1'},name='j_mp_hanging_chad'}) and bought==G.shop_jokers.cards[2])
-- A name the run no longer holds falls back to the logged slot rather than
-- skipping the purchase entirely.
assert(driver.step({op='buy',args={'1','2'},name='Gone Forever'}) and bought==G.shop_jokers.cards[2])
-- Two copies are ambiguous, so the slot decides.
G.shop_jokers={cards={shop_card('Splash','Joker'),shop_card('Splash','Joker')}}
assert(driver.step({op='buy',args={'1','1'},name='Splash'}) and bought==G.shop_jokers.cards[1])
-- A use finds its card in whichever area now holds it.
G.shop_booster={cards={shop_card('Arcana Pack','Booster'),shop_card('Buffoon Pack','Booster')}}
G.consumeables={cards={shop_card('The Fool','Tarot')}}
G.FUNCS.can_open=function(e) e.config.button='use_card' end
assert(driver.step({op='use',args={'1'},name='Buffoon Pack'}) and used==G.shop_booster.cards[2])

-- Closing the shop or a pack leaves the CardArea in G with cards set to nil,
-- exactly as CardArea:remove does; scanning it must not crash.
G.consumeables={cards={shop_card('The Fool','Tarot')}}
G.shop_booster.cards=nil;G.shop_vouchers={cards=nil};G.shop_jokers.cards=nil;G.pack_cards={cards=nil}
G.STATE=1
assert(driver.step({op='use',args={'1'}}) and used==G.consumeables.cards[1])
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

print('PASS: UIRoot traversal, nested boxes, on-deck blind scoping, booster skip, inferred cash-out, cycle safety, named waiting reasons, positional use resolution, locating logged cards in the live game, removed card areas and forced selections')
