const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { newest, readState, createServer } = require('../viewer-server');
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
  } finally {if(server)await new Promise(resolve=>server.close(resolve));await fs.rm(dir,{recursive:true,force:true});}
});

