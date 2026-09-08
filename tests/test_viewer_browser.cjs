const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const { createServer } = require('../server/viewer-server');
(async () => {
  const server = createServer('.');
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const browser = await chromium.launch({ headless: true, ...(process.env.BROWSER_EXECUTABLE ? {executablePath: process.env.BROWSER_EXECUTABLE} : {}) });
  try {
    const page = await browser.newPage({ viewport: {width: 1440, height: 1000} });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    const base = {schema_version:1, session:'test-session', sequence:1, observed_at:Math.floor(Date.now()/1000), available:true, phase:'SELECTING_HAND', mod_version:'1.0.1',
      hand:{cards:[{visible:true,rank:'2',suit:'Hearts',slot:1},{visible:false,slot:2},{visible:true,rank:'Ace',suit:'Spades',slot:3}]},
      deck:{cards:['Diamonds','Clubs','Hearts','Spades'].flatMap(suit=>['2','3','4','5','6','7','8','9','10','Jack','Queen','King','Ace'].map(rank=>({visible:true,rank,suit}))).concat([{visible:true,rank:'Ace',suit:'Spades'},{visible:true,key:'m_stone'}]),remaining_cards:[{visible:true,rank:'King',suit:'Clubs'}],draw_count:1},
      jokers:{cards:[{visible:true,set:'Joker',key:'j_abstract',name:'Abstract Joker',description:'+3 Mult for each Joker card (Currently +12 Mult)',description_complete:true}]},
      blind:{name:'The Hook',loc_debuff_text:'Discards 2 random cards per hand'},blinds:{choices:[{slot:'Boss',name:'The Hook',description:'Discards 2 random cards per hand'}]},vouchers:[]};
    let response = {state:base, stale:false, directory:'test'};
    await page.route('**/state', route => route.fulfill({json:response}));
    await page.goto('http://127.0.0.1:'+server.address().port);
    await page.locator('#content:not([hidden])').waitFor();
    assert.match(await page.locator('#panels').textContent(),/Discards 2 random cards/);
    await page.locator('#nav-inventory').click();
    assert.match(await page.locator('#panels').textContent(),/Currently \+12 Mult/);
    await page.locator('#nav-remaining').click();
    assert.match(await page.locator('.deck-card').getAttribute('aria-label'),/King/);
    for (const section of ['overview','blinds','vouchers','hand','deck','inventory','shop','pack','poker','raw','remaining']) {
      await page.locator('#nav-'+section).click();
      assert.equal(await page.locator('#nav-'+section).getAttribute('aria-current'),'page');
    }
    await page.locator('#nav-deck').click();
    assert.deepEqual(await page.locator('.deck-suit-row').evaluateAll(rows=>rows.map(r=>r.dataset.suit)),['Spades','Hearts','Clubs','Diamonds','Other']);
    assert.deepEqual(await page.locator('.deck-suit-row[data-suit="Spades"] .deck-card').evaluateAll(cards=>cards.map(c=>c.dataset.rank)),['Ace','Ace','King','Queen','Jack','10','9','8','7','6','5','4','3','2']);
    assert.equal(await page.locator('.deck-card').count(),54);
    assert.equal(await page.locator('.deck-card[data-rank="10"][data-suit="Spades"] .art-rank').getAttribute('data-tile'),'deck:8,3');
    assert.equal(await page.locator('#sort').isVisible(),false);
    if(process.env.VIEWER_SCREENSHOT_PATH)await page.screenshot({path:process.env.VIEWER_SCREENSHOT_PATH,fullPage:true});
    await page.locator('#nav-hand').click();
    await page.locator('#sort').selectOption('rank-desc');
    assert.match(await page.locator('.card').nth(0).textContent(),/Ace/);
    assert.match(await page.locator('.card').nth(1).textContent(),/Face down/);
    await page.locator('#sort').selectOption('rank-asc');
    assert.match(await page.locator('.card').nth(0).textContent(),/2/);
    await page.locator('#sort').selectOption('suit');
    assert.match(await page.locator('.card').nth(0).textContent(),/Ace/);
    await page.locator('#sort').selectOption('name');
    await page.locator('#sort').selectOption('rank-desc');
    // Transition records update raw data but preserve the available preview.
    response={...response,state:{...base,sequence:2,available:false,phase:'UNAVAILABLE'}};
    await page.waitForFunction(() => document.getElementById('status').textContent.includes('Last preview'));
    assert.equal(await page.locator('#content').isVisible(),true);
    assert.equal(await page.locator('.card').count(),3);
    assert.match(await page.locator('#raw').textContent(),/"available": false/);
    response={...response,stale:true};
    await page.waitForFunction(() => document.getElementById('status').textContent.includes('waiting for fresh export'));
    assert.equal(await page.locator('#content').isVisible(),true);
    response={state:{...base,sequence:3,hand:{cards:[{visible:true,rank:'Queen',suit:'Diamonds'}]}},stale:false,directory:'test'};
    await page.waitForFunction(() => document.querySelector('.card')?.textContent.includes('Queen'));
    await page.locator('#pause').click();
    response={...response,state:{...base,sequence:4}};
    await page.locator('#nav-deck').click();
    assert.match(await page.locator('#status').textContent(),/paused/);
    await page.locator('#pause').click();
    await page.setViewportSize({width:390,height:844});
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
    assert.equal(await page.locator('.deck-mat').evaluate(e=>e.scrollWidth>e.clientWidth),true);
    response={...response,state:{...base,session:'new-session',sequence:1,available:false}};
    await page.locator('#waiting:not([hidden])').waitFor();
    assert.equal(await page.locator('#content').isVisible(),false);
    response={...response,state:{...base,session:'new-session'}};
    await page.locator('#content:not([hidden])').waitFor();
    await page.reload();
    assert.equal(await page.locator('#sort').inputValue(),'rank-desc');
    assert.deepEqual(errors,[]);
    console.log('PASS: suit rows, Ace-to-2 ordering, duplicates, sprite coordinates, deck scrolling, 11 sections, descriptions, remaining cards, sorting, retained previews, session reset, pause, mobile and persistence');
  } finally {
    await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(e => {console.error(e);process.exitCode=1;});
