// Both background servers must exit with their game process, without touching another process.
const assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {once}=require('node:events');
const net=require('node:net');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const powershell=path.join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe');
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function port(){const probe=net.createServer();await new Promise(r=>probe.listen(0,'127.0.0.1',r));const value=probe.address().port;await new Promise(r=>probe.close(r));return value;}
async function waitFor(check){for(let i=0;i<150;i++){if(await check())return;await sleep(100);}assert.fail('Timed out waiting for server lifecycle');}
(async()=>{
 const unrelated=spawn(process.execPath,['-e','setInterval(()=>{},1000)'],{windowsHide:true});
 try{
  for(const script of ['server/start-viewer.ps1','action-recorder/server/start-recorder.ps1']){
   for(const forced of [false,true]){
    const game=spawn(process.execPath,['-e','process.stdin.resume();process.stdin.once("data",()=>process.exit(0))'],{windowsHide:true});
    const servicePort=await port();
    const args=['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',path.join(root,script),'-Port',String(servicePort),'-GamePid',String(game.pid)];
    const server=spawn(powershell,[...args,'-Server'],{windowsHide:true});
    let error='';server.stderr.on('data',data=>error+=data);
    try{
     await waitFor(async()=>{assert.equal(server.exitCode,null,error);try{return (await(await fetch('http://127.0.0.1:'+servicePort+'/health')).json()).gamePid===game.pid;}catch{return false;}});
     // The launcher must reuse a server already tied to this game.
     const launcher=spawn(powershell,[...args,'-NoOpen'],{windowsHide:true});
     assert.equal((await once(launcher,'exit'))[0],0);
     if(forced)game.kill();else game.stdin.write('exit');
     await waitFor(()=>server.exitCode!==null);
     assert.equal(server.exitCode,0,error);
     await assert.rejects(fetch('http://127.0.0.1:'+servicePort+'/health'));
     assert.equal(unrelated.exitCode,null);
    }finally{game.kill();if(server.exitCode===null)server.kill();}
   }
  }
  console.log('PASS: both Windows servers stop on normal and forced game exit; matching launchers reuse them; unrelated processes survive');
 }finally{unrelated.kill();}
})().catch(error=>{console.error(error);process.exitCode=1;});
