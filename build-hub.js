// Build "PayedScriptsHub.lua" from launcher.template.lua + every hub .txt file.
// Run:  node build-hub.js
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const ROOT = __dirname;

// matched by an ASCII substring so the fancy unicode filenames still resolve
const ALL_FILES = fs.readdirSync(ROOT).filter(f => f.toLowerCase().endsWith('.txt'));

function findFile(fragment) {
  const hit = ALL_FILES.find(f => f.includes(fragment));
  if (!hit) throw new Error('no .txt file matching: ' + fragment);
  return hit;
}

// the two leaked-file names are written in unicode math-bold, so they are
// picked by name length instead of by an ASCII substring
function findFileNameOfLength(len) {
  const hit = ALL_FILES.find(f => f.length === len);
  if (!hit) throw new Error('no .txt file with a ' + len + ' char name');
  return hit;
}

const HUBS = [
  {
    id: 'divine', title: 'Divine Hub', file: findFile('Divine hub duel'),
    tags: 'speed · aimbot · ESP · safe mode',
    accent: [150, 124, 255],
    guis: ['DIVINE.CC_GUI', 'DIVINE.CC_Intro', 'DIVINE.CC_StealGUI',
           'DIVINE.CC_MobilePanel', 'DIVINE.CC_DarkMode'],
  },
  {
    id: 'uranium', title: 'Uranium / Vortex', file: findFile('Uranium.cc'),
    tags: 'speed · bat v2 · ESP',
    accent: [110, 225, 165],
    guis: ['UraniumIntro', 'VortexHub', 'VortexMobile'],
  },
  {
    id: 'hussxx', title: 'HussXx', file: findFile('HussXx_Intro'),
    tags: 'speed · aimbot · intro · mobile',
    accent: [255, 130, 165],
    guis: ['HussXxIntro', 'HussXx', 'HussXxMobilePanel', 'TpBatButton',
           'BatV2Button', 'InstaResetButton', 'CleanHubE01Warning'],
  },
  {
    id: 'source', title: 'Source Hub', file: findFile('source hub duels'),
    tags: 'speed · grab · mobile',
    accent: [255, 168, 92],
    guis: ['SourceHubIntro', 'MurderHubGUI', 'SOURCE_LockBtn'],
  },
  {
    id: 'neva', title: 'Neva Duels', file: findFileNameOfLength(46),
    tags: 'speed · steal bar · ESP',
    accent: [120, 200, 255],
    guis: ['Neva Duels', 'NevaDMobile', 'J1StealBar'],
  },
  {
    id: 'exe', title: 'Exe Duel', file: findFileNameOfLength(19),
    tags: 'speed · aimbot · insta reset',
    accent: [255, 104, 104],
    guis: ['ExeAnimationSearch', 'ExeInstaResetPanel', 'ExeMobileButtons',
           'ButtonBackground', 'ExeMenuBackground', 'ExeLagger_UI', '.exe'],
  },
  {
    id: 'lagger', title: 'Unpatched Lagger', file: findFile('Unpatched Lagger'),
    tags: 'lag switch · keybind',
    accent: [226, 214, 120],
    guis: ['KillHub_UI'],
  },
  {
    id: 'askar', title: 'Askar Confuser', file: findFile('Askar confuser'),
    tags: 'spin confuser · speed',
    accent: [255, 200, 60],
    guis: ['Askar_Confuser'],
  },
];

// nearest long-bracket level whose closing sequence is not present in the body
function bracketLevel(body) {
  for (let n = 2; n <= 12; n++) {
    const close = ']' + '='.repeat(n) + ']';
    if (!body.includes(close)) return n;
  }
  throw new Error('no safe long-bracket level');
}

const lines = [];
let total = 0;
let packedTotal = 0;

for (const hub of HUBS) {
  const full = path.join(ROOT, hub.file);
  if (!fs.existsSync(full)) throw new Error('missing file: ' + hub.file);
  let body = fs.readFileSync(full, 'utf8').replace(/^\uFEFF/, '');

  // CRLF -> LF keeps the embedded source tidy
  body = body.replace(/\r\n/g, '\n');
  // drop a single trailing newline so the closing bracket sits on its own line
  body = body.replace(/\n$/, '');

  // raw DEFLATE, then base64: 1.2 MB of source -> ~300 KB, which keeps the
  // whole script under the size caps some executors put on the script box
  const packed = zlib.deflateRawSync(Buffer.from(body, 'utf8'), { level: 9 });
  const b64 = packed.toString('base64');
  const wrapped = b64.replace(/(.{120})/g, (m) => m + '\n').replace(/\n$/, '');

  const n = bracketLevel(wrapped);
  const eq = '='.repeat(n);
  const kb = (Buffer.byteLength(body, 'utf8') / 1024).toFixed(0) + ' KB';
  const pkb = (wrapped.length / 1024).toFixed(0) + ' KB';

  total += Buffer.byteLength(body, 'utf8');
  packedTotal += wrapped.length;

  lines.push('');
  lines.push('HUBS[#HUBS + 1] = {');
  lines.push('    id     = ' + JSON.stringify(hub.id) + ',');
  lines.push('    title  = ' + JSON.stringify(hub.title) + ',');
  lines.push('    tags   = ' + JSON.stringify(hub.tags) + ',');
  lines.push('    source = ' + JSON.stringify(hub.file) + ',');
  lines.push('    size   = ' + JSON.stringify(kb) + ',');
  lines.push('    packed = ' + JSON.stringify(pkb) + ',');
  lines.push('    accent = Color3.fromRGB(' + hub.accent.join(', ') + '),');
  lines.push('    guiSet = { ' + hub.guis.map(g => '[' + JSON.stringify(g) + '] = true').join(', ') + ' },');
  lines.push('    src    = [' + eq + '[');
  lines.push(wrapped);
  lines.push(']' + eq + ']');
  lines.push('}');
}

const template = fs.readFileSync(path.join(ROOT, 'launcher.template.lua'), 'utf8')
  .replace(/\r\n/g, '\n');

if (!template.includes('--@@HUBS@@')) throw new Error('template marker not found');

// NOTE: use a replacer function - a plain string replacement would treat
// "$$", "$&" etc. in the embedded Lua as replacement patterns and corrupt it
const out = template.replace('--@@HUBS@@', () => lines.join('\n').replace(/^\n/, ''));
const dest = path.join(ROOT, 'PayedScriptsHub.lua');
fs.writeFileSync(dest, out, 'utf8');

console.log('wrote ' + dest);
console.log('embedded ' + HUBS.length + ' hubs, ' + (total / 1024).toFixed(0) + ' KB of script');
console.log('payload    ' + (packedTotal / 1024).toFixed(0) + ' KB after deflate + base64');
console.log('final file: ' + (Buffer.byteLength(out, 'utf8') / 1024).toFixed(0) + ' KB, ' +
  out.split('\n').length + ' lines');
