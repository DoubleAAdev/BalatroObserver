const assert=require('node:assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const {createServer}=require('../viewer-server');
(async()=>{
 const server=createServer('.');await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const browser=await chromium.launch({headless:true,...(process.env.BROWSER_EXECUTABLE?{executablePath:process.env.BROWSER_EXECUTABLE}:{})});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1100}});
  const errors=[],requests=[];page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>requests.push(r.url()));
  const editions=[null,'foil','holo','polychrome','negative'],seals=[null,'Red','Blue','Gold','Purple'];
  const keys=['c_base','m_bonus','m_mult','m_wild','m_lucky','m_glass','m_steel','m_gold','m_stone'];
  const matrix=[];
  for(const key of keys)for(const edition of editions)for(const seal of seals)matrix.push({
   visible:true,rank:key==='m_stone'?undefined:'Jack',suit:key==='m_stone'?undefined:'Spades',key,seal,edition:edition?{[edition]:true}:{}
  });
  let payload={state:{schema_version:1,available:true,session:'art-test',sequence:1,observed_at:Math.floor(Date.now()/1000),phase:'SELECTING_HAND',mod_version:'0.7.0',
   hand:{cards:matrix.slice(0,25)}},stale:false,directory:'fixture'};
  await page.route('**/state',r=>r.fulfill({json:payload}));
  await page.goto('http://127.0.0.1:'+server.address().port);
  await page.locator('#nav-hand').click();await page.locator('.card').nth(24).waitFor();
  // Decode every local image before taking a visual QA screenshot.
  await page.evaluate(async()=>{await Promise.all(['8BitDeck_opt2.png','Enhancers.png','Editions.png','Jokers.png'].map(name=>{const img=new Image();img.src='/assets/'+name;return img.decode();}));});
  if(process.env.ART_SCREENSHOT_PATH)await page.screenshot({path:process.env.ART_SCREENSHOT_PATH,fullPage:true});
  payload={...payload,state:{...payload.state,sequence:2,hand:{cards:matrix}}};
  await page.waitForFunction(()=>document.querySelectorAll('.card').length===225);
  const rendered=await page.locator('.card').evaluateAll(cards=>cards.map(e=>({
   seal:e.querySelector('.art-seal')?.dataset.seal||null,
   rank:!!e.querySelector('.art-rank'),
   foil:!!e.querySelector('.art-foil'),holo:!!e.querySelector('.art-holo'),polychrome:!!e.querySelector('.art-polychrome'),negative:!!e.querySelector('.art-negative'),
   sealZ:e.querySelector('.art-seal')?Number(getComputedStyle(e.querySelector('.art-seal')).zIndex):0,
   finishZ:e.querySelector('.art-finish')?Number(getComputedStyle(e.querySelector('.art-finish')).zIndex):0,
   blend:e.querySelector('.art-polychrome')?getComputedStyle(e.querySelector('.art-polychrome')).mixBlendMode:null,
   enhancement:e.querySelector('.art-enhancement')?.dataset.tile
  })));
  for(let i=0;i<matrix.length;i++){
   const c=matrix[i],r=rendered[i];assert.equal(r.seal,c.seal);assert.equal(r.rank,c.key!=='m_stone');
   for(const ed of ['foil','holo','polychrome','negative'])assert.equal(r[ed],!!c.edition[ed]);
   if(c.seal)assert.ok(r.sealZ>r.finishZ);
   if(c.edition.polychrome)assert.equal(r.blend,'color');
   if(c.key==='m_gold')assert.equal(r.enhancement,'enhancement:6,0');
   if(c.key==='m_stone')assert.equal(r.enhancement,'enhancement:5,0');
  }
  payload={...payload,state:{...payload.state,sequence:3,hand:{cards:[
   {visible:false,rank:'Ace',suit:'Spades',key:'j_joker',set:'Joker',seal:'Red',edition:{polychrome:true}},
   {visible:true,set:'Joker',key:'j_joker',edition:{holo:true},seal:'Purple'},
   {visible:true,set:'Joker',key:'j_unknown_custom',name:'Custom Joker',edition:{foil:true}}
  ]}}};
  await page.waitForFunction(()=>document.querySelectorAll('.card').length===3);
  const hidden=page.locator('.card').nth(0);
  assert.equal(await hidden.locator('.art-back').count(),1);
  assert.equal(await hidden.locator('.art-rank,.art-joker,.art-seal,.art-finish').count(),0);
  assert.doesNotMatch(await hidden.textContent(),/Ace|Spades|Red|Polychrome/);
  assert.equal(await page.locator('.card').nth(1).locator('.art-joker').getAttribute('data-tile'),'joker:0,0');
  assert.equal(await page.locator('.card').nth(1).locator('.art-seal').getAttribute('data-seal'),'Purple');
  assert.equal(await page.locator('.card').nth(2).locator('.art-fallback').count(),1);
  assert.match(await page.locator('footer').textContent(),/Saffron Haas/);
  assert.ok(requests.every(url=>url.startsWith('http://127.0.0.1:')));
  assert.deepEqual(errors,[]);
  console.log('PASS: 225 enhancement/edition/seal combinations, seal layering, negative isolation, stone redaction, joker sprites, custom fallback, hidden-card redaction, local assets and credit');
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{console.error(e);process.exitCode=1;});
