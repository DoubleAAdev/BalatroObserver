// Balatro Observer dashboard. Polls /state every 200 ms and renders one section at a time.
// Snapshot values are only ever inserted as text nodes; no snapshot data becomes markup, a URL or CSS.
// Loaded after: /assets/wiki-art.js (WIKI_ART, WIKI_KEYS), the calculator engine, /score-preview.js (ObserverScore)
// and /joker-sprites.js (JOKER_SPRITES).

// ---- Version and status labels ----
const $=id=>document.getElementById(id);
const viewerVersion=document.querySelector('meta[name=observer-version]').content;
// Snapshot metadata identifies the mod loaded by Balatro, even before a restart.
function showVersion(s,stale){
 const version=s?.mod_version;
 $('mod-version').textContent=version?'Mod v'+version+(stale?' (last snapshot)':''):'Mod version: '+(s?'unreported':'waiting');
 $('version-note').textContent=!s?'Waiting for game':!version?'Restart Balatro to load v'+viewerVersion:version!==viewerVersion?'Version mismatch — restart Balatro':stale?'Waiting for fresh export':'Versions match';
}


// ---- Navigation sections: id -> [icon, nav label, page title, description] ----
const sections={
 overview:['◈','Overview','Run overview','A little perspective before your next big hand.'],
 blinds:['◉','Blinds & tags','Blinds & skip tags','Current-ante blind choices, the next blind, the boss, and visible skip rewards.'],
 vouchers:['▱','Vouchers','Redeemed vouchers','Vouchers acquired in this run, including any starting deck vouchers.'],
 hand:['♠','Current hand','Current hand','Your cards on the table. Gold outlines mark selected cards.'],
 remaining:['▥','Remaining cards','Remaining cards','The public unplayed deck view. Includes cards kept ambiguous by face-down effects; never draw order.'],
 deck:['▤','Deck','Your deck','Full deck composition in suit rows, Ace to 2. This is not the draw pile or its order.'],
 inventory:['✦','Jokers & items','Jokers & consumables','The supporting cast of your run.'],
 shop:['◇','Shop','The shop','Cards, vouchers, and boosters available in the current shop.'],
 pack:['▣','Open pack','Inside the pack','Visible choices from your currently opened pack.'],
 poker:['≋','Poker hands','Poker hands','Hand levels, scoring values, and play counts.'],
 raw:['⌘','Raw data','Under the hood','The latest snapshot, exactly as the observer exports it.']
};

// ---- Score preview state (kept until another hand is selected; cleared on a new session) ----
let lastShop=null,shopSession=null,scoreLive=false,lastScore=null,scoreSession=null,scoreHeld=false;
function updateScore(s,stale){
 if(s&&s.session!==scoreSession){lastScore=null;scoreSession=s.session;}
 const selected=!stale&&s?.available&&s.phase==='SELECTING_HAND'&&(s.hand?.cards||[]).some(c=>c.selected);
 scoreHeld=!selected;
 if(selected)lastScore=ObserverScore.preview(s);
}

