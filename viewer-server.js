const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');

// An unavailable observation can be newest: never fall back to an older playable state.
function newest(records) {
  return records.filter(s => s && s.schema_version === 1 &&
    typeof s.available === 'boolean' && typeof s.session === 'string' &&
    Number.isFinite(s.observed_at) && Number.isFinite(s.sequence))
    .sort((a, b) => b.observed_at - a.observed_at ||
      (a.session === b.session ? b.sequence - a.sequence : b.session.localeCompare(a.session)))[0] || null;
}
async function readState(directory) {
  // One slot can be partially written while the other remains a valid snapshot.
  const records = await Promise.all([0, 1].map(async slot => {
    try { return JSON.parse(await fs.readFile(path.join(directory, 'state-' + slot + '.json'), 'utf8')); }
    catch { return null; }
  }));
  const state = newest(records);
  return { state, stale: !state || Date.now() / 1000 - state.observed_at > 3, directory };
}
function createServer(directory) {
  return http.createServer(async (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    try {
      const url = new URL(req.url, 'http://localhost');
      if (url.pathname === '/state') {
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify(await readState(directory)));
      } else if (url.pathname === '/' || url.pathname === '/observer.html') {
        res.setHeader('Content-Type', 'text/html; charset=utf-8');
        res.end(await fs.readFile(path.join(__dirname, 'observer.html')));
      } else {
        res.writeHead(404); res.end('Not found');
      }
    } catch {
      res.writeHead(500); res.end('Unable to read observer data');
    }
  });
}
if (require.main === module) {
  const directory = path.resolve(process.argv[2] || path.join(process.env.APPDATA || '.', 'Balatro', 'balatro_observer'));
  const port = Number(process.env.PORT || 8765);
  const server = createServer(directory);
  server.on('error', err => { console.error(err.message); process.exitCode = 1; });
  // Serve locally so the dashboard can read snapshots without browser file access.
  server.listen(port, '127.0.0.1', () => {
    console.log('Observer viewer: http://127.0.0.1:' + port);
    console.log('Reading: ' + directory);
  });
}
module.exports = { newest, readState, createServer };

