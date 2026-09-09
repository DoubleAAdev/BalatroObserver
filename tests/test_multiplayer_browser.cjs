const assert=require('node:assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const {createServer}=require('../server/viewer-server');
const {preview}=require('../viewer/score-preview');
(async()=>{
 const server=createServer('.');await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,...(process.env.BROWSER_EXECUTABLE?{executablePath:process.env.BROWSER_EXECUTABLE}:{})});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  const keys=['conjoined_joker','defensive_joker','lets_go_gambling','pacifist','penny_pincher','pizza','skip_off','speedrun','taxes'];
  const state={schema_version:1,available:true,session:'mp',sequence:1,observed_at:Date.now()/1000,phase:'SELECTING_HAND',multiplayer:{active:true,pvp:true,mode:'Attrition',lives:3,nemesis_lives:2,nemesis_hands:'4',nemesis_score:'???'},run:{deck_key:'b_mp_cocktail',deck:{key:'b_mp_cocktail',name:'Cocktail Deck',description:'Three decks',components:[{key:'b_mp_violet',name:'Violet Deck'}]}},blind:{key:'bl_mp_nemesis',name:'Your Nemesis'},hand:{cards:[{key:'c_base',rank:'Ace',suit:'Spades',selected:true,visible:true}]},jokers:{cards:keys.map((key,i)=>({key:'j_mp_'+key,set:'Joker',visible:true,description:i===0?'X2.5000001 Mult':'Public description',edition:i===0?{mp_phantom:true}:{}}))}};
  let response={state,stale:false};await page.route('**/state',r=>r.fulfill({json:response}));
  await page.goto('http://127.0.0.1:'+server.address().port);
  await page.locator('#multiplayer-panel').waitFor();
  assert.match(await page.locator('#multiplayer-panel').textContent(),/Nemesis score: \?\?\?/);
  assert.match(await page.locator('#score-preview').textContent(),/Multiplayer rules/);
  assert.equal(await page.locator('.predicted-score').count(),0);
  assert.equal(await page.locator('.wiki-card').count(),9);
  assert.match(await page.locator('.art-phantom').locator('..').textContent(),/Phantom/);
  assert.match(await page.locator('.description').first().textContent(),/X2.50 Mult/);
  assert.match(await page.locator('#panels').textContent(),/Revealed components: Violet Deck/);
  await page.evaluate(async()=>{await Promise.all(['violet','indigo','orange','oracle','gradient','heidelberg','cocktail'].map(k=>{const img=new Image();img.src='/'+WIKI_KEYS['b_mp_'+k];return img.decode();}));});
  response={state:{...state,sequence:2,multiplayer:undefined,run:{},jokers:{cards:[{visible:false,slot:1}]}},stale:false};
  await page.waitForFunction(()=>!document.querySelector('#multiplayer-panel'));
  assert.equal(await page.locator('.wiki-card').count(),0);
  assert.equal(await page.locator('.art-phantom').count(),0);
  assert.ok(preview(state).unsupported);
  assert.ok(preview({...state,multiplayer:undefined}).unsupported);
  assert.deepEqual(errors,[]);
  console.log('PASS: Multiplayer HUD masking, all deck images, joker art, Phantom, decimals, scoring guard and session cleanup');
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
