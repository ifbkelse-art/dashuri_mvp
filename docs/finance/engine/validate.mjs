// Validation and audit of the financial engine against the implementation.
// Run: node docs/finance/engine/validate.mjs   (read-only; touches no app files)
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const require = createRequire(import.meta.url);
const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '../../..');
const M = require('./dashuri-model.js');

let pass = 0, fail = 0;
const results = [];
function check(name, ok, detail) {
  results.push({ name, ok: !!ok, detail: detail || '' });
  if (ok) pass++; else fail++;
  console.log((ok ? 'PASS ' : 'FAIL ') + name + (detail ? ' — ' + detail : ''));
}
const close = (a, b, tol = 1e-6) => Math.abs(a - b) <= tol * Math.max(1, Math.abs(a), Math.abs(b));

// 1. Diamond packages vs migration seed
const sql = readFileSync(path.join(repo, 'supabase/migrations/20261121000100_mvp_foundation.sql'), 'utf8');
const seed = [...sql.matchAll(/\('(diamonds_\d+)',\s*(\d+),\s*true,\s*\d+,\s*(\d+),\s*'(\w+)'/g)].map(m => ({ id: m[1], diamonds: +m[2], pricePaise: +m[3], label: m[4] }));
check('1. Diamond packages match the migration seed (6 packages, Diamonds, price, label)',
  seed.length === 6 && seed.every((s, i) => s.id === M.PACKAGES[i].id && s.diamonds === M.PACKAGES[i].diamonds && s.pricePaise === M.PACKAGES[i].pricePaise && s.label === M.PACKAGES[i].label),
  seed.map(s => `${s.label} ${s.diamonds}D ₹${s.pricePaise / 100}`).join(', '));

// 2. Rule set vs rules.go and the rule_sets seed
const go = readFileSync(path.join(repo, 'backend/internal/modules/economy/rules.go'), 'utf8');
const g = k => { const m = go.match(new RegExp(k + ':\\s*([0-9_]+)')); return m ? +m[1].replace(/_/g, '') : NaN; };
const ruleSql = readFileSync(path.join(repo, 'supabase/migrations/20261117000300_economy_and_ledger.sql'), 'utf8');
check('2a. Bean conversion 10,000 Beans per 16,670 Diamonds (rules.go + seed)', g('BeansNumerator') === M.RULES.beansNumerator && g('DiamondsDenominator') === M.RULES.diamondsDenominator && /'beans', 10000, 'diamonds', 16670/.test(ruleSql));
check('2b. 1 Bean = ½ paisa', g('PaisePerBeanNumerator') === 1 && g('PaisePerBeanDenominator') === 2);
check('2c. Rate range 500–10,000 D/min, no level ladder', g('MinRatePerMinute') === 500 && g('MaxRatePerMinute') === 10000 && /LevelRateCaps:\s*nil/.test(go) && M.RULES.levelRateCaps === null);
check('2d. Free call: 60 s, ₹10 host comp, 20/host/day', g('FreeCallSeconds') === 60 && g('FreeCallHostCompPaise') === 1000 && g('FreeCallMaxPerHostPerDay') === 20);
check('2e. ₹500 minimum withdrawal, 60 s minimum start balance', g('MinWithdrawalPaise') === 50000 && g('MinStartBalanceSeconds') === 60);
check('2f. Interruption threshold 10 s; spend order promotional first', /InterruptionThreshold:\s*10 \* time.Second/.test(go) && /SpendOrder:\s*"promotional_first"/.test(go));

// 3. Settlement formula vs Go implementation and its integration test
const d = M.exact.diamondsForSeconds(4000, 65), b = M.exact.beansForDiamonds(d);
check('3. Settlement: 65 s at 4,000 D/min → 4,333 Diamonds, 2,599 Beans (calls integration test)', d === 4333 && b === 2599, `${d} D, ${b} Beans, host ₹${M.exact.paiseForBeans(b) / 100}`);
check('3b. Free-call compensation ₹10 = 2,000 Beans', M.exact.beansForPaise(1000) === 2000);
check('3c. Refund reverses only unspent purchased Diamonds (ReversalAmount)', M.exact.reversalAmount(54000, 20000, 0, 0) === 20000 && M.exact.reversalAmount(54000, 60000, 1000, 5000) === 54000 && M.exact.reversalAmount(54000, 3000, 0, 4000) === 0);
check('3d. Moderation frames: every 20 s per participant in first 180 s → 9 per participant max', M.exact.framesPerParticipant(300) === 9 && M.exact.framesPerParticipant(60) === 3);
check('3e. Aggregate host rate equals the exact rule within rounding', close(M.HOST_RUPEES_PER_DIAMOND * 4333, 2599 * 0.005, 1e-3));

// Run all scenarios
const runs = Object.fromEntries(M.SCENARIOS.map(s => [s, M.run(M.defaults(s))]));
const sum = (ms, k) => ms.reduce((s, r) => s + r[k], 0);

for (const [name, r] of Object.entries(runs)) {
  const ms = r.months, p = r.params;
  // 5. Unspent Diamonds are not revenue
  const purchasedNet = sum(ms, 'diamondsPurchased') * (1 - p.refundRate);
  const consumedPurchased = sum(ms, 'diamondsConsumedPurchased');
  check(`5. [${name}] Diamond conservation: bought − refunded − used = unspent`, close(purchasedNet - consumedPurchased, ms[5].unspentDiamonds, 1e-6));
  check(`5b. [${name}] Revenue = used purchased Diamonds × ex-GST ₹/Diamond (unspent excluded)`, close(sum(ms, 'revenueRecognized'), consumedPurchased * r.unit.exGstPerDiamond, 1e-9) && sum(ms, 'revenueRecognized') <= sum(ms, 'netSalesExGst') + 1e-6);
  // 6. Pending host earnings are not profit
  check(`6. [${name}] Host earnings are expensed; Bean liability = earned − paid`, close(sum(ms, 'hostEarnings') - sum(ms, 'hostPayouts'), ms[5].beanLiability) && ms.every(m => m.directCosts >= m.hostEarningsPaid - m.beanClawback - 1e-6));
  // 8. Payouts disabled
  check(`8. [${name}] Payouts off: no host cash paid in any month`, ms.every(m => m.hostPayouts === 0) && p.payoutsEnabled === 0);
  // 9. Infrastructure never silently zero
  check(`9. [${name}] Infrastructure and fixed costs are non-zero every month`, ms.every(m => m.infraCloud > 0 && m.infraVariable > 0 && m.fixedOps > 0 && m.smsCost > 0));
  // 10. No double counting
  check(`10. [${name}] Expense total = direct + other variable + fixed + marketing + one-time`, ms.every(m => close(m.totalExpenses, m.directCosts + m.otherVariable + m.fixedCosts + m.marketing + m.oneTime)));
  check(`10b. [${name}] Operating profit = revenue − total expenses`, ms.every(m => close(m.operatingProfit, m.revenueRecognized - m.totalExpenses)));
  check(`10c. [${name}] Cash identity: closing = start + Σ net cash flow`, close(ms[5].closingCash, p.startingCash + sum(ms, 'netCashFlow')));
  check(`10d. [${name}] Purchases counted once (gross = Σ package gross)`, ms.every(m => close(m.grossPurchaseValue, m.grossByPackage.reduce((s, x) => s + x, 0))));
  check(`10f. [${name}] Play fee: deducted = expensed (matched to use) + deferred`, close(sum(ms, 'playFee'), sum(ms, 'playFeeExpense') + ms[5].deferredPlayFee));
  check(`10e. [${name}] GST excluded from revenue (GST ÷ net sales = 18/118)`, ms.every(m => close(m.gstOnSales / (m.grossPurchaseValue - m.refunds), p.gstRate / (1 + p.gstRate))));
}

// 7. Cashfree not active
const src = readFileSync(path.join(here, 'dashuri-model.js'), 'utf8');
check('7. Cashfree is not a revenue rail in the model (flag false, no Cashfree revenue line)', M.RULES.cashfreeEnabled === false && !/cashfreeRevenue|rail:\s*'cashfree'/.test(src));

// 11–12. Extreme inputs
const ext = [
  { organicNewM1: 0, marketingBudget: 0, referralRate: 0 },
  { organicNewM1: 1e6, organicGrowth: 1 },
  { convFreeCall: 0, convOther: 0, convLater: 0 },
  { callsPerPayer: 0 },
  { callsPerPayer: 60, avgCallMinutes: 60 },
  { payerChurn: 0.95, hostChurn: 0.9 },
  { hostsStart: 1, hostApplications: 0 },
  { cac: 5, marketingBudget: 1000000 },
  { playFee: 0.4, playFeeOnGross: 1, refundRate: 0.3, chargebackRate: 0.3 },
  { payoutsEnabled: 1, payoutStartMonth: 1 },
  { spikeMonth: 3, spikeMultiplier: 20 },
  { purchaseValueMultiplier: 4 }, { purchaseValueMultiplier: 0.3 },
  { priceMultiplier: 2, diamondsMultiplier: 0.5, bulkBonusCut: 1 },
  { promoBonusPct: 0.5, promoChurnEffect: 0.3, referralRate: 2, referralPromoDiamonds: 50000 }
];
const finite = o => Object.values(o).every(v => typeof v !== 'number' || isFinite(v));
let extOk = true, extDetail = [];
for (const e of ext) for (const s of M.SCENARIOS) {
  const r = M.run(Object.assign(M.defaults(s), e));
  const ok = r.months.every(m => finite(m)) && isFinite(r.cumOperatingProfit) && isFinite(r.minCapital) && r.months.every(m => m.paidMinutes >= -1e-9 && m.unspentDiamonds >= -1e-6);
  if (!ok) { extOk = false; extDetail.push(JSON.stringify(e) + ' ' + s); }
}
check('11. Extreme inputs: every output finite, no negative minutes or Diamonds (15 cases × 3 scenarios)', extOk, extDetail.join('; '));
const zero = M.run(Object.assign(M.defaults('base'), { callsPerPayer: 0 }));
check('12. Buy-but-never-use: revenue 0, all purchases held as liability', sum(zero.months, 'revenueRecognized') === 0 && zero.months[5].diamondLiability > 0);
const po = M.run(Object.assign(M.defaults('base'), { payoutsEnabled: 1, payoutStartMonth: 1 }));
check('13. Payouts switched on reduce cash and the Bean liability by the same amount', close(sum(po.months, 'hostPayouts'), runs.base.months[5].beanLiability - po.months[5].beanLiability) && po.months[5].closingCash < runs.base.months[5].closingCash);

// 14. Exports
const csv = M.toCSV(M.SCENARIOS.map(s => [M.SCENARIO_LABEL[s], runs[s]]));
const lines = csv.trim().split('\n');
const cols = l => { let n = 1, q = false; for (const ch of l) { if (ch === '"') q = !q; else if (ch === ',' && !q) n++; } return n; };
check('14. CSV: header + 18 rows (3 scenarios × 6 months), equal column counts', lines.length === 19 && new Set(lines.map(cols)).size === 1, `${lines.length} lines, ${cols(lines[0])} columns`);
const json = JSON.stringify(M.assumptionsDocument(Object.fromEntries(M.SCENARIOS.map(s => [s, M.defaults(s)])), '2026-11-22'));
const parsed = JSON.parse(json);
check('14b. Assumptions JSON parses; every assumption has source, status, confidence', parsed.assumptions.length > 60 && parsed.assumptions.every(x => x.status && x.confidence && 'source' in x));

// 17. No secrets in the deliverables directory
const secretRe = /(sk_live|sk_test|AIza[0-9A-Za-z_-]{20,}|-----BEGIN|service_role|eyJhbGciOi|STREAM_API_SECRET=|password=)/;
check('17. Engine source contains no keys, tokens or passwords', !secretRe.test(src));

console.log(`\n${pass} passed, ${fail} failed`);
if (process.argv.includes('--json')) console.log(JSON.stringify(results));
process.exit(fail ? 1 : 0);
