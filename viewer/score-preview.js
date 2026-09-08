/* Local adapter for efhiii's Balatro Calculator. See THIRD_PARTY_NOTICES.md. */
(function(root){
 const engine=typeof module==='object'?require('../assets/calculator/balatro-sim.js'):{Hand,handChips};
 const ids=typeof module==='object'?require('../assets/calculator/joker-ids.json'):CALCULATOR_JOKERS;
 const handNames=['Flush Five','Flush House','Five of a Kind','Straight Flush','Four of a Kind','Full House','Flush','Straight','Three of a Kind','Two Pair','Pair','High Card'];
 const suits={Hearts:0,Clubs:1,Diamonds:2,Spades:3};
 const enhancements={c_base:0,m_bonus:1,m_mult:2,m_wild:3,m_glass:4,m_steel:5,m_stone:6,m_gold:7,m_lucky:8};
 const edition=c=>c.edition?.foil?1:c.edition?.holo?2:c.edition?.polychrome?3:c.edition?.negative?4:0;
 const fail=message=>{throw new Error(message);};
 const num=(v,label)=>Number.isFinite(v)?v:fail('Missing '+label);
 const card=c=>{
  if(c.visible===false)fail('A face-down card prevents a reliable preview');
  if(!(c.key in enhancements))fail('Unsupported card: '+(c.name||c.key));
  const stone=c.key==='m_stone';
  const rank=stone?0:({Jack:9,Queen:10,King:11,Ace:12}[c.rank]??Number(c.rank)-2);
  if(!Number.isInteger(rank)||rank<0||rank>12||(!stone&&suits[c.suit]===undefined))fail('Unknown card rank or suit');
  if(stone&&c.perma_bonus)fail('Stone Card bonus is not supported by the calculator');
  return [rank,stone?0:suits[c.suit],edition(c),enhancements[c.key],{Gold:1,Red:2,Blue:3,Purple:4}[c.seal]||0,num(c.perma_bonus??0,'card bonus'),!!c.debuff];
 };
 function joker(c,s){
  const id=ids[c.key];if(id===undefined)fail('Unsupported joker: '+(c.name||c.key));
  const v=i=>num(c.score_vars?.[String(i)],(c.name||c.key)+' value '+i);
  let value=0;
  if(!c.debuff)switch(c.key){
   case 'j_stone':value=v(2)/25;break;
   case 'j_acrobat':case 'j_dusk':value=num(s.round?.hands_left,'hands left')===1?1:0;break;
   case 'j_banner':value=num(s.round?.discards_left,'discards left');break;
   case 'j_mystic_summit':value=num(s.round?.discards_left,'discards left')===v(2)?1:0;break;
   case 'j_loyalty_card':value=s.scoring_context?.loyalty_remaining?.[String(c.slot)];value=num(value,'loyalty counter');break;
   case 'j_steel_joker':value=(v(2)-1)/0.2;break;
   case 'j_glass':value=(v(2)-1)/0.75;break;
   case 'j_vampire':value=(v(2)-1)*10;break;
   case 'j_obelisk':value=(v(2)-1)*5;break;
   case 'j_castle':value=v(3)/3;break;
   case 'j_idol':{const rank=({Jack:9,Queen:10,King:11,Ace:12}[c.score_vars?.['2']]??Number(c.score_vars?.['2'])-2);value=4*num(rank,'Idol rank')+num(suits[c.score_vars?.['3']],'Idol suit');break;}
   case 'j_wee':value=v(1)/8;break;
   case 'j_stencil':value=v(1)-1;break;
   case 'j_ceremonial':value=v(1);break;
   case 'j_fortune_teller':value=v(2);break;
   case 'j_hit_the_road':value=(v(2)-1)/0.5;break;
   case 'j_ride_the_bus':case 'j_green_joker':value=v(c.key==='j_green_joker'?3:2);break;
   case 'j_drivers_license':value=v(2);break;
   case 'j_throwback':value=(v(2)-1)/0.25;break;
   case 'j_caino':value=v(2)-1;break;
   case 'j_yorick':value=v(4);break;
   case 'j_bootstraps':value=v(3)/2;break;
   case 'j_runner':value=v(1)/15;break;
   case 'j_ice_cream':value=(100-v(1))/5;break;
   case 'j_blue_joker':value=num(s.deck?.draw_count,'draw count')-52;break;
   case 'j_constellation':value=(v(2)-1)*10;break;
   case 'j_red_card':value=v(2)/3;break;
   case 'j_madness':value=(v(2)-1)/0.5;break;
   case 'j_square':value=v(1)/4;break;
   case 'j_hologram':value=(v(2)-1)/0.25;break;
   case 'j_erosion':value=v(2)/4;break;
   case 'j_lucky_cat':value=(v(2)-1)*4;break;
   case 'j_bull':value=Math.max(0,num(s.run?.dollars,'money'));break;
   case 'j_flash':value=v(2)/2;break;
   case 'j_popcorn':value=(20-v(1))/4;break;
   case 'j_ramen':value=(2-v(1))*100;break;
   case 'j_trousers':value=v(3)/2;break;
   case 'j_campfire':value=(v(2)-1)/0.25;break;
   case 'j_ancient':value=suits[c.score_vars?.['2']];num(value,'Ancient Joker suit');break;
  }
  return [id,value,edition(c),!!c.debuff,num(c.sell_cost??0,'joker sell value')];
 }
 function preview(s){
  try{
   if(!s?.available||s.phase!=='SELECTING_HAND')return {message:'Select a hand in Balatro to preview its score.'};
   const selected=(s.hand?.cards||[]).filter(c=>c.selected);
   if(!selected.length)return {message:'Select cards in Balatro to preview their score.'};
   if(selected.length>5)fail('The calculator supports up to five selected cards');
   if(!s.scoring_context)fail('Restart Balatro to enable score data');
   if((s.jokers?.cards||[]).some(c=>!c.debuff&&c.key==='j_vampire')&&(s.hand?.cards||[]).some(c=>c.key==='m_stone'))fail('Vampire with Stone Cards needs hidden ranks; preview withheld');
   if((s.jokers?.cards||[]).some(c=>!c.debuff&&c.key==='j_glass')&&selected.some(c=>c.key==='m_glass'))fail('Glass Joker with played Glass Cards is not supported reliably by this calculator');
   const jokers=(s.jokers?.cards||[]).map(c=>joker(c,s));
   const all=(s.hand?.cards||[]).map(card);
   const levels=handNames.map(name=>{
    const h=s.poker_hands?.[name];
    if(!h)return [1,0,0,0];
    return [num(h.level,'hand level'),(s.consumables?.cards||[]).filter(c=>c.key===({ 'High Card':'c_pluto',Pair:'c_mercury','Two Pair':'c_uranus','Three of a Kind':'c_venus',Straight:'c_saturn',Flush:'c_jupiter','Full House':'c_earth','Four of a Kind':'c_mars','Straight Flush':'c_neptune','Five of a Kind':'c_planet_x','Flush House':'c_ceres','Flush Five':'c_eris'}[name])).length,num(h.played??0,'hand plays'),num(h.played_this_round??0,'round plays')];
   });
   // Use actual exported base chips/mult (including hand upgrades), not a guessed level formula.
   for(let i=0;i<handNames.length;i++){
    const h=s.poker_hands?.[handNames[i]];
    if(h){engine.handChips[i][0]=num(h.chips,'hand chips');engine.handChips[i][1]=num(h.mult,'hand mult');engine.handChips[i][2]=0;engine.handChips[i][3]=0;}
   }
   const config={cards:all.filter((c,i)=>s.hand.cards[i].selected),cardsInHand:all.filter((c,i)=>!s.hand.cards[i].selected),jokers,hands:levels,
    TheFlint:!s.blind?.disabled&&s.blind?.name==='The Flint',TheEye:!s.blind?.disabled&&s.blind?.name==='The Eye',PlasmaDeck:s.run?.deck_key==='b_plasma',Observatory:(s.vouchers||[]).some(v=>v.key==='v_observatory')};
   const calculate=best=>{const h=new engine.Hand(JSON.parse(JSON.stringify(config)));h.compileAll();if(!s.poker_hands?.[handNames[h.typeOfHand]])fail('Missing scoring values for '+handNames[h.typeOfHand]);return {score:best?h.simulateBestHand():h.simulateWorstHand(),hand:handNames[h.typeOfHand]};};
   const low=calculate(false),high=calculate(true);
   return {hand:low.hand,low:low.score,high:high.score,selected:selected.length};
  }catch(e){return {message:e.message,unsupported:true};}
 }
 const api={preview,handNames};if(typeof module==='object')module.exports=api;else root.ObserverScore=api;
})(globalThis);
