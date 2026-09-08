const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { newest, readState, createServer } = require('../server/viewer-server');
const record = (sequence, available=true) => ({schema_version:1,session:'test',sequence,observed_at:Math.floor(Date.now()/1000),available,phase:'SHOP'});
test('latest unavailable record supersedes playable observation', () => {
  assert.equal(newest([record(1),record(2,false)]).available,false);
  assert.equal(newest([null,{},record(3)]).sequence,3);
});
test('session changes prioritize timestamp over previous sequence',()=>{
  assert.equal(newest([{...record(999),observed_at:1},{...record(1),session:'new',observed_at:2}]).session,'new');
});
test('file recovery, staleness and HTTP integration',async()=>{
  const dir=await fs.mkdtemp(path.join(os.tmpdir(),'observer-viewer-'));
  let server;
  try {
    assert.equal((await readState(dir)).state,null);
    await fs.writeFile(path.join(dir,'state-0.json'),JSON.stringify(record(2)));
    await fs.writeFile(path.join(dir,'state-1.json'),'{"incomplete":');
    assert.equal((await readState(dir)).state.sequence,2);
    await fs.writeFile(path.join(dir,'state-1.json'),JSON.stringify(record(3,false)));
    assert.equal((await readState(dir)).state.available,false);
    await fs.writeFile(path.join(dir,'state-0.json'),JSON.stringify({...record(2),observed_at:1}));
    await fs.writeFile(path.join(dir,'state-1.json'),JSON.stringify({...record(3),observed_at:2}));
    assert.equal((await readState(dir)).stale,true);
    server=createServer(dir);await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
    const base='http://127.0.0.1:'+server.address().port;
    assert.match(await (await fetch(base)).text(),/Balatro Observer/);
    assert.equal((await (await fetch(base+'/state')).json()).state.sequence,3);
    assert.equal((await fetch(base+'/main.lua')).status,404);
    for (const asset of ['8BitDeck_opt2.png','Enhancers.png','Editions.png','Jokers.png']) {
      const response=await fetch(base+'/assets/'+asset);
      assert.equal(response.status,200);assert.equal(response.headers.get('content-type'),'image/png');
      assert.deepEqual(Buffer.from(await response.arrayBuffer()).subarray(0,8),Buffer.from([137,80,78,71,13,10,26,10]));
    }
    assert.match(await (await fetch(base+'/credits')).text(),/Copyright \(c\) 2024 Saffron Haas/);
    assert.equal((await fetch(base+'/assets/main.lua')).status,404);
    assert.equal((await fetch(base+'/assets/%2e%2e/main.lua')).status,404);
  } finally {if(server)await new Promise(resolve=>server.close(resolve));await fs.rm(dir,{recursive:true,force:true});}
});
