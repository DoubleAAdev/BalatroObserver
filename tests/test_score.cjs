const {test}=require('node:test');const assert=require('node:assert/strict');const {preview}=require('../score-preview');
const card=(rank,extra={})=>({key:'c_base',rank,suit:'Spades',visible:true,selected:true,perma_bonus:0,...extra});
const base=()=>({available:true,phase:'SELECTING_HAND',scoring_context:{},hand:{cards:[card('Ace')]},jokers:{cards:[]},poker_hands:{'High Card':{level:1,chips:5,mult:1,played:0,played_this_round:0},Pair:{level:1,chips:10,mult:2,played:0,played_this_round:0}}});
const score=s=>{const p=preview(s);assert.ok(p.low,p.message);return Math.round(p.low[0]*10**p.low[1]);};
test('selected card, pair, upgraded hand, base joker and bonus chips',()=>{
 const s=base();assert.equal(score(s),16);
 s.hand.cards.push(card('Ace'));assert.equal(score(s),64);
 s.jokers.cards=[{key:'j_joker',score_vars:{1:4},sell_cost:1}];assert.equal(score(s),192);
 s.jokers.cards=[];s.poker_hands.Pair.chips=25;s.poker_hands.Pair.mult=3;assert.equal(score(s),141);
 s.hand.cards[0].perma_bonus=5;assert.equal(score(s),156);
});
test('held steel, red seals, editions and actual selection order',()=>{
 const s=base();s.hand.cards.push(card('King',{selected:false,key:'m_steel'}));assert.equal(score(s),24);
 s.hand.cards=[card('Ace',{seal:'Red'})];assert.equal(score(s),27);
 s.hand.cards=[card('Ace',{edition:{foil:true}})];assert.equal(score(s),66);
 const before=JSON.stringify(s);score(s);assert.equal(JSON.stringify(s),before,'simulation mutated export');
});
test('dynamic Wee and Greedy values, lucky range, empty and hidden states',()=>{
 const s=base();s.hand.cards=[card('2')];s.jokers.cards=[{key:'j_wee',score_vars:{1:40,2:8},sell_cost:2}];assert.equal(score(s),55);
 s.jokers.cards=[{key:'j_greedy_joker',score_vars:{1:3,2:'Diamonds'},sell_cost:2}];s.hand.cards=[card('Ace',{suit:'Diamonds'})];assert.equal(score(s),64);
 s.jokers.cards=[];s.hand.cards=[card('Ace',{key:'m_lucky'})];const p=preview(s);assert.notDeepEqual(p.low,p.high);
 s.hand.cards[0].visible=false;assert.match(preview(s).message,/face-down/);
 s.hand.cards=[];assert.match(preview(s).message,/Select cards/);
 s.available=false;assert.ok(!preview(s).low);
});
test('all vanilla IDs, unsupported custom jokers, missing score data and privacy',()=>{
 assert.equal(Object.keys(require('../assets/calculator/joker-ids.json')).length,150);
 const s=base();s.jokers.cards=[{key:'j_custom',name:'Custom'}];assert.match(preview(s).message,/Unsupported joker/);
 s.jokers.cards=[{key:'j_wee'}];assert.match(preview(s).message,/Missing/);
 delete s.scoring_context;assert.match(preview(s).message,/Restart Balatro/);
});
test('canonical Caino key maps to the legendary calculator ID',()=>{
 const s=base();s.jokers.cards=[{key:'j_caino',score_vars:{1:1,2:3}}];
 assert.equal(require('../assets/calculator/joker-ids.json').j_caino,83);
 assert.equal(score(s),48);
});
