local parser=dofile('replayer/parser.lua')(function(text)
    assert(text=='{}');return {seed='TESTSEED',deck='b_red',ruleset='ruleset_mp_standard_ranked',gamemode='gamemode_mp_attrition',lobby_config={stake=1}}
end)
local input='MP_RLOG: MANIFEST {}\nMP_RLOG: 1 discard 2.3\nClient sent message: {"lines":["MP_RLOG: 1 discard 2.3"]}\nMP_RLOG: 2 use 1 2\nINFO :: MULTIPLAYER :: Client sent message: action:usedCard,card:The Magician\nMP_RLOG: END {}\nMP_RLOG: CHK v1 carbon=0\n'
local runs=parser.parse(input)
assert(#runs==1 and #runs[1].actions==2 and runs[1].complete and runs[1].manifest.stake==1)
-- MP_RLOG drives the action; the mirrored line names the card it touched.
assert(runs[1].actions[2].op=='use' and runs[1].actions[2].name=='The Magician')
assert(#parser.parse(input..input)==2)
for _,bad in ipairs({'MP_RLOG: 2 play 1','MP_RLOG: 1 play 1.1','MP_RLOG: 1 play 0','MP_RLOG: 1 execute os.remove','MP_RLOG: 1 reorder 8 1','MP_RLOG: 1 ready_blind 4','MP_RLOG: 1 set_ante_key os.remove'}) do
    assert(not pcall(parser.parse,'MP_RLOG: MANIFEST {}\n'..bad))
end
-- Multiplayer writes tostring(math.random()), which is not always "0.<digits>".
for _,key in ipairs({'0','1e-05','0.16979563507933'}) do
    assert(parser.parse('MP_RLOG: MANIFEST {}\nMP_RLOG: 1 set_ante_key '..key)[1].actions[1].args[1]==key)
end
-- An abandoned lobby leaves a manifest with no actions; it must not sink the log.
local abandoned=parser.parse('MP_RLOG: MANIFEST {}\nMP_RLOG: END {}\n'..input)
assert(#abandoned==1 and #abandoned[1].actions==2)
assert(not pcall(parser.parse,'MP_RLOG: MANIFEST {}\nMP_RLOG: END {}'))
-- Each action takes the first mirrored line that follows it, and only for the
-- ops that name a card.
local mirrored=parser.parse('MP_RLOG: MANIFEST {}\nMP_RLOG: 1 use 1\n:: MULTIPLAYER :: Client sent message: action:usedCard,card:Arcana Pack\n:: MULTIPLAYER :: Client sent message: action:usedCard,card:Strength\nMP_RLOG: 2 buy 1 1\n:: MULTIPLAYER :: Client sent message: action:boughtCardFromShop,card:Mail-In Rebate,cost:4\nMP_RLOG: 3 sell 4 1\n:: MULTIPLAYER :: Client sent message: action:soldCard,card:j_mp_bloodstone\nMP_RLOG: 4 reroll\n:: MULTIPLAYER :: Client sent message: action:rerollShop,cost:5\n')
assert(mirrored[1].actions[1].name=='Arcana Pack','a later mirrored line must not overwrite it')
assert(mirrored[1].actions[2].name=='Mail-In Rebate' and mirrored[1].actions[3].name=='j_mp_bloodstone')
assert(mirrored[1].actions[4].name==nil,'a reroll names no card')
local JSON=dofile('mod/json.lua')
local files,now={},1
love={timer={getTime=function()return now end},filesystem={createDirectory=function()return true end,write=function(p,t)files[p]=t;return true end,append=function(p,t)files[p]=(files[p] or '')..t;return true end}}
local function card(rank)return{facing='front',base={value=rank,suit='Spades'},config={center={key='c_base'}},ability={set='Default'},states={drag={is=false}}}end
local ace,king,queen=card('Ace'),card('King'),card('Queen')
G={STAGES={RUN=1},STAGE=1,STATES={SELECTING_HAND=1,SHOP=2,ROUND_EVAL=3,BLIND_SELECT=4},STATE=1,STATE_COMPLETE=true,SETTINGS={},GAME={current_round={},round_resets={}},FUNCS={},hand={cards={ace,king,queen},highlighted={}},play={cards={}},discard={cards={},config={card_limit=52}},CONTROLLER={locks={}}}
function G.hand:unhighlight_all()self.highlighted={}end
function G.hand:add_to_highlighted(c)table.insert(self.highlighted,c)end
Card={}
local calls=0
G.FUNCS.discard_cards_from_highlighted=function()calls=calls+1 end
G.FUNCS.can_discard=function(e)e.config.button='discard_cards_from_highlighted'end
local rec=dofile('action-recorder/mod/recorder.lua')(JSON,'test')
local hooks=dofile('action-recorder/mod/hooks.lua')(rec,JSON);hooks.install();rec.begin(false)
local driver=dofile('replayer/driver.lua')(parser,rec,JSON)
assert(driver.step(runs[1].actions[1]) and calls==1)
assert(files[rec.path]:find('"rank":"King"') and files[rec.path]:find('"rank":"Queen"'))
assert(not files[rec.path]:find('"rank":"Ace"'))
assert(not pcall(driver.step,{op='discard',args={'9'}}))
assert(driver.step({op='reorder',args={'6','3.1.2'}}));assert(G.hand.cards[1]==queen)
assert(files[rec.path]:find('"type":"reorder"'))
MP={GAME={},UI={show_asteroid_hand_level_up=function()MP.GAME.asteroids=(MP.GAME.asteroids or 0)+1 end}}
assert(driver.step({op='set_ante_key',args={'0.123'}}) and MP.GAME.ante_key=='0.123')
assert(driver.step({op='net_asteroid',args={}}) and MP.GAME.asteroids==1)
G.STATE=4;G.blind_select={}
assert(driver.step({op='ready_blind',args={'1'}}) and MP.GAME.ready_blind)
assert(files[rec.path]:find('"type":"ready_blind"'))
-- A bare use slot present in two areas is resolved from the action stream.
G.STATE=2;G.consumeables={cards={ace}};G.shop_booster={cards={king}}
local used;G.FUNCS.use_card=function(e)used=e.config.ref_table end
local uses=driver.resolve({{n=1,op='use',args={'1'}},{n=2,op='pack_pick',args={'1'}}})
assert(uses[1].area=='shop_booster','a use answered by a pack pick opened the booster')
assert(driver.step(uses[1]) and used==king)
assert(driver.resolve({{n=1,op='use',args={'1','2.3'}}})[1].area=='consumeables','hand targets mean a consumable')
assert(driver.step({op='use',args={'1'}}) and used==ace,'an unresolved bare slot falls back to the consumable')
print('PASS: replay parsing, sequence rejection, empty-run skipping, named cards from the mirrored stream, mirrored-line exclusion, accurate discard recording, reorder, ante key, asteroid and positional use resolution')
