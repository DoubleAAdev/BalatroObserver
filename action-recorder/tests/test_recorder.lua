local JSON=dofile('mod/json.lua')
local files,now={},10
love={timer={getTime=function() return now end},filesystem={createDirectory=function() return true end,write=function(p,t) files[p]=t;return true end,append=function(p,t) files[p]=(files[p] or '')..t;return true end,getInfo=function(p) return files[p] and {} end}}
local function card(rank) return {facing='front',base={value=rank,suit='Spades'},config={center={key='c_base'}},ability={set='Default',extra={secret='SECRET'},perma_bonus=0},edition={},states={drag={is=false}}} end
local ace,copy,king=card('Ace'),card('Ace'),card('King')
G={STAGE=1,STAGES={RUN=1},STATE=1,STATES={SELECTING_HAND=1,SHOP=2,BLIND_SELECT=3,SMODS_BOOSTER_OPENED=4},STATE_COMPLETE=true,GAME={dollars=10,round=1,current_round={hands_left=4,discards_left=3},round_resets={ante=1,blind_choices={Small='bl_small'},blind_tags={Small='tag_double'}},blind_on_deck='Small',seed='SECRET'},FUNCS={},hand={cards={ace,copy,king},highlighted={copy,king}},play={cards={}},discard={cards={},config={card_limit=52}},jokers={cards={}},consumeables={cards={}},CONTROLLER={locks={}}}
Card={check_use=function(c) return c.reject end,sell_card=function(c) return 'sold',nil,7 end}
local call_count=0
G.FUNCS.play_cards_from_highlighted=function(e) if e=='fail' then error('original-error') end;call_count=call_count+1;return nil,'played',nil end
G.FUNCS.discard_cards_from_highlighted=function() call_count=call_count+1 end
G.FUNCS.buy_from_shop=function(e) if e.reject then return false,'full' end;return true end
G.FUNCS.use_card=function(e) if Card.check_use(e.config.ref_table) then return end end
for _,name in ipairs({'reroll_shop','skip_booster','select_blind','skip_blind'}) do G.FUNCS[name]=function() end end
local rec=dofile('mod/recorder.lua')(JSON,'0.1.0')
local hooks=dofile('mod/hooks.lua')(rec,JSON);hooks.install();rec.begin(false)
local path=rec.path
local function actions() local n=0;for _ in files[path]:gmatch('"action":') do n=n+1 end;return n end
local function packed(...)return{n=select('#',...),...}end
local returns=packed(G.FUNCS.play_cards_from_highlighted('unchanged'))
assert(returns.n==3 and returns[1]==nil and returns[2]=='played' and returns[3]==nil and call_count==1)
local failed,message=pcall(G.FUNCS.play_cards_from_highlighted,'fail');assert(not failed and message:find('original%-error') and actions()==1)
assert(actions()==1 and files[path]:find('"index":2') and files[path]:find('"rank":"King"'))
G.FUNCS.discard_cards_from_highlighted({},true);assert(actions()==1)
G.FUNCS.discard_cards_from_highlighted({});assert(actions()==2)
assert(not files[path]:find('SECRET'))
local definitions=0;for _ in files[path]:gmatch('"rank":"Ace"') do definitions=definitions+1 end;assert(definitions==1)
king.base.value='Queen';G.FUNCS.play_cards_from_highlighted({});assert(files[path]:find('"rank":"Queen"'))
king.facing='back';G.FUNCS.discard_cards_from_highlighted({});assert(files[path]:find('"hidden":true,"index":3'))
G.STATE=2;G.shop_jokers={cards={ace}};ace.cost=6
assert(G.FUNCS.buy_from_shop({config={ref_table=ace},reject=true})==false and actions()==4)
G.FUNCS.buy_from_shop({config={ref_table=ace,id='buy_and_use'}});assert(actions()==5 and files[path]:find('"use_after_buy":true'))
G.consumeables.cards={copy};G.shop_jokers.cards={};G.hand.cards={king}
copy.reject=true;G.FUNCS.use_card({config={ref_table=copy}});assert(actions()==5)
copy.reject=false;G.FUNCS.use_card({config={ref_table=copy}},false,true);assert(actions()==5)
G.FUNCS.use_card({config={ref_table=copy}});assert(actions()==6)
local sell=packed(Card.sell_card(copy));assert(sell.n==3 and sell[1]=='sold' and sell[2]==nil and sell[3]==7 and actions()==7)
G.FUNCS.reroll_shop({});assert(actions()==8)
G.STATE=4;G.pack_cards={cards={ace}}
G.FUNCS.use_card({config={ref_table=ace}});assert(actions()==9 and files[path]:find('"type":"pack_pick"'))
G.FUNCS.skip_booster({});assert(actions()==10)
G.STATE=3;G.blind_select={}
G.FUNCS.select_blind({config={ref_table={key='bl_small'}}});G.FUNCS.skip_blind({});assert(actions()==12)
G.STATE=1;G.hand.cards={ace,copy,king};G.pack_cards={cards={card('SECRET_PACK')}}
hooks.reorders();ace.states.drag.is=true;G.hand.cards={copy,ace,king};hooks.reorders();assert(actions()==12)
ace.states.drag.is=false;hooks.reorders();assert(actions()==13 and files[path]:find('"order":%[2,1,3%]'))
hooks.reorders();assert(actions()==13);G.hand.cards={ace,king};hooks.reorders();assert(actions()==13)
now=now+1;rec.observe();assert(files[path]:find('"observation":') and files[path]:find('"after_action":13'))
assert(not files[path]:find('SECRET_PACK'))
assert(not files[path]:match('"areas":{[^\n]*"shop_jokers"'))
local before=files[path];rec.observe();assert(before==files[path])
G.GAME={dollars=7,current_round={},round_resets={ante=2},seed='SECRET'};rec.record(rec.capture('reroll'))
assert(rec.path~=path and files[rec.path]:find('"partial":true') and files[path]==before)
local writes=0;love.filesystem.append=function() writes=writes+1;return false end
G.STATE=2;G.FUNCS.reroll_shop({});assert(rec.ok==false and writes==1);G.FUNCS.reroll_shop({});assert(writes==1)
local out=assert(io.open('work/test-recording.jsonl','wb'));out:write(before);out:close()
print('PASS: all action tokens, identities, dictionary reuse, targets, callback returns, rejection, drag debounce, privacy, segments and disk failure')
