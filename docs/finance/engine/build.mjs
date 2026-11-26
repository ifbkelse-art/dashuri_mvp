// Builds the finance deliverables from the one engine.
// Run: node docs/finance/engine/build.mjs [--fragment <path>] [--summary <path>]
//   → docs/finance/DASHURI_FINANCIAL_SIMULATOR.html   (standalone page, engine inlined)
//   → docs/finance/DASHURI_SIX_MONTH_PROJECTIONS.csv  (3 scenarios × 6 months)
//   → docs/finance/DASHURI_FINANCIAL_ASSUMPTIONS.json (every input, source, status)
import { createRequire } from 'node:module';
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const require = createRequire(import.meta.url);
const here = path.dirname(fileURLToPath(import.meta.url));
const out = path.resolve(here, '..');
const M = require('./dashuri-model.js');
const arg = k => { const i = process.argv.indexOf(k); return i > 0 ? process.argv[i + 1] : null; };
const START = '2027-01-01';

const engine = readFileSync(path.join(here, 'dashuri-model.js'), 'utf8');
const template = readFileSync(path.join(here, 'simulator.template.html'), 'utf8');
const fragment = template.replace('/*__ENGINE__*/', () => engine.replace(/<\/script/gi, '<\\/script'));
const page = '<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">\n</head>\n<body>\n' + fragment + '\n</body>\n</html>\n';
writeFileSync(path.join(out, 'DASHURI_FINANCIAL_SIMULATOR.html'), page);
if (arg('--fragment')) writeFileSync(arg('--fragment'), fragment);

const runs = Object.fromEntries(M.SCENARIOS.map(s => [s, M.run(M.defaults(s))]));
writeFileSync(path.join(out, 'DASHURI_SIX_MONTH_PROJECTIONS.csv'), M.toCSV(M.SCENARIOS.map(s => [M.SCENARIO_LABEL[s], runs[s]])));
writeFileSync(path.join(out, 'DASHURI_FINANCIAL_ASSUMPTIONS.json'), JSON.stringify(M.assumptionsDocument(Object.fromEntries(M.SCENARIOS.map(s => [s, M.defaults(s)])), START), null, 2) + '\n');

if (arg('--summary')) {
  const pick = r => { const { months, params, unit, ...rest } = r; return { ...rest, months: months.map(m => { const { packagesSold, grossByPackage, ...x } = m; return x; }), unit: { avgPrice: unit.avgPrice, avgDiamonds: unit.avgDiamonds, grossPerDiamond: unit.grossPerDiamond, exGstPerDiamond: unit.exGstPerDiamond } }; };
  const base = M.defaults('base');
  writeFileSync(arg('--summary'), JSON.stringify({
    runs: Object.fromEntries(Object.entries(runs).map(([k, v]) => [k, pick(v)])),
    sensitivity: M.sensitivity(base), stress: M.stress(base), stressCons: M.stress(M.defaults('conservative')),
    levers: M.levers(base), leversCons: M.levers(M.defaults('conservative')),
    pkg1500: M.packageEconomics(base, 1500), pkg500: M.packageEconomics(base, 500),
    perMinute: [500, 1000, 1500, 2000, 4000, 10000].map(r => M.perMinute(base, r))
  }, null, 1));
}
console.log('Built:', ['DASHURI_FINANCIAL_SIMULATOR.html', 'DASHURI_SIX_MONTH_PROJECTIONS.csv', 'DASHURI_FINANCIAL_ASSUMPTIONS.json'].map(f => path.join('docs/finance', f)).join(', '));
