// Builds render jobs for screens (hi-fi + wireframe). Usage: node jobs.mjs [filterRegex] > jobs.json
import { readFileSync, readdirSync } from 'node:fs';
const OUT = process.env.OUT || '../Dashuri_Design';
const filt = new RegExp(process.argv[2] || '.');
const base = 'file://' + process.cwd() + '/render.html';
const jobs = [];
for (const f of readdirSync('.').filter(f => /^s_.*\.js$/.test(f)).sort()) {
  const src = readFileSync(f, 'utf8');
  const consts = Object.fromEntries([...src.matchAll(/const (F_\w+)\s*=\s*'([^']+)'/g)].map(m => [m[1], m[2]]));
  for (const m of src.matchAll(/S\(\{id:'([^']+)',folder:(\w+),name:'([^']+)'/g)) {
    const [, id, fc, name] = m; if (!filt.test(id)) continue;
    const folder = consts[fc] || fc;
    jobs.push({ url: `${base}?id=${id}`, out: `${OUT}/${folder}/${id}_${name}.png`, id });
    if (!process.env.NOWF) jobs.push({ url: `${base}?id=${id}&wf=1`, out: `${OUT}/Wireframes/${folder}/${id}_${name}_wireframe.png`, id });
  }
}
console.log(JSON.stringify(jobs));
