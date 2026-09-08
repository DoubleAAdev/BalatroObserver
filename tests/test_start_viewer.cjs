const {test}=require('node:test');const assert=require('node:assert/strict');const http=require('node:http');
const {ensureViewer}=require('../server/start-viewer');const {createServer}=require('../server/viewer-server');
const listen=server=>new Promise(r=>server.listen(0,'127.0.0.1',r));
const close=server=>new Promise(r=>server.close(r));
test('already running viewer is reused without launching a duplicate',async()=>{
 const server=createServer('.');await listen(server);
 try{const result=await ensureViewer({port:server.address().port,launch:()=>assert.fail('duplicate launch')});assert.equal(result.started,false);}finally{await close(server);}
});
test('cold start waits until the viewer responds',async()=>{
 const reservation=http.createServer();await listen(reservation);const port=reservation.address().port;await close(reservation);
 const server=createServer('.');let count=0;
 try{const result=await ensureViewer({port,launch:()=>{count++;setTimeout(()=>server.listen(port,'127.0.0.1'),150);}});assert.equal(count,1);assert.equal(result.started,true);}finally{await close(server);}
});
test('occupied port is reported without launching or killing another service',async()=>{
 const server=http.createServer((req,res)=>res.end('Other app'));await listen(server);
 try{await assert.rejects(ensureViewer({port:server.address().port,launch:()=>assert.fail('must not launch')}),/occupied/);}finally{await close(server);}
});
test('failed startup is bounded and explains where to find details',async()=>{
 const reservation=http.createServer();await listen(reservation);const port=reservation.address().port;await close(reservation);
 await assert.rejects(ensureViewer({port,launch:()=>{},timeout:150}),/viewer-server.log/);
});
