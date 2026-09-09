local JSON=dofile('mod/json.lua')
local observer=dofile('mod/observer.lua')(JSON,dofile('mod/multiplayer.lua'))
local function forbidden() error('Observer must never execute mod callbacks') end
MP={LOBBY={connected=true,code='PRIVATE_LOBBY',config={gamemode='gamemode_mp_attrition',ruleset='standard',hide_score_until_played=true,custom_seed='PRIVATE_SEED'}},GAME={lives=3,enemy={lives=2,hands_text='4',score_text='PRIVATE_SCORE',score={secret='PRIVATE_SCORE_OBJECT'},cards={'PRIVATE_CARDS'},skips=1}},ACTIONS={send=forbidden}}
local G={STAGE=1,STAGES={RUN=1},STATE=1,STATES={SELECTING_HAND=1,SHOP=2},STATE_COMPLETE=true,
 GAME={stake=6,skips=3,current_round={hands_played=0},hands={},blind={config={blind={key='bl_mp_nemesis'}},chips=987654321},
 selected_back={effect={center={key='b_mp_cocktail'}}},modifiers={mp_cocktail={'PRIVATE_COMPONENT'},mp_cocktail_sticker={[2]='b_mp_violet'}}},
 localization={descriptions={Joker={},Back={b_mp_cocktail={name='Cocktail Deck',text={'Three decks'}},b_mp_violet={name='Violet Deck',text={'Vouchers'}}},Planet={c_mp_asteroid={name='Asteroid',text={'Remove #1# level'}}},Spectral={c_mp_ouija_standard={name='Ouija 2',text={'Destroy #1# cards'}}},Other={p_mp_standard_giga={name='Giga Standard Pack',text={'Choose #1# of #2#'}}}},misc={v_dictionary={a_mp_skips_ahead={'#1# Skips Ahead'}}}},
 jokers={cards={}},hand={cards={}},playing_cards={}}
local function joker(key,ability,text)
 G.localization.descriptions.Joker[key]={name=key,text={text or '#1#'},loc_vars=forbidden}
 ability.set='Joker'
 return {facing='front',config={center={key=key,calculate=forbidden}},ability=ability}
end
G.jokers.cards={
 joker('j_mp_conjoined_joker',{extra={x_mult_gain=.5,max_x_mult=3,x_mult=2.5,secret='PRIVATE_EXTRA'}},'#1# #2# #3#'),
 joker('j_mp_defensive_joker',{extra={extra=125,highstake=75},t_chips=150},'#1# #2#'),
 joker('j_mp_pacifist',{extra={x_mult=10}}),
 joker('j_mp_penny_pincher',{extra={dollars=1,nemesis_dollars=3}},'#1# #2#'),
 joker('j_mp_pizza',{extra={discards=2,discards_nemesis=1}},'#1# #2#'),
 joker('j_mp_taxes',{extra={mult_gain=4,mult=28}},'#1# #2#'),
 joker('j_mp_skip_off',{extra={extra_hands=1,extra_discards=1,hands=2,discards=2}},'#1# #2# #3# #4# #5#'),
 joker('j_mp_speedrun',{},'Spectral card'),
 joker('j_mp_lets_go_gambling',{extra={odds=4,xmult=4,dollars=10,nemesis_dollars=10}},'#1# in #2# X#3# $ #4# #5# #6# #7#'),
 joker('j_mp_seltzer',{extra={hands_left=6}}),
 joker('j_mp_turtle_bean',{extra={h_size=4,h_mod=1}},'#1# #2#'),
 joker('j_mp_ticket',{extra={dollars=3}}),
 joker('j_mp_hanging_chad',{extra=1})}
G.jokers.cards[1].edition={type='mp_phantom'}
G.consumeables={cards={{facing='front',config={center={key='c_mp_asteroid'}},ability={set='Planet'}},{facing='front',config={center={key='c_mp_ouija_standard'}},ability={set='Spectral',extra={destroy=3}}}}}
local state=observer.snapshot(G)
assert(state.multiplayer.mode=='Attrition' and state.multiplayer.lives==3 and state.multiplayer.nemesis_lives==2)
assert(state.multiplayer.nemesis_score=='???' and state.multiplayer.nemesis_hands=='4' and state.blind.chips==nil)
local expected={'0.5 3 2.5','75 150','10','1 3','2 1','4 28','1 1 2 2 2 Skips Ahead','Spectral card','? in ? X4 $ 10 ? ? 10','6','4 1','3','1'}
for i,text in ipairs(expected) do assert(state.jokers.cards[i].description==text, state.jokers.cards[i].description) end
assert(state.jokers.cards[1].edition.mp_phantom)
assert(not state.jokers.cards[9].description_complete)
assert(state.consumables.cards[1].description=='Remove 1 level' and state.consumables.cards[2].description=='Destroy 3 cards')
assert(#state.run.deck.components==1 and state.run.deck.components[1].name=='Violet Deck')
assert(not JSON.encode(state):find('PRIVATE') and not JSON.encode(state):find('987654321'))
G.GAME.current_round.hands_played=nil;assert(observer.snapshot(G).multiplayer.nemesis_score=='???')
G.GAME.current_round.hands_played=1;MP.GAME.enemy.score_text='1.23e12'
assert(observer.snapshot(G).multiplayer.nemesis_score=='1.23e12')
G.GAME.blind={config={blind={key='bl_small'}},chips=300}
assert(observer.snapshot(G).multiplayer.nemesis_score==nil and observer.snapshot(G).blind.chips==300)
MP.LOBBY.config.disable_live_and_timer_hud=true
assert(observer.snapshot(G).multiplayer.lives==nil)
G.jokers.cards[1].facing='back'
assert(observer.snapshot(G).jokers.cards[1].key==nil and observer.snapshot(G).jokers.cards[1].edition==nil)
G.STATE=2;G.shop_booster={cards={{facing='front',config={center={key='p_mp_standard_giga'}},ability={set='Booster',choose=4,extra=10}}}}
assert(observer.snapshot(G).shop.boosters.cards[1].description=='Choose 4 of 10')
G.OVERLAY_MENU={};assert(not observer.snapshot(G).available and not observer.snapshot(G).multiplayer);G.OVERLAY_MENU=nil
MP=nil;assert(observer.snapshot(G).multiplayer==nil)
print('PASS: Multiplayer descriptions, Phantom, revealed Cocktail, public HUD, score masking, hidden cards and callback isolation')
