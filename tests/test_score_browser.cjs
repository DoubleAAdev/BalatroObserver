const assert=require('node:assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const {createServer}=require('../viewer-server');
(async()=>{
 const server=createServer('.');await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,...(process.env.BROWSER_EXECUTABLE?{executablePath:process.env.BROWSER_EXECUTABLE}:{})});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[],requests=[];
  page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>requests.push(r.url()));
  const base={schema_version:1,session:'score',sequence:1,observed_at:Date.now()/1000,available:true,phase:'SELECTING_HAND',mod_version:'0.7.2',scoring_context:{},hand:{cards:[{key:'c_base',rank:'Ace',suit:'Spades',visible:true,selected:true,slot:1}]},poker_hands:{'High Card':{level:1,chips:5,mult:1}},jokers:{cards:[{key:'j_joker',set:'Joker',visible:true,score_vars:{1:4},description:'+4 Mult'}]}};
  let response={state:base,stale:false,directory:'fixture'};
  await page.route('**/state',r=>r.fulfill({json:response}));
  await page.goto('http://127.0.0.1:'+server.address().port);
  await page.waitForFunction(()=>document.querySelector('.predicted-score')?.textContent==='80');
  assert.equal(await page.title(),'Balatro Observer');
  assert.equal(await page.locator('#nav-reference').count(),0);
  await page.locator('#nav-hand').click();assert.equal(await page.locator('.predicted-score').textContent(),'80');
  if(process.env.SCORE_SCREENSHOT_PATH)await page.screenshot({path:process.env.SCORE_SCREENSHOT_PATH,fullPage:true});
  response={...response,state:{...base,sequence:2,hand:{cards:[{...base.hand.cards[0],selected:false}]}}};
  await page.waitForFunction(()=>document.querySelector('#score-preview').textContent.includes('Select cards'));
  response={...response,state:{...base,sequence:3}};await page.locator('.predicted-score').waitFor();
  response={...response,stale:true};await page.waitForFunction(()=>document.querySelector('#score-preview').textContent.includes('fresh'));
  assert.equal(await page.locator('.predicted-score').count(),0);
  response={state:{...base,available:false,sequence:4},stale:false};
  await page.waitForFunction(()=>document.querySelector('#raw').textContent.includes('"available": false'));
  assert.equal(await page.locator('.predicted-score').count(),0);
  assert.ok(requests.every(url=>url.startsWith('http://127.0.0.1:')));
  assert.deepEqual(errors,[]);
  console.log('PASS: live selection score, overview/hand, no library, renamed title, stale/transition suppression and local-only calculator');
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