// ---- Formatting and DOM helpers ----
let active='overview',paused=false,busy=false,snapshot=null,usable=false,lastBody='';
// Keep snapshot precision for calculations; round only displayed numeric values.
const formatNumber=n=>Number.isFinite(n)&&!Number.isInteger(n)?n.toFixed(2):String(n);
const formatText=text=>typeof text==='number'?formatNumber(text):String(text).replace(/(?<![\d.])[-+]?\d+\.\d+(?:e[+-]?\d+)?(?![\d.])/gi,n=>{const prefix=n.startsWith('+')?'+':'';return prefix+Number(n).toFixed(2);});
function el(tag,text,cls){const e=document.createElement(tag);if(text!==undefined)e.textContent=formatText(text);if(cls)e.className=cls;return e;}
const value=v=>v===undefined||v===null?'—':typeof v==='number'?formatNumber(v):formatText(v);
const pretty=v=>v?String(v).replace(/^(?:bl|tag|[a-z])_/, '').replaceAll('_',' ').replace(/\b\w/g,c=>c.toUpperCase()):'Unknown card';
function status(text,bad=false){$('status').textContent=text;$('status').dataset.kind=bad?'bad':'ok';}
for(const [id,[icon,label]] of Object.entries(sections)){const b=el('button');b.id='nav-'+id;b.append(el('span',icon,'icon'),el('span',label),el('span','','count'));b.onclick=()=>{active=id;try{sessionStorage.setItem('observer-section',id);}catch{}select();render();};$('nav').append(b);}
try{const saved=sessionStorage.getItem('observer-section');if(sections[saved])active=saved;}catch{}
function select(){for(const id of Object.keys(sections)){const b=$('nav-'+id);if(id===active)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');}
$('title').textContent=sections[active][2];$('description').textContent=sections[active][3];
document.querySelector('.sortbar').hidden=['deck','remaining','raw'].includes(active);
$('raw-view').hidden=active!=='raw';$('content').hidden=active==='raw'||!usable;$('waiting').hidden=active==='raw'||usable;}
function panel(title,badge,wide=true){const p=el('section',undefined,'panel'+(wide?' wide':'')),head=el('div',undefined,'panel-head');head.append(el('h2',title));if(badge!==undefined)head.append(el('span',badge,'pill'));p.append(head);$('panels').append(p);return p;}
function empty(p,title,detail,icon='♧'){const e=el('div',undefined,'empty');e.append(el('span',icon,'empty-icon'),el('strong',title),el('span',detail));p.append(e);}
function stat(label,v){const box=el('div',undefined,'stat');box.append(el('span',label),el('b',value(v)));$('stats').append(box);}

// ---- Viewer-only card sorting (never changes the export) ----
let sortMode='original';
try{sortMode=localStorage.getItem('observer-sort')||'original';}catch{}
if(!['original','rank-desc','rank-asc','suit','name'].includes(sortMode))sortMode='original';
$('sort').value=sortMode;
$('sort').onchange=()=>{sortMode=$('sort').value;try{localStorage.setItem('observer-sort',sortMode);}catch{}render();};
function sortedCards(list){
 if(sortMode==='original')return list;
 const rank=c=>({Ace:14,King:13,Queen:12,Jack:11}[c.rank]||Number(c.rank)||0);
 const suits={Spades:0,Hearts:1,Clubs:2,Diamonds:3};
 const ordered=list.filter(c=>c.visible!==false).map((c,i)=>({c,i})).sort((a,b)=>{
  let order=0;
  if(sortMode==='rank-desc')order=rank(b.c)-rank(a.c);
  if(sortMode==='rank-asc')order=rank(a.c)-rank(b.c);
  if(sortMode==='suit')order=(suits[a.c.suit]??4)-(suits[b.c.suit]??4)||rank(b.c)-rank(a.c);
  if(sortMode==='name')order=(a.c.name||a.c.key||a.c.rank||'').localeCompare(b.c.name||b.c.key||b.c.rank||'');
  return order||a.i-b.i;
 }).map(x=>x.c);
 let i=0;return list.map(c=>c.visible===false?c:ordered[i++]);
}
// Adapted from efhiii/balatro-calculator (MIT): enhancement → face → edition → seal.
// Atlas coordinates are local constants; snapshot data never becomes a URL or CSS string.
// JOKER_SPRITES (atlas coordinates) is loaded from /joker-sprites.js.
const ENHANCEMENTS={m_bonus:[1,1],m_mult:[2,1],m_wild:[3,1],m_lucky:[4,1],m_glass:[5,1],m_steel:[6,1],m_stone:[5,0],m_gold:[6,0]};
const SEALS={Gold:[2,0],Purple:[4,4],Red:[5,4],Blue:[6,4]};
const EDITIONS={foil:1,holo:2,polychrome:3};
const SHEETS={deck:['8BitDeck_opt2.png',13,4],enhancement:['Enhancers.png',7,5],edition:['Editions.png',5,1],joker:['Jokers.png',10,16]};
function atlasLayer(sheet,x,y,cls){
 const [name,cols,rows]=SHEETS[sheet],e=el('span',undefined,'sprite-layer '+cls);
 e.style.backgroundImage='url("/assets/'+name+'")';
 e.style.backgroundSize=(cols*100)+'% '+(rows*100)+'%';
 e.style.backgroundPosition=(cols>1?100*x/(cols-1):0)+'% '+(rows>1?100*y/(rows-1):0)+'%';
 e.dataset.tile=sheet+':'+x+','+y;return e;
}
function wikiImage(file,label,cls='wiki-icon'){
 const img=el('img',undefined,cls);img.src='/'+file;img.alt=label;img.loading='lazy';return img;
}
function namedArt(name){return WIKI_ART.find(a=>a.name.toLowerCase()===String(name||'').toLowerCase());}
function blindArt(p,b){const file=WIKI_KEYS[b?.key]||namedArt(b?.name)?.file;if(file)p.append(wikiImage(file,b.name||pretty(b.key),'blind-art'));}
function cardArtwork(c){
 const art=el('div',undefined,'card-art');art.setAttribute('aria-hidden','true');
 if(c.visible===false){art.append(atlasLayer('enhancement',0,2,'art-back'));return art;}
 if(c.set==='Booster'&&WIKI_KEYS[c.key])art.classList.add('booster-art');
 const rank=deckRank(c),suitRow={Hearts:0,Clubs:1,Diamonds:2,Spades:3}[c.suit];
 const joker=JOKER_SPRITES[c.key],enhancement=ENHANCEMENTS[c.key]||[1,0];
 const face=el('span',undefined,'art-face');
 let maskSheet='enhancement',maskX=1,maskY=0;
 const wikiFile=WIKI_KEYS[c.key];
 if(wikiFile&&!c.rank){face.append(wikiImage(wikiFile,c.name||pretty(c.key),'wiki-card'));}
 else if(joker&&c.set==='Joker'){
  face.append(atlasLayer('joker',joker.x,joker.y,'art-joker'));
  if(joker.soul)face.append(atlasLayer('joker',...joker.soul,'art-soul'));
  maskSheet='joker';maskX=joker.x;maskY=joker.y;
 }else if(c.key==='m_stone'||(rank>=2&&rank<=14&&suitRow!==undefined)){
  face.append(atlasLayer('enhancement',...enhancement,'art-enhancement'));
  if(c.key!=='m_stone')face.append(atlasLayer('deck',rank-2,suitRow,'art-rank'));
 }else{
  face.append(atlasLayer('enhancement',1,0,'art-enhancement'));
  face.append(el('span',c.set==='Joker'?'✦':'◇','art-fallback'));
 }
 if(c.edition?.negative){face.classList.add('art-negative');art.dataset.negative='true';}
 art.append(face);
 const addFinish=(x,cls)=>{
  const layer=atlasLayer('edition',x,0,'art-finish '+cls);
  const [name,cols,rows]=SHEETS[maskSheet];
  layer.style.maskImage='url("'+(wikiFile?'/'+wikiFile:'/assets/'+name)+'")';
  layer.style.maskSize=wikiFile?'100% 100%':(cols*100)+'% '+(rows*100)+'%';
  layer.style.maskPosition=wikiFile?'center':(100*maskX/(cols-1))+'% '+(100*maskY/(rows-1))+'%';
  art.append(layer);
 };
 for(const [edition,x] of Object.entries(EDITIONS))if(c.edition?.[edition])addFinish(x,'art-'+edition);
 if(c.debuff)addFinish(4,'art-debuff');
 // Keep the seal above the edition layer: it must not disappear or inherit its tint.
 if(SEALS[c.seal]){const stamp=atlasLayer('enhancement',...SEALS[c.seal],'art-seal');stamp.dataset.seal=c.seal;art.append(stamp);}
 return art;
}

// ---- Card area panels ----
function cards(title,area,wide=true){
 const list=area?.cards||[],p=panel(title,list.length+(area?.capacity!==undefined?' / '+area.capacity:' cards'),wide);
 if(!list.length){empty(p,'Nothing here yet','Cards will appear automatically when this area is populated.');return;}
 const row=el('div',undefined,'cards');p.append(row);
 for(const c of sortedCards(list)){const hidden=c.visible===false;
 const box=el('div',undefined,'card'+(hidden?' hidden':!c.rank?' special':'')+(c.selected?' selected':''));row.append(box);
 if(!hidden&&c.set==='Booster')box.classList.add('booster-card');
 box.append(cardArtwork(c));
 if(hidden){box.append(el('strong','Face down','card-name'),el('small','Slot '+value(c.slot)));continue;}
 box.append(el('strong',c.rank?c.rank+' '+value(c.suit):c.name||WIKI_ART.find(a=>a.file===WIKI_KEYS[c.key])?.name||pretty(c.key),'card-name'));
 if(c.rank&&c.key&&c.key!=='c_base')box.append(el('small',pretty(c.key)));
 if(c.description){box.classList.add('with-description');box.append(el('p',c.description,'description'));if(c.description_complete===false)box.append(el('small','? = dynamic value not exported','description-note'));}
 else if(c.set==='Joker')box.append(el('small','Description not available in this snapshot.'));
 if(c.slot!==undefined)box.append(el('small','Game slot '+c.slot));
 box.title=c.key||[c.rank,c.suit].filter(Boolean).join(' ');
 const labels=[];if(c.selected)labels.push('Selected');if(c.debuff)labels.push('Debuffed');if(c.seal)labels.push(c.seal+' seal');
 for(const [k,v] of Object.entries(c.edition||{}))if(v)labels.push(pretty(k));
 for(const [k,v] of Object.entries(c.stickers||{}))if(v!==false&&v!=null)labels.push(v===true?pretty(k):pretty(k)+': '+v);
 if(labels.length)box.append(el('small',labels.join(' · '),'tags'));
 }}

// ---- Deck views: one overlapping row per suit, Ace to 2, like the in-game deck viewer ----
const deckSuits=['Spades','Hearts','Clubs','Diamonds'];
const deckSymbols={Spades:'♠',Hearts:'♥',Clubs:'♣',Diamonds:'♦'};
const deckRank=c=>({Ace:14,King:13,Queen:12,Jack:11}[c.rank]||Number(c.rank)||0);
function deckCard(c){
 const hidden=c.visible===false,e=el('div',undefined,'deck-card');
 e.tabIndex=0;e.dataset.rank=hidden?'':value(c.rank);e.dataset.suit=hidden?'':value(c.suit);
 const traits=[];
 if(!hidden){
  if(c.key&&c.key!=='c_base')traits.push(pretty(c.key));
  if(c.seal)traits.push(c.seal+' seal');
  for(const [k,v] of Object.entries(c.edition||{}))if(v)traits.push(pretty(k));
 }
 const label=hidden?'Face down':(c.rank?c.rank+' of '+value(c.suit):pretty(c.key))+(traits.length?' · '+traits.join(' · '):'');
 e.title=label;e.setAttribute('aria-label',label);e.append(cardArtwork(c));
 return e;
}
function deckRows(title,list){
 const p=panel(title,list.length+' cards');
 p.append(el('p','Spades · Hearts · Clubs · Diamonds — Ace to 2. Hover or focus a card for its details.','hint'));
 const mat=el('div',undefined,'deck-mat');mat.style.marginTop='18px';mat.tabIndex=0;mat.setAttribute('aria-label',title+' by suit; scroll horizontally to see all cards');p.append(mat);
 const groups=deckSuits.map(suit=>[suit,list.filter(c=>c.visible!==false&&c.suit===suit)]);
 const other=list.filter(c=>c.visible===false||!deckSuits.includes(c.suit));if(other.length)groups.push(['Other',other]);
 for(const [suit,group] of groups){
 const row=el('section',undefined,'deck-suit-row');row.dataset.suit=suit;row.setAttribute('aria-label',suit+' · '+group.length+' cards');
 const label=el('div',undefined,'deck-suit-label');label.append(el('b',deckSymbols[suit]||'◇'),el('small',group.length));label.title=suit;row.append(label);
 const fan=el('div',undefined,'deck-fan');row.append(fan);mat.append(row);
 // Stable rank ordering retains every duplicate and never mutates the export.
 const ordered=group.map((c,i)=>({c,i})).sort((a,b)=>deckRank(b.c)-deckRank(a.c)||a.i-b.i);
 for(const {c} of ordered)fan.append(deckCard(c));
 if(!group.length)fan.append(el('span','No cards in '+suit.toLowerCase(),'deck-row-empty'));
 }
}

// ---- Section renderers ----
// Current deck: name, effect text and wiki artwork, like the Run Info deck panel.
function deckPanel(s){
 const deck=s.run?.deck,key=deck?.key||s.run?.deck_key;
 const p=panel('Deck',undefined,false);
 if(!deck&&!key){empty(p,'Waiting for deck information','Restart Balatro with the latest observer to export the current deck.','▤');return;}
 const name=deck?.name||pretty(key),file=WIKI_KEYS[key]||namedArt(name)?.file;
 if(file)p.append(wikiImage(file,name,'deck-art'));
 p.append(el('div',name,'blind-name'));
 if(deck?.description){p.append(el('p',deck.description,'hint'));if(deck.description_complete===false)p.append(el('p','? = value not exported for this deck','hint'));}
 else p.append(el('p','Effect text not available in this snapshot.','hint'));
}
function blindPanels(s){
 const info=s.blinds;
 if(!info){empty(panel('Blinds & skip tags'),'Waiting for blind information','Restart Balatro with the latest observer to export the current ante.');return;}
 stat('Next blind',info.next?.name||info.next?.key);stat('Boss blind',info.boss?.name||info.boss?.key);
 for(const b of info.choices||[]){
  const p=panel(b.slot+' blind',b.status||'Unknown',false);
  blindArt(p,b);p.append(el('div',b.name||pretty(b.key),'blind-name'));
  if(b.description)p.append(el('p',b.description,'hint'));
  if(b.mult!==undefined)p.append(el('p','Base score multiplier: ×'+b.mult,'hint'));
  if(b.dollars!==undefined)p.append(el('p','Base reward: $'+b.dollars,'hint'));
  if(b.skip_tag)p.append(el('p','Skip tag: '+(b.skip_tag.name||pretty(b.skip_tag.key)),'hint'));
 }
}
function scorePanel(s){
 const p=panel('Selected hand score','Balatro Calculator');p.id='score-preview';
 const prediction=lastScore||{message:'Select cards in Balatro to preview their score.'};
 if(scoreHeld&&lastScore)p.append(el('p','Last selected hand · kept until you select another hand','hint'));
 if(prediction.message){p.append(el('p',prediction.message,'hint'));return;}
 const format=score=>{const n=score[0]*10**score[1];return Number.isFinite(n)&&n<1e15?Math.floor(n+1e-7).toLocaleString():score[0].toFixed(2)+'e'+score[1];};
 const low=format(prediction.low),high=format(prediction.high);
 p.append(el('div',low===high?low:low+' – '+high,'predicted-score'));
 p.append(el('p',prediction.hand+' · '+prediction.selected+' selected · '+(low===high?'Estimated score':'Estimated random-effect range'),'hint'));
 p.append(el('p','Uses your current card and joker order. Calculator estimates may differ with modded effects or blind rules.','hint'));
 const credit=el('a','Powered by Balatro Calculator');credit.href='https://efhiii.github.io/balatro-calculator/';credit.target='_blank';credit.rel='noopener noreferrer';p.append(credit);
}

// ---- Main render: rebuilds the active section from the current snapshot ----
function render(){
 select();if(!snapshot||!usable||active==='raw')return;
 const s=snapshot;$('stats').replaceChildren();$('panels').replaceChildren();
 if(active==='overview'){
 scorePanel(s);
 for(const [l,v] of [['Money',s.run?.dollars===undefined?undefined:'$'+s.run.dollars],['Ante',s.round?.ante],['Round',s.run?.round],['Score',s.run?.chips],['Hands left',s.round?.hands_left],['Discards left',s.round?.discards_left]])stat(l,v);
 const p=panel('Current blind',s.blind?.disabled?'Disabled':pretty(s.phase),false);
 blindArt(p,s.blind);p.append(el('div',s.blind?.name||'No active blind','blind-name'));
 if(s.blind?.loc_debuff_text)p.append(el('p',s.blind.loc_debuff_text,'hint'));
 if(s.blind?.disabled)p.append(el('p','Boss effect disabled','hint'));
 const row=el('div',undefined,'blind-values');for(const [l,v] of [['Target score',s.blind?.chips],['Reward',s.blind?.dollars===undefined?undefined:'$'+s.blind.dollars],['Stake',s.run?.stake]]){const x=el('div');x.append(el('small',l),el('span',value(v)));row.append(x);}const stake=['White','Red','Green','Black','Blue','Purple','Orange','Gold'][s.run?.stake-1];const stakeFile=namedArt(stake+' stake');if(stakeFile)row.lastChild.append(wikiImage(stakeFile.file,stake+' stake','stake-art'));p.append(row);
 deckPanel(s);
 cards('Current hand',s.hand);cards('Jokers',s.jokers,false);cards('Consumables',s.consumables,false);
 }else if(active==='blinds'){blindPanels(s);
 }else if(active==='vouchers'){if(s.vouchers)cards('Redeemed vouchers',{cards:s.vouchers});else empty(panel('Redeemed vouchers'),'Waiting for voucher information','Restart Balatro with the latest observer.');
 }else if(active==='hand'){
 scorePanel(s);
 stat('Cards in hand',s.hand?.cards?.length);stat('Hand capacity',s.hand?.capacity);stat('Selected',s.hand?.cards?.filter(c=>c.selected).length);stat('Hands left',s.round?.hands_left);stat('Discards left',s.round?.discards_left);cards('Current hand',s.hand);
 }else if(active==='remaining'){stat('Draw pile count',s.deck?.draw_count);stat('Visible possible remaining',s.deck?.remaining_cards?.length);if(s.deck?.remaining_cards)deckRows('Remaining cards',s.deck.remaining_cards);else empty(panel('Remaining cards'),'Waiting for remaining deck data','Restart Balatro with the latest mod.');
 }else if(active==='deck'){
 stat('Full deck',s.deck?.cards?.length);stat('Draw pile',s.deck?.draw_count);stat('Discard pile',s.deck?.discard_count);
 deckRows('Full deck',s.deck?.cards||[]);
 }else if(active==='inventory'){cards('Jokers',s.jokers);cards('Consumables',s.consumables);}
 else if(active==='shop'){
 const shop=s.shop||lastShop?.shop;
 if(!s.shop){const note=panel('Last observed shop','!');note.append(el('p',shop?'Shop cannot be accessed at this moment. Showing the last observed inventory from '+new Date(lastShop.observed_at*1000).toLocaleTimeString()+'. Prices and availability may have changed.':'Shop cannot be accessed at this moment. No shop has been observed in this session yet.','hint'));}
 if(shop){if(s.shop)stat('Money',s.run?.dollars===undefined?undefined:'$'+s.run.dollars);stat(s.shop?'Reroll cost':'Last reroll cost',shop.reroll_cost===undefined?undefined:'$'+shop.reroll_cost);cards(s.shop?'Cards for sale':'Last seen cards',shop.cards);cards('Vouchers',shop.vouchers,false);cards('Booster packs',shop.boosters,false);}
 }
 else if(active==='pack'){if(s.pack){stat('Picks remaining',s.pack.choices_left);cards('Pack choices',s.pack.cards);}else empty(panel('Open pack'),'No pack open','Open a booster pack to inspect its visible choices.','▣');}
 else if(active==='poker'){
 const p=panel('Hand levels'),wrap=el('div',undefined,'scroll'),t=el('table'),head=el('thead'),hr=el('tr'),body=el('tbody');
 for(const x of ['Hand','Level','Chips','Mult','Played','This round']){const th=el('th',x);th.scope='col';hr.append(th);}head.append(hr);t.append(head,body);
 for(const [name,h] of Object.entries(s.poker_hands||{})){const tr=el('tr');for(const x of [name,h.level,h.chips,h.mult,h.played,h.played_this_round])tr.append(el('td',value(x)));body.append(tr);}wrap.append(t);p.append(wrap);
 }
 $('stats').hidden=!$('stats').children.length;
}

// ---- Polling: keep the last good preview through animations and stale exports ----
function counts(s){for(const [id,n] of Object.entries({hand:s?.hand?.cards?.length,deck:s?.deck?.cards?.length,inventory:s?.jokers?.cards?.length,shop:s?.shop?.cards?.cards?.length,pack:s?.pack?.cards?.cards?.length})){$('nav-'+id).querySelector('.count').textContent=usable?value(n):'';}}
async function tick(){
 if(paused||busy)return;busy=true;
 try{
 if(location.protocol==='file:')throw new Error('Open the dashboard from start-viewer.cmd or the in-game mod settings; a file:// page cannot receive live updates.');
 const r=await fetch('/state',{cache:'no-store',signal:AbortSignal.timeout(2000)});if(!r.ok)throw new Error('Viewer server returned '+r.status);
 const {state:s,stale,directory}=await r.json();if(paused)return;
 // Keep the display stable during animations; raw data always shows the newest record.
 // A new game session must never inherit the previous session's preview.
 const previous=snapshot,previousScoreLive=scoreLive;
 scoreLive=!!s?.available&&!stale;
 updateScore(s,stale);
 if(s&&s.session!==shopSession){lastShop=null;shopSession=s.session;}
 if(s?.available&&s.shop)lastShop={shop:s.shop,observed_at:s.observed_at};
 if(s&&snapshot&&s.session!==snapshot.session)snapshot=null;
 if(s?.available)snapshot=s;
 usable=!!snapshot;
 $('meta').textContent=s?'#'+s.sequence+' · '+new Date(s.observed_at*1000).toLocaleTimeString():'200 ms refresh';
 $('source').textContent='Source: '+directory+(s?' · Session '+s.session:'');
 $('raw').textContent=s?JSON.stringify(s,null,2):'No valid snapshots found.';
 counts(snapshot);showVersion(s,stale);
 if(s?.available&&!stale)status('● Live · '+pretty(s.phase)+' · 200 ms refresh');
 else if(snapshot)status('Last preview · '+new Date(snapshot.observed_at*1000).toLocaleTimeString()+' · '+(stale?'waiting for fresh export':'updating when ready'),true);
 else{status('Waiting for observer',true);$('waiting-title').textContent='Waiting for the table';$('waiting-text').textContent='Your first available snapshot will appear here automatically.';}
 const {sequence,observed_at,...body}=snapshot||{};const next=JSON.stringify(body);
 if(next!==lastBody||!previous!==!snapshot||previousScoreLive!==scoreLive){render();lastBody=next;}else select();
 }catch(e){if(!paused){scoreLive=false;scoreHeld=true;usable=!!snapshot;render();counts(snapshot);showVersion(snapshot,true);status(snapshot?'Connection interrupted · keeping last preview':'Connection unavailable',true);$('waiting-title').textContent='Waiting for connection';$('waiting-text').textContent=e.message;select();}}
 finally{busy=false;}
}
$('pause').onclick=()=>{paused=!paused;$('pause').textContent=paused?'▶ Resume updates':'Ⅱ Pause updates';if(paused)status('Updates paused · frozen snapshot',true);else tick();};
select();tick();setInterval(tick,200);
