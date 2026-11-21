import { readFileSync } from 'node:fs';
const OUT = process.env.OUT || '../Dashuri_Design';
const base = 'file://' + process.cwd() + '/board.html';
const jobs = [];
for (const [file, folder] of [['sheets.js','Components'],['flows.js','User_Flows']]) {
  const src = readFileSync(file,'utf8');
  for (const m of src.matchAll(/(?:SH|FL)\('([A-Z]+\d+)','([^']+)'/g)) if (new RegExp(process.argv[2]||'.').test(m[1])) jobs.push({ url:`${base}?id=${m[1]}`, out:`${OUT}/${folder}/${m[1]}_${m[2]}.png`, w:1600, h:1000, dsf:2 });
}
console.log(JSON.stringify(jobs));
