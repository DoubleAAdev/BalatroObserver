const assert=require('node:assert/strict');
const fs=require('node:fs/promises');
const path=require('node:path');
const os=require('node:os');
const net=require('node:net');
const {spawn}=require('node:child_process');
const {chromium}=require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const version=require('../BalatroObserver.json').version;
const root=path.resolve(__dirname,'..');
const powershell=path.join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe');
const cleanEnv={...process.env,PATH:path.join(process.env.SystemRoot,'System32')};
function run(args){return new Promise((resolve,reject)=>{let output='';const child=spawn(powershell,['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass',...args],{env:cleanEnv,windowsHide:true});child.stdout.on('data',s=>output+=s);child.stderr.on('data',s=>output+=s);child.on('error',reject);child.on('exit',code=>resolve({code,output}));});}
(async()=>{
 const dir=await fs.mkdtemp(path.join(os.tmpdir(),'observer no node '));
 const socket=net.createServer();await new Promise(r=>socket.listen(0,'127.0.0.1',r));const port=socket.address().port;await new Promise(r=>socket.close(r));
 const base='http://127.0.0.1:'+port;
 let output='',browser;
 const child=spawn(powershell,['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',path.join(root,'server/start-viewer.ps1'),'-Server','-StateDirectory',dir,'-Port',String(port)],{env:cleanEnv,windowsHide:true});
 child.stderr.on('data',s=>output+=s);
 try {
  let health;for(let i=0;i<100;i++){try{health=await(await fetch(base+'/health')).json();break;}catch{await new Promise(r=>setTimeout(r,100));}}
  assert.equal(health?.version,version,output);assert.equal(health.runtime,'Windows PowerShell/.NET');
  assert.equal((await(await fetch(base+'/state')).json()).state,null);
  const state={schema_version:1,available:true,session:'test',sequence:1,observed_at:Date.now()/1000,mod_version:'0.7.5',phase:'SELECTING_HAND',hand:{cards:[{visible:false,slot:1}]},jokers:{cards:[]},vouchers:[]};
  const put=(slot,s)=>fs.writeFile(path.join(dir,`state-${slot}.json`),typeof s==='string'?s:JSON.stringify(s));
  await put(0,state);await put(1,'{"partial":');
  assert.deepEqual((await(await fetch(base+'/state')).json()).state,state);
  await put(1,{...state,available:false,sequence:2});
  assert.equal((await(await fetch(base+'/state')).json()).state.available,false);
  await put(1,{...state,observed_at:1,sequence:1000});await put(0,{...state,observed_at:2});
  assert.equal((await(await fetch(base+'/state')).json()).stale,true);
  await put(1,{...state,observed_at:'invalid'});await put(0,state);
  for(const route of ['/credits','/observer.html','/observer.css','/observer.js','/joker-sprites.js','/assets/8BitDeck_opt2.png','/assets/Enhancers.png','/assets/Editions.png','/assets/Jokers.png','/assets/wiki-art.js','/score-preview.js','/assets/calculator/balatro-sim.js','/assets/calculator/joker-ids.js',...require('../assets/wiki-art.json').map(x=>'/'+x.file)]) {
   const response=await fetch(base+route);assert.equal(response.status,200,route);assert.ok((await response.arrayBuffer()).byteLength>0,route);
  }
  for(const route of ['/missing.txt','/main.lua','/BalatroObserver.json','/mod/observer.lua','/server/viewer-server.cs','/scripts/sync-mod.ps1','/%2e%2e%2fmissing.txt']) assert.equal((await fetch(base+route)).status,404,route);
  assert.equal((await fetch(base+'/state',{method:'POST'})).status,405);
  const statusFile=path.join(dir,'status.txt');
  const reuse=await run(['-File',path.join(root,'server/start-viewer.ps1'),'-NoOpen','-Port',String(port),'-Request','test-request','-StatusFile',statusFile]);
  assert.equal(reuse.code,0,reuse.output);assert.equal(await fs.readFile(statusFile,'utf8'),'test-request:ready');
  const unrelated=require('node:http').createServer((req,res)=>res.end(JSON.stringify({app:'BalatroObserver',version:'0.1.0'})));
  await new Promise(r=>unrelated.listen(0,'127.0.0.1',r));
  try {
   const occupied=await run(['-File',path.join(root,'server/start-viewer.ps1'),'-NoOpen','-Port',String(unrelated.address().port),'-Request','occupied','-StatusFile',statusFile]);
   assert.notEqual(occupied.code,0);assert.match(occupied.output,/occupied/);
   assert.equal(await fs.readFile(statusFile,'utf8'),'occupied:error');
   assert.equal((await fetch('http://127.0.0.1:'+unrelated.address().port)).status,200);
  } finally {await new Promise(r=>unrelated.close(r));}
  browser=await chromium.launch({headless:true,...(process.env.BROWSER_EXECUTABLE?{executablePath:process.env.BROWSER_EXECUTABLE}:{})});
  const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(base);await page.locator('#content:not([hidden])').waitFor();
  assert.equal(await page.title(),'Balatro Observer v'+version);
  assert.match(await page.locator('#viewer-version').textContent(),new RegExp(version));
  assert.match(await page.locator('#mod-version').textContent(),/0.7.5/);
  assert.match(await page.locator('#version-note').textContent(),/restart/i);
  await page.locator('#nav-hand').click();assert.match(await page.locator('#panels').textContent(),/Face down/);
  await put(0,{...state,sequence:3,mod_version:version,hand:{cards:[{visible:true,rank:'Ace',suit:'Spades',key:'c_base'}]},observed_at:Date.now()/1000});
  await page.waitForFunction(()=>document.querySelector('#panels').textContent.includes('Ace'));
  await page.screenshot({path:path.join(root,'.test-runtime/windows-viewer-100.png'),fullPage:true});
  assert.deepEqual(errors,[]);
  console.log('PASS: Windows server without Node on PATH; raw snapshot preservation, incomplete slots, unavailable/latest/stale records, all asset routes, private path rejection, launcher reuse and readiness, Chromium live updates, redaction and version mismatch.');
 } finally {if(browser)await browser.close();child.kill();await new Promise(r=>child.exitCode!==null?r():child.once('exit',r));await fs.rm(dir,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
