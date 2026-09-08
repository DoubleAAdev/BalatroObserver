// Optional Node.js viewer server for non-Windows platforms and development tests.
// Serves the same read-only routes as server/viewer-server.cs. Usage: node server/viewer-server.js [stateDirectory]
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');

// The mod folder holds the manifest, viewer/, assets/ and credits; this file lives in server/.
const root = path.resolve(__dirname, '..');
const version = require(path.join(root, 'BalatroObserver.json')).version;

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

// URLs are stable across releases; only the disk layout under the mod folder changes.
// Explicit routes keep private mod files and arbitrary paths inaccessible.
const publicFiles = new Map([
  ['/', ['viewer/observer.html', 'text/html; charset=utf-8']],
  ['/observer.html', ['viewer/observer.html', 'text/html; charset=utf-8']],
  ['/observer.css', ['viewer/observer.css', 'text/css; charset=utf-8']],
  ['/credits', ['THIRD_PARTY_NOTICES.md', 'text/plain; charset=utf-8']]
]);
for (const file of ['observer.js', 'joker-sprites.js', 'score-preview.js']) publicFiles.set('/' + file, ['viewer/' + file, 'text/javascript; charset=utf-8']);
for (const file of ['assets/wiki-art.js', 'assets/calculator/balatro-sim.js', 'assets/calculator/joker-ids.js']) publicFiles.set('/' + file, [file, 'text/javascript; charset=utf-8']);
for (const file of ['8BitDeck_opt2.png', 'Enhancers.png', 'Editions.png', 'Jokers.png']) publicFiles.set('/assets/' + file, ['assets/' + file, 'image/png']);
for (const item of require(path.join(root, 'assets/wiki-art.json'))) {
  const type = { '.png': 'image/png', '.gif': 'image/gif', '.jpg': 'image/jpeg', '.webp': 'image/webp' }[path.extname(item.file)];
  if (!/^assets\/wiki\/[^/\\]+$/.test(item.file) || !type) throw new Error('Invalid bundled artwork path');
  publicFiles.set('/' + item.file, [item.file, type]);
}

function createServer(directory) {
  return http.createServer(async (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    try {
      const url = new URL(req.url, 'http://localhost');
      const route = publicFiles.get(decodeURIComponent(url.pathname));
      if (req.method !== 'GET') {
        res.writeHead(405); res.end('Method not allowed');
      } else if (url.pathname === '/health') {
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify({ app: 'BalatroObserver', version, runtime: 'Node.js' }));
      } else if (url.pathname === '/state') {
        res.setHeader('Content-Type', 'application/json');
        res.end(JSON.stringify(await readState(directory)));
      } else if (route) {
        const [file, contentType] = route;
        res.setHeader('Content-Type', contentType);
        res.end(await fs.readFile(path.join(root, file)));
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
module.exports = { newest, readState, createServer, root, version };
