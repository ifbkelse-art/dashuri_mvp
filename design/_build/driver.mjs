// Minimal Chrome DevTools Protocol driver: renders PNG screenshots and PDFs.
// Usage: node driver.mjs jobs.json [concurrency]
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { tmpdir } from 'node:os';

const jobs = JSON.parse(readFileSync(process.argv[2], 'utf8'));
const CONC = Number(process.argv[3] || 4);
const PORT = 9300 + Math.floor(Math.random() * 500);
const CH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const prof = mkdtempSync(join(process.env.TMPDIR || tmpdir(), 'dsh-'));
const chrome = spawn(CH, ['--headless=new', `--remote-debugging-port=${PORT}`, `--user-data-dir=${prof}`, '--hide-scrollbars',
  '--allow-file-access-from-files', '--disable-gpu', '--no-first-run', '--no-default-browser-check', 'about:blank'], { stdio: 'ignore' });

const sleep = ms => new Promise(r => setTimeout(r, ms));
async function json(path, method = 'GET') { for (let i = 0; i < 60; i++) { try { const r = await fetch(`http://127.0.0.1:${PORT}${path}`, { method }); return await r.json(); } catch { await sleep(250); } } throw new Error('chrome not up'); }

class Page {
  constructor(ws) { this.ws = ws; this.id = 0; this.cb = new Map(); this.ev = [];
    ws.onmessage = m => { const d = JSON.parse(m.data); if (d.id && this.cb.has(d.id)) { this.cb.get(d.id)(d); this.cb.delete(d.id); } else if (d.method) this.ev.forEach(f => f(d)); }; }
  send(method, params = {}) { const id = ++this.id; return new Promise((res, rej) => { this.cb.set(id, d => d.error ? rej(new Error(method + ': ' + d.error.message)) : res(d.result)); this.ws.send(JSON.stringify({ id, method, params })); }); }
  waitEvent(name, ms = 30000) { return new Promise(res => { const t = setTimeout(() => res(null), ms); const f = d => { if (d.method === name) { clearTimeout(t); this.ev = this.ev.filter(x => x !== f); res(d); } }; this.ev.push(f); }); }
}
async function newPage() { const t = await json('/json/new?about:blank', 'PUT'); const ws = new WebSocket(t.webSocketDebuggerUrl); await new Promise(r => ws.onopen = r); const p = new Page(ws); await p.send('Page.enable'); await p.send('Runtime.enable'); return p; }

async function run(p, j) {
  await p.send('Emulation.setDeviceMetricsOverride', { width: j.w || 390, height: j.h || 844, deviceScaleFactor: j.dsf || 3, mobile: false });
  const load = p.waitEvent('Page.loadEventFired', 60000);
  await p.send('Page.navigate', { url: j.url }); await load;
  for (let i = 0; i < 240; i++) { const r = await p.send('Runtime.evaluate', { expression: '!!window.__ready', returnByValue: true }); if (r.result.value) break; await sleep(100); }
  mkdirSync(dirname(j.out), { recursive: true });
  if (j.type === 'pdf') {
    const r = await p.send('Page.printToPDF', { printBackground: true, preferCSSPageSize: true, timeout: 600000 });
    writeFileSync(j.out, Buffer.from(r.data, 'base64'));
  } else {
    const r = await p.send('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: j.y || 0, width: j.w || 390, height: j.h || 844, scale: j.scale || 1 }, captureBeyondViewport: !!j.y });
    writeFileSync(j.out, Buffer.from(r.data, 'base64'));
  }
  process.stdout.write('.');
}

try {
  await json('/json/version');
  const queue = [...jobs]; const pages = await Promise.all(Array.from({ length: Math.min(CONC, jobs.length) }, newPage));
  await Promise.all(pages.map(async p => { while (queue.length) { const j = queue.shift(); try { await run(p, j); } catch (e) { console.error('\nFAIL', j.out, e.message); } } }));
  console.log(`\nrendered ${jobs.length}`);
} finally { chrome.kill(); }
