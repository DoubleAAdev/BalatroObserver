const assert=require('node:assert/strict');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const {createServer}=require('../viewer-server');
const art=require('../assets/wiki-art.json');
(async()=>{
 const server=createServer('.');await new Promise(r=>server.listen(0,'127.0.0.1',r));
 const browser=await chromium.launch({headless:true,...(process.env.BROWSER_EXECUTABLE?{executablePath:process.env.BROWSER_EXECUTABLE}:{})});
 try{
  const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  const base={schema_version:1,session:'wiki',sequence:1,observed_at:Date.now()/1000,available:true,phase:'SHOP',mod_version:'0.7.0',run:{stake:8,dollars:20},blind:{name:'The Hook'},consumables:{cards:[{visible:true,key:'c_fool',set:'Tarot',edition:{negative:true}},{visible:true,key:'c_pluto',set:'Planet'},{visible:true,key:'c_ankh',set:'Spectral'}]},shop:{cards:{cards:[{visible:true,key:'c_fool',set:'Tarot'}]},vouchers:{cards:[{visible:true,key:'v_overstock_norm',set:'Voucher'}]},reroll_cost:5}};
  let response={state:base,stale:false,directory:'fixture'};
  await page.route('**/state',r=>r.fulfill({json:response}));
  await page.goto('http://127.0.0.1:'+server.address().port);
  await page.locator('.wiki-card').first().waitFor();
  assert.equal(await page.locator('.wiki-card').count(),3);
  assert.match(await page.locator('.art-negative img').getAttribute('src'),/The_Fool/);
  assert.match(await page.locator('.blind-art').getAttribute('src'),/The_Hook/);
  assert.match(await page.locator('.stake-art').getAttribute('src'),/Gold_stake/);
  assert.equal(await page.locator('#nav-reference').count(),0);
  assert.equal(await page.title(),'Balatro Observer');
  assert.equal(art.length,208);
  for(const obsolete of ['Magnet','Electromagnet','Pattern','Tesselation','BigSpoon','BigGoldSpoon'])assert.ok(!art.some(a=>a.name===obsolete));
  await page.evaluate(async()=>{await Promise.all(WIKI_ART.map(a=>{const i=new Image();i.src='/'+a.file;return i.decode();}));});
  // Every vanilla pack variant maps to its distinct wrapper, never its contents.
  const boosterKeys=["p_arcana_normal_1", "p_arcana_normal_2", "p_arcana_normal_3", "p_arcana_normal_4", "p_arcana_jumbo_1", "p_arcana_jumbo_2", "p_arcana_mega_1", "p_arcana_mega_2", "p_celestial_normal_1", "p_celestial_normal_2", "p_celestial_normal_3", "p_celestial_normal_4", "p_celestial_jumbo_1", "p_celestial_jumbo_2", "p_celestial_mega_1", "p_celestial_mega_2", "p_standard_normal_1", "p_standard_normal_2", "p_standard_normal_3", "p_standard_normal_4", "p_standard_jumbo_1", "p_standard_jumbo_2", "p_standard_mega_1", "p_standard_mega_2", "p_buffoon_normal_1", "p_buffoon_normal_2", "p_buffoon_jumbo_1", "p_buffoon_mega_1", "p_spectral_normal_1", "p_spectral_normal_2", "p_spectral_jumbo_1", "p_spectral_mega_1"];
  response={...response,state:{...base,sequence:10,shop:{...base.shop,boosters:{cards:boosterKeys.map(key=>({visible:true,key,set:'Booster'}))}}}};
  await page.waitForFunction(()=>document.querySelector('#raw').textContent.includes('p_spectral_mega_1'));
  await page.locator('#nav-shop').click();
  assert.equal(await page.locator('.wiki-card').count(),2+boosterKeys.length);
  for(const width of [1440,390]){
   await page.setViewportSize({width,height:1000});
   const dimensions=await page.locator('.booster-art').evaluateAll(els=>els.map(e=>({w:e.getBoundingClientRect().width,h:e.getBoundingClientRect().height,parent:e.parentElement.getBoundingClientRect().height})));
   assert.equal(dimensions.length,32);
   for(const d of dimensions){assert.ok(Math.abs(d.h/d.w-186/114)<0.01);assert.ok(d.parent>d.h);}
  }
  await page.setViewportSize({width:1440,height:1000});
  if(process.env.BOOSTER_SCREENSHOT_PATH)await page.screenshot({path:process.env.BOOSTER_SCREENSHOT_PATH,fullPage:true});
  const sources=await page.locator('.wiki-card').evaluateAll(images=>images.map(i=>i.getAttribute('src')));
  assert.ok(sources.some(src=>src.endsWith('/Arcana_Normal_4.png')));
  assert.ok(sources.some(src=>src.endsWith('/Spectral_Mega_1.png')));
  response={state:base,stale:false,directory:'fixture'};
  await page.waitForFunction(()=>document.querySelectorAll('.wiki-card').length===2);

  assert.equal(await page.locator('.wiki-card').count(),2);
  response={...response,state:{...base,sequence:2,phase:'SELECTING_HAND',shop:undefined}};
  await page.waitForFunction(()=>document.querySelector('#panels').textContent.includes('Last observed shop'));
  assert.equal(await page.locator('.wiki-card').count(),2);
  assert.match(await page.locator('#panels').textContent(),/cannot be accessed at this moment/);
  if(process.env.WIKI_SCREENSHOT_PATH)await page.screenshot({path:process.env.WIKI_SCREENSHOT_PATH,fullPage:true});
  response={...response,state:{...base,sequence:3,shop:{cards:{cards:[]},vouchers:{cards:[]},reroll_cost:6}}};
  await page.waitForFunction(()=>!document.querySelector('#panels').textContent.includes('Last observed shop'));
  assert.equal(await page.locator('.wiki-card').count(),0,'fresh empty shop replaces cached inventory');
  response={...response,state:{...base,sequence:4,session:'new',shop:undefined}};
  await page.waitForFunction(()=>document.querySelector('#panels').textContent.includes('No shop has been observed'));
  assert.equal(await page.locator('.wiki-card').count(),0);
  await page.locator('#nav-overview').click();await page.setViewportSize({width:390,height:844});
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  assert.match(await page.locator('footer').textContent(),/Balatro Wiki/);
  assert.deepEqual(errors,[]);
  console.log('PASS: all 208 images decode, no image library, consumable/voucher/negative/blind/stake art, shop history/reset and mobile layout');
 }finally{await browser.close();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1;});

