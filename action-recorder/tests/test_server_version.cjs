const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const net = require('node:net');
const {spawn} = require('node:child_process');
(async () => {
  const root = path.resolve(__dirname, '..');
  const script = path.join(root, 'server/start-recorder.ps1');
  const shell = path.join(process.env.SystemRoot, 'System32/WindowsPowerShell/v1.0/powershell.exe');
  const probe = net.createServer();
  await new Promise(resolve => probe.listen(0, '127.0.0.1', resolve));
  const port = probe.address().port;
  await new Promise(resolve => probe.close(resolve));
  const args = ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', script, '-Port', String(port), '-GamePid', String(process.pid)];
  const server = spawn(shell, [...args, '-Server'], {windowsHide: true});
  const status = path.join(__dirname, 'launcher.status');
  let errors = '';
  server.stderr.on('data', data => errors += data);
  try {
    let health;
    for (let i = 0; i < 100; i++) {
      try { health = await (await fetch(`http://127.0.0.1:${port}/health`)).json(); break; } catch {}
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    assert.ok(health, errors);
    assert.equal(health.version, JSON.parse(fs.readFileSync(path.join(root, '../BalatroObserver.json'))).version);
    for (const request of ['first', 'retry']) {
      const launch = spawn(shell, [...args, '-NoOpen', '-Request', request, '-StatusFile', status], {windowsHide: true});
      launch.stderr.on('data', data => errors += data);
      const code = await new Promise(resolve => launch.on('exit', resolve));
      assert.equal(code, 0, errors);
      assert.equal(fs.readFileSync(status, 'utf8'), `${request}:ready`);
    }
    console.log('PASS: recorder health matches manifest; launcher accepts and reuses current server');
  } finally {
    server.kill();
    fs.rmSync(status, {force: true});
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
