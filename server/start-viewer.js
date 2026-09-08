'use strict';
// Optional Node.js launcher: reuses a healthy viewer of this release or starts server/viewer-server.js, then opens the browser.
// The Windows in-game button uses start-viewer.ps1 instead; this file exists for other platforms and tests.
const http=require('node:http');
const fs=require('node:fs');
const path=require('node:path');
const {spawn}=require('node:child_process');
const root=path.resolve(__dirname,'..');
const release=require(path.join(root,'BalatroObserver.json')).version;

// 'ready' only for a viewer of this exact release. This launcher never stops another process: an older
// viewer is reported as 'outdated' (the Windows launcher replaces it; here, close it and retry).
function probe(port,version=release){
 return new Promise(resolve=>{
  const request=http.get({hostname:'127.0.0.1',port,path:'/health',timeout:500},response=>{
   let body='';response.on('data',chunk=>{body+=chunk;if(body.length>4096)request.destroy();});
   response.on('error',()=>resolve('occupied'));
   response.on('end',()=>{try{const health=JSON.parse(body);resolve(health.app!=='BalatroObserver'?'occupied':health.version===version?'ready':'outdated');}catch{resolve('occupied');}});
  });
  request.on('timeout',()=>request.destroy());
  request.on('error',error=>resolve(error.code==='ECONNREFUSED'?'stopped':'occupied'));
 });
}
async function ensureViewer({port=8765,launch,timeout=10000,version=release}={}){
 const initial=await probe(port,version);
 if(initial==='ready')return {started:false,port};
 if(initial==='outdated')throw new Error('Port '+port+' is used by an older Balatro Observer viewer. Close it and try again.');
 if(initial==='occupied')throw new Error('Port '+port+' is occupied by another application. Close it and try again.');
 if(launch)await launch();
 else{
  const log=fs.openSync(path.join(root,'viewer-server.log'),'a');
  try{
   const child=spawn(process.execPath,[path.join(__dirname,'viewer-server.js')],{cwd:root,env:{...process.env,PORT:String(port)},detached:true,windowsHide:true,stdio:['ignore',log,log]});
   await new Promise((resolve,reject)=>{child.once('spawn',resolve);child.once('error',reject);});
   child.unref();
  }finally{fs.closeSync(log);}
 }
 const deadline=Date.now()+timeout;
 while(Date.now()<deadline){if(await probe(port,version)==='ready')return {started:true,port};await new Promise(r=>setTimeout(r,100));}
 throw new Error('The viewer did not become ready. See viewer-server.log in the mod folder.');
}
function openBrowser(url){
 const command="Start-Process -FilePath '"+url.replaceAll("'","''")+"'";
 const args=process.platform==='win32'?['-NoProfile','-NonInteractive','-EncodedCommand',Buffer.from(command,'utf16le').toString('base64')]:[url];
 const child=spawn(process.platform==='win32'?'powershell.exe':process.platform==='darwin'?'open':'xdg-open',args,{detached:true,windowsHide:true,stdio:'ignore'});
 child.on('error',()=>{});child.unref();
}
function reportStatus(state){
 const request=process.argv.find(arg=>arg.startsWith('--request='))?.slice(10);
 const file=process.argv.find(arg=>arg.startsWith('--status-file='))?.slice(14);
 if(request&&file){fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,request+':'+state);}
}
if(require.main===module)ensureViewer().then(result=>{
 reportStatus('ready');
 console.log(result.started?'Viewer started and ready':'Viewer already running');
 if(!process.argv.includes('--no-open'))openBrowser('http://127.0.0.1:8765');
}).catch(error=>{
 reportStatus('error');
 console.error(error.message);
 const escape=s=>s.replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const file=path.join(root,'viewer-start-error.html');
 fs.writeFileSync(file,'<!doctype html><meta charset="utf-8"><title>Balatro Observer</title><h1>Unable to start Balatro Observer</h1><p>'+escape(error.message)+'</p>');
 if(!process.argv.includes('--no-open'))openBrowser(require('node:url').pathToFileURL(file).href);
 process.exitCode=1;
});
module.exports={ensureViewer,probe};
