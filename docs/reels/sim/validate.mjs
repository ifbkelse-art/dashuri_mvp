// Validates the Reels incremental model against the finance engine.
// Run from the repo root: node docs/reels/sim/validate.mjs
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
const require = createRequire(import.meta.url);
const F = require('../../finance/engine/dashuri-model.js');
const R = require('./reels-model.js');

let pass = 0, fail = 0;
const ok = (name, cond, detail = '') => { if (cond) { pass++; console.log('PASS', name); } else { fail++; console.log('FAIL', name, detail); } };
const near = (a, b, eps = 1e-6) => Math.abs(a - b) <= eps * Math.max(1, Math.abs(a), Math.abs(b));
const zero = r => Object.assign({}, r, { churnReduction: 0, nonPayerRetentionUplift: 0, laterConversionUplift: 0, signupUplift: 0, cannibalization: 0 });

for (const sc of R.SCENARIOS) {
  const fp = F.defaults(sc), rp = R.defaults(sc);
  const res = R.run(F, fp, rp);
  const direct = F.run(fp);
  ok(`${sc}: Scenario A is the unmodified finance engine`, near(res.A.cumOperatingProfit, direct.cumOperatingProfit) && near(res.A.cumRevenue, direct.cumRevenue));
  const z = R.run(F, fp, zero(rp));
  ok(`${sc}: zero impact → no incremental revenue (no double counting)`, z.rows.every(x => near(x.dRevenue, 0)));
  ok(`${sc}: zero impact → Δ operating = −Reels cost`, z.rows.every(x => near(x.dOperating, -x.reelsCost)));
  ok(`${sc}: costs are non-negative and finite`, res.rows.every(x => ['video', 'moderationApi', 'humanReview', 'compute', 'reelsCost'].every(k => Number.isFinite(x[k]) && x[k] >= 0)));
  ok(`${sc}: B operating = A operating + Δ`, near(res.summary.operatingB, res.summary.operatingA + res.summary.sixMonthDOperating));
  ok(`${sc}: Δ operating = Σ monthly`, near(res.summary.sixMonthDOperating, res.rows.reduce((s, x) => s + x.dOperating, 0)));
  ok(`${sc}: stored minutes never decrease`, res.rows.every((x, i) => i === 0 || x.storedMin >= res.rows[i - 1].storedMin));
}

// Mux free tier and credit.
{
  const fp = F.defaults('base');
  const small = Object.assign(R.defaults('base'), { viewsPerViewer: 1, adoption: 0.1, reelsPerCreator: 0, reelsPerHost: 0 });
  const r = R.run(F, fp, small);
  ok('delivery under the 100k free minutes costs ₹0', r.rows.every(x => x.watchMin < 100000 && x.video === 0));
  const big = Object.assign(R.defaults('base'), { viewsPerViewer: 2000, adoption: 1, muxCreditUsd: 0 });
  const rb = R.run(F, fp, big);
  const m = rb.rows[5];
  const expectUsd = Math.max(0, m.watchMin - 100000) * 0.0008 + m.storedMin * 0.0024;
  ok('delivery + storage priced at $0.0008 and $0.0024 per minute', near(m.video, expectUsd * fp.usdInr, 1e-9), `${m.video} vs ${expectUsd * fp.usdInr}`);
}

// Moderation: incremental on the shared Sightengine plan, monotonic.
{
  const fp = F.defaults('base');
  let prev = -1, mono = true;
  for (const n of [0, 1, 3, 6, 12, 30]) {
    const r = R.run(F, fp, Object.assign(R.defaults('base'), { reelsPerCreator: n, reelsPerHost: n }));
    const c = r.rows[5].moderationApi;
    if (c < prev - 1e-9) mono = false;
    prev = c;
  }
  ok('moderation cost rises with uploads and is ≥ 0', mono);
  const none = R.run(F, fp, Object.assign(R.defaults('base'), { reelsPerCreator: 0, reelsPerHost: 0 }));
  ok('no uploads → no moderation cost', none.rows.every(x => x.moderationApi === 0 && x.reelOps === 0));
}

// Positive impact never lowers incremental revenue; cannibalization never raises it.
{
  const fp = F.defaults('base'), base = R.defaults('base');
  const lo = R.run(F, fp, zero(base)).summary.sixMonthDRevenue;
  const hi = R.run(F, fp, Object.assign(zero(base), { churnReduction: 0.2 })).summary.sixMonthDRevenue;
  const can = R.run(F, fp, Object.assign(zero(base), { cannibalization: 0.1 })).summary.sixMonthDRevenue;
  ok('churn reduction increases incremental revenue', hi > lo);
  ok('cannibalization reduces revenue', can < lo);
  const be = R.breakEvenChurnReduction(F, fp, base);
  ok('break-even churn reduction found and consistent', be != null && R.run(F, fp, Object.assign({}, base, { churnReduction: be })).summary.sixMonthDOperating >= -1);
}

// Extremes: no NaN anywhere.
{
  let finite = true;
  for (const sc of R.SCENARIOS) {
    for (const over of [{ adoption: 0 }, { adoption: 1, viewsPerViewer: 1000 }, { reelSeconds: 60, frameInterval: 1, modelsPerFrame: 6 }, { creatorShare: 0.3 }, { churnReduction: 0.5, laterConversionUplift: 1 }]) {
      const r = R.run(F, F.defaults(sc), Object.assign(R.defaults(sc), over));
      for (const row of r.rows) for (const c of R.COLUMNS) if (typeof row[c] === 'number' && !Number.isFinite(row[c])) finite = false;
    }
  }
  ok('extreme inputs produce finite numbers', finite);
}

// Exports and secrets.
{
  const csv = R.toCSV(R.run(F, F.defaults('base'), R.defaults('base')));
  const lines = csv.split('\n');
  ok('CSV has a header and 6 months', lines.length === 7 && lines.every(l => l.split(',').length === R.COLUMNS.length));
  const src = readFileSync(new URL('./reels-model.js', import.meta.url), 'utf8');
  ok('model source contains no secrets', !/(sk_live|api_secret=|BEGIN [A-Z ]*PRIVATE KEY|MUX_TOKEN_SECRET=)/.test(src));
  ok('every assumption has a status and source', R.ASSUMPTIONS.every(a => ['verified', 'implemented', 'assumption'].includes(a.status) && (a.status === 'assumption' || a.source.length > 10)));
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
