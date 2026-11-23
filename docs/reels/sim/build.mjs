// Builds docs/reels/DASHURI_REELS_FINANCIAL_SIMULATOR.html (standalone,
// works offline; fonts are optional). Run from the repo root:
//   node docs/reels/sim/build.mjs
import { readFileSync, writeFileSync } from 'node:fs';
const here = new URL('.', import.meta.url);
const read = p => readFileSync(new URL(p, here), 'utf8').replace(/<\/script/gi, '<\\/script');
const html = readFileSync(new URL('simulator.template.html', here), 'utf8')
  .replace('/*__FINANCE_ENGINE__*/', () => read('../../finance/engine/dashuri-model.js'))
  .replace('/*__REELS_MODEL__*/', () => read('reels-model.js'));
const out = new URL('../DASHURI_REELS_FINANCIAL_SIMULATOR.html', here);
writeFileSync(out, html);
console.log('wrote', out.pathname, (html.length / 1024).toFixed(0) + ' KB');
