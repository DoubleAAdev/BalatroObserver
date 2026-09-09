const assert=require('node:assert/strict');
const fs=require('node:fs/promises');
const path=require('node:path');
const net=require('node:net');
const {spawn}=require('node:child_process');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),dir=path.join(root,'work','server-fixtures');await fs.mkdir(dir,{recursive:true});
 const journal=await fs.readFile(path.join(root,'work','test-recording.jsonl'),'utf8'),filename='run-123-456-1.jsonl';
 await fs.writeFile(path.join(dir,filename),journal);
 const portProbe=net.createServer();await new Promise(r=>portProbe.listen(0,'127.0.0.1',r));const port=portProbe.address().port;await new Promise(r=>portProbe.close(r));
 const child=spawn(path.join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe'),['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join(root,'server/start-recorder.ps1'),'-Server','-Port',String(port),'-StateDirectory',dir],{windowsHide:true});
 let output='',browser;child.stderr.on('data',data=>output+=data);
 try{
  const base='http://127.0.0.1:'+port;let healthy=false;
  for(let i=0;i<100;i++){try{healthy=(await(await fetch(base+'/health')).json()).app==='BalatroActionRecorder';if(healthy)break;}catch{}await new Promise(r=>setTimeout(r,100));}
  assert.ok(healthy,output);
  const list=await(await fetch(base+'/recordings')).json();assert.equal(list.recordings[0].file,filename);
  const response=await fetch(base+'/export?file='+filename),exported=await response.json();
  assert.match(response.headers.get('content-disposition'),/attachment/);
  assert.equal(exported.actions.length,13);assert.equal(exported.trailing_record_ignored,false);
  assert.equal(new Set(exported.actions.map(a=>a.type)).size,11);
  function refs(list){for(const ref of list||[]){if(ref.hidden){assert.equal(ref.card,undefined);assert.equal(ref.instance,undefined);}else assert.ok(exported.cards[ref.card]);}}
  for(const action of exported.actions)for(const key of ['cards','targets','options'])refs(action[key]);
  for(const observation of exported.observations)for(const list of Object.values(observation.areas))refs(list);
  const first=exported.actions[0];assert.deepEqual(first.cards.map(c=>c.index),[2,3]);assert.equal(exported.cards[first.cards[0].card].rank,'Ace');assert.equal(exported.cards[first.cards[1].card].rank,'King');
  const options=first.options;assert.equal(options[0].card,options[1].card);assert.notEqual(options[0].instance,options[1].instance);
  assert.ok(!JSON.stringify(exported).includes('SECRET'));
  await fs.appendFile(path.join(dir,filename),'{"unfinished":');
  assert.equal((await(await fetch(base+'/export?file='+filename)).json()).trailing_record_ignored,true);
  await fs.writeFile(path.join(dir,filename),journal+'invalid complete line\n');
  assert.equal((await fetch(base+'/export?file='+filename)).status,422);
  await fs.writeFile(path.join(dir,filename),journal);
  assert.equal((await fetch(base+'/export?file=..%2FREADME.md')).status,422);
  assert.equal((await fetch(base+'/README.md')).status,404);
  assert.equal((await fetch(base+'/recordings',{method:'POST'})).status,405);
  browser=await chromium.launch({headless:true,executablePath:process.env.BROWSER_EXECUTABLE});const page=await browser.newPage({acceptDownloads:true});const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(base);await page.locator('.recording').waitFor();
  const downloadPromise=page.waitForEvent('download');await page.locator('#export-latest').click();const download=await downloadPromise;
  assert.equal(download.suggestedFilename(),'run-123-456-1.json');
  assert.equal(JSON.parse(await fs.readFile(await download.path(),'utf8')).actions.length,13);
  for(const width of [1440,390]){await page.setViewportSize({width,height:900});assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));}
  await page.screenshot({path:path.join(root,'work','export-page.png'),fullPage:true});
  assert.deepEqual(errors,[]);
  console.log('PASS: 11 tokens, dictionary/duplicate identities, complete and interrupted journal export, corruption refusal, path isolation, real browser JSON download and mobile layout');
 }finally{if(browser)await browser.close();child.kill();await new Promise(r=>child.exitCode!==null?r():child.once('exit',r));}
})().catch(e=>{console.error(e);process.exitCode=1;});
