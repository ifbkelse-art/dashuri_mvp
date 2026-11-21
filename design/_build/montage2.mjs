import { writeFileSync } from 'node:fs'; import { execFileSync } from 'node:child_process';
const [out, cols, ...files] = process.argv.slice(2); const c=Number(cols), w=800, h=500;
writeFileSync('/tmp/_m2.html', `<html><body style="margin:0;background:#888;display:grid;grid-template-columns:repeat(${c},${w}px);gap:6px;padding:6px">${files.map(f=>`<img src="file://${f}" style="width:${w}px;height:${h}px">`).join('')}</body></html>`);
execFileSync('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',['--headless=new','--hide-scrollbars','--allow-file-access-from-files',`--window-size=${c*806+6},${Math.ceil(files.length/c)*506+6}`,'--force-device-scale-factor=1',`--screenshot=${out}`,'file:///tmp/_m2.html'],{stdio:'ignore'});
