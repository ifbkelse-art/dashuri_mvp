// node montage.mjs out.png cols file1 file2 ...  -> contact sheet for visual QA
import { writeFileSync } from 'node:fs'; import { execFileSync } from 'node:child_process';
const [out, cols, ...files] = process.argv.slice(2); const c = Number(cols); const w = 390, h = 844, s = 0.5;
const rows = Math.ceil(files.length / c);
const html = `<html><body style="margin:0;background:#888;display:grid;grid-template-columns:repeat(${c},${w*s}px);gap:6px;padding:6px">${files.map(f => `<div style="position:relative"><img src="file://${f}" style="width:${w*s}px;height:${h*s}px;display:block"><span style="position:absolute;top:0;left:0;background:#000;color:#fff;font:10px sans-serif;padding:2px">${f.split('/').pop().slice(0,22)}</span></div>`).join('')}</body></html>`;
writeFileSync('/tmp/_m.html', html);
const W = Math.round(c * (w*s + 6) + 6), H = Math.round(rows * (h*s + 6) + 6);
execFileSync('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', ['--headless=new','--hide-scrollbars','--allow-file-access-from-files',`--window-size=${W},${H}`,'--force-device-scale-factor=1',`--screenshot=${out}`,'file:///tmp/_m.html'], { stdio: 'ignore' });
