// Generates the Markdown simulation reports and CSV data from the engine.
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { DEFAULT_SCENARIOS, SEEDS, SCENARIO_KEYS, DEFAULT_PACKAGES, RATE_LADDERS, SOURCES, PARAM_META, CONSTANTS } from '../src/engine/assumptions.js';
import { runScenario, sensitivity } from '../src/engine/runs.js';
import { packageWaterfall, hostInrForDiamonds } from '../src/engine/finance.js';
import { monthlyCsv, assumptionsCsv, comparisonCsv, toCsv } from '../src/engine/export.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, '..', 'docs', 'simulation');
mkdirSync(join(out, 'data'), { recursive: true });

const inrFmt = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 });
const inr = (v) => (v < 0 ? '−₹' : '₹') + inrFmt.format(Math.abs(Math.round(v)));
const inr2 = (v) => (v < 0 ? '−₹' : '₹') + Math.abs(v).toFixed(2);
const n0 = (v) => inrFmt.format(Math.round(v));
const pct = (v, d = 1) => (v * 100).toFixed(d) + '%';
const table = (head, rows) => `| ${head.join(' | ')} |\n|${head.map((_, i) => (i ? '---:' : '---')).join('|')}|\n${rows.map((r) => `| ${r.join(' | ')} |`).join('\n')}\n`;

const res = {};
for (const k of SCENARIO_KEYS) res[k] = runScenario(DEFAULT_SCENARIOS[k], SEEDS[k]);
const sens = {};
for (const k of SCENARIO_KEYS) sens[k] = sensitivity(DEFAULT_SCENARIOS[k], SEEDS[k], 'profitAfterAcquisition');
const S = (k, key) => res[k].summaryStats[key];
const name = (k) => DEFAULT_SCENARIOS[k].name;
const tot = (k, key) => res[k].monthlyMean.reduce((s, m) => s + m[key], 0);
const today = '2026-11-17';
const header = (title) => `# ${title}\n\n- **Generated:** ${today} by \`simulation/scripts/generate-reports.mjs\` from the simulation engine (same code as the dashboard).\n- **Status:** conditional what-if scenarios, **not forecasts**. Demand inputs have no market data behind them.\n- **Runs:** five seeds per scenario (Worst ${SEEDS.worst.join(', ')}; Base ${SEEDS.base.join(', ')}; Best ${SEEDS.best.join(', ')}). Figures are means of the five runs unless stated.\n\n`;

// ---------- CSV ----------
for (const k of SCENARIO_KEYS) writeFileSync(join(out, 'data', `monthly-${k}.csv`), monthlyCsv(res[k].monthlyMean, name(k)));
writeFileSync(join(out, 'data', 'scenario-comparison.csv'), comparisonCsv(SCENARIO_KEYS.map((k) => res[k])));
writeFileSync(join(out, 'data', 'assumptions.csv'), assumptionsCsv(DEFAULT_SCENARIOS));
for (const k of SCENARIO_KEYS) writeFileSync(join(out, 'data', `sensitivity-${k}.csv`), toCsv([['Variable', 'Who controls it', 'Low setting', 'Profit at low', 'High setting', 'Profit at high', 'Swing'], ...sens[k].rows.map((r) => [r.label, r.influence, r.loLabel, r.lo, r.hiLabel, r.hi, r.swing])]));

// ---------- Monthly projections ----------
const MP_ROWS = [
  ['installs', 'Installs', n0], ['registrations', 'Registrations', n0], ['eligible', 'Eligible users', n0], ['activeCustomers', 'Active customers', n0], ['payingCustomers', 'Paying customers', n0], ['newPayers', 'New payers', n0],
  ['freeCardUsers', 'Free Call Card users', n0], ['freeCallsCompleted', 'Free calls completed', n0], ['newPayersFromFreeCall', 'Free-to-paid conversions', n0],
  ['activeHosts', 'Active hosts', n0], ['utilisation', 'Host utilisation', (v) => pct(v)], ['avgRate', 'Avg rate (D/min)', n0],
  ['incomingCalls', 'Incoming paid calls', n0], ['acceptedCalls', 'Accepted calls', n0], ['connectedCalls', 'Connected = completed calls', n0], ['paidMinutes', 'Paid billable minutes', n0], ['freeCallMinutes', 'Free-call minutes', n0],
  ['purchases', 'Top-ups', n0], ['avgTopup', 'Average top-up', inr], ['topupGross', 'Top-up cash (incl. GST)', inr], ['refundGross', 'Refunds', inr], ['chargebackGross', 'Chargebacks', inr],
  ['diamondsPurchased', 'Diamonds purchased', n0], ['diamondsConsumed', 'Diamonds consumed', n0], ['walletDiamonds', 'Unspent purchased Diamonds (end)', n0],
  ['beansEarnedPaid', 'Beans earned, paid calls', n0], ['beansEarnedFree', 'Beans earned, free calls', n0], ['beansWithdrawn', 'Beans withdrawn', n0],
  ['revenue', 'Recognised revenue (ex GST)', inr], ['playFeeExpense', 'Play fee', inr], ['hostPaidExpense', 'Host Beans, paid calls', inr], ['videoPaid', 'Video, paid', inr], ['moderationPaid', 'Moderation bot, paid', inr], ['chargebackLoss', 'Chargeback loss', inr], ['chargebackFees', 'Chargeback fees', inr],
  ['contribution', '**Contribution, paid calls**', inr], ['freeCallCost', 'Free Call Card cost', inr], ['opex', 'Operating expenses', inr], ['preLaunch', 'Pre-launch placeholder', inr], ['operatingProfit', '**Operating profit before acquisition**', inr],
  ['payoutCash', 'Host payouts made', inr], ['customerLiabilityInr', 'Customer wallet liability (end)', inr], ['hostLiabilityInr', 'Host payout liability (end)', inr], ['closingCash', 'Closing cash balance', inr],
];
let mp = header('Dashuri — Six-month monthly projections');
mp += 'Accounting: top-ups are cash, not revenue. Revenue is recognised only when purchased Diamonds are spent in billable calls. "Contribution" covers paid calls only; it is not profit. The full set of 70 monthly lines is in `data/monthly-*.csv`.\n\n';
for (const k of SCENARIO_KEYS) {
  const m = res[k].monthlyMean;
  const flow = new Set(['activeCustomers', 'payingCustomers', 'activeHosts', 'utilisation', 'avgRate', 'avgTopup', 'walletDiamonds', 'customerLiabilityInr', 'hostLiabilityInr', 'closingCash']);
  mp += `## ${name(k)}\n\n` + table(['Metric', 'M1', 'M2', 'M3', 'M4', 'M5', 'M6', 'Total / end'], MP_ROWS.map(([key, l, f]) => [l, ...m.map((x) => f(x[key])), flow.has(key) ? f(m[5][key]) : f(m.reduce((s, x) => s + x[key], 0))])) + '\n';
}
writeFileSync(join(out, 'monthly-projections.md'), mp);

// ---------- Unit economics ----------
let ue = header('Dashuri — Unit economics');
ue += `Founder-confirmed conversion: **16,670 Diamonds spent = 10,000 Beans = ₹50** (₹${hostInrForDiamonds(1).toFixed(7)} per Diamond). Package waterfalls assume the whole pack is spent at one rate, GST at 18% inside the price (principal model, Dashuri remits), Play fee 15% on the GST-exclusive price, Stream HD video ($1.50 per 1,000 participant-minutes, 2 participants), the founder's moderation model (nudity bot for the first 3 minutes of each call: 6 frames/min × 2 streams × $0.0015, **UNVERIFIED** price), 4.5-minute calls, a 5% refund/fraud reserve and ₹88 = US$1.\n\n`;
for (const rate of [1000, 4000, 8000]) {
  ue += `## All packages at ${n0(rate)} Diamonds/min\n\n` + table(['Package', 'Price', 'Diamonds', 'Minutes', '₹/min to customer', 'GST', 'Play fee', 'Host', 'Video', 'Moderation', 'Reserve', 'Contribution', '%'], DEFAULT_PACKAGES.map((p) => {
    const w = packageWaterfall(p, { rate });
    return [p.name, inr(p.price), n0(p.diamonds), w.minutes.toFixed(1), inr2(w.pricePerMinute), inr2(w.gst), inr2(w.fee), inr2(w.host), inr2(w.video), inr2(w.moderation), inr2(w.reserve), `**${inr2(w.contribution)}**`, pct(w.contributionPct)];
  })) + '\n';
}
const p1199 = DEFAULT_PACKAGES[3];
const alt = [
  ['Base: principal, Dashuri remits GST, fee 15% on ex-GST price', {}],
  ['Play fee charged on GST-inclusive price', { feeBase: 'gross' }],
  ['Play fee 30% (revenue above US$1M a year)', { playFeeRate: 0.3 }],
  ['Agent model (hypothetical; GST on margin only)', { gstMode: 'agent' }],
  ['Alternative billing at 11% (NOT assumed available; gateway fee excluded)', { playFeeRate: 0.11 }],
  ['Moderation bot price ×0 (on-device model)', { moderationUsdPerFrame: 0 }],
  ['Full HD video ($3.00)', { videoUsdPer1000: 3 }],
];
ue += `## ₹1,199 pack at 4,000 D/min under alternative tax and fee treatments\n\n` + table(['Treatment', 'GST', 'Play fee', 'Host', 'Contribution', '% of price'], alt.map(([l, o]) => {
  const w = packageWaterfall(p1199, { rate: 4000, ...o });
  return [l, inr2(w.gst), inr2(w.fee), inr2(w.host), `**${inr2(w.contribution)}**`, pct(w.contributionPct)];
})) + '\n';
ue += `**Change from the audit (v0.2):** the audit's ₹1,199 example used a proposed 1 Diamond = 1 Bean ratio (host ₹270, contribution ₹533.97). The founder's confirmed ratio of 16,670 D = 10,000 Beans makes the host share ₹${hostInrForDiamonds(54000).toFixed(2)} and contribution ₹${packageWaterfall(p1199, { rate: 4000 }).contribution.toFixed(2)}.\n\n`;
ue += `## Host earnings by rate\n\n` + table(['Rate (D/min)', 'Customer pays /min (₹1,199 pack)', 'Host earns /min', 'Host earns per talk-hour', 'Host share of price'], [500, 1000, 2000, 4000, 6000, 8000, 10000].map((r) => {
  const ppm = r * (p1199.price / p1199.diamonds);
  const h = hostInrForDiamonds(r);
  return [n0(r), inr2(ppm), inr2(h), inr(h * 60), pct(h / ppm)];
})) + '\nHost earnings per talk-hour are before idle time. At Base-case utilisation (~11%), an online host earns roughly a tenth of these figures per online hour.\n\n';
const rate = { worst: res.worst.monthlyMean[5].avgRate, base: res.base.monthlyMean[5].avgRate, best: res.best.monthlyMean[5].avgRate };
ue += `## Per-minute, per-call and per-customer (simulated, Month 6)\n\n` + table(['Scenario', 'Avg rate', 'Revenue / paid min', 'Contribution / paid min', 'Contribution / call', 'Contribution / payer (6 mo)', 'Free Call Card cost / converted payer'], SCENARIO_KEYS.map((k) => {
  const m6 = res[k].monthlyMean[5];
  const cpm = m6.contribution / Math.max(1, m6.paidMinutes);
  return [name(k), n0(rate[k]), inr2(m6.revenue / Math.max(1, m6.paidMinutes)), inr2(cpm), inr2(cpm * DEFAULT_SCENARIOS[k].avgPaidCallMin), inr(S(k, 'contributionPerPayer').mean), inr(tot(k, 'freeCallCost') / Math.max(1, tot(k, 'newPayersFromFreeCall')))];
})) + '\n';
ue += `## Free Call Card economics\n\nCost per completed free call = ₹10 host compensation + video + 1 minute of bot moderation. Customers who never convert still cost ₹10. The cost per converted payer = cost per completed call ÷ free-to-paid rate.\n\n` + table(['Free-to-paid rate', '3%', '6%', '10%', '15%', '20%'], [['Host cost per converted payer', ...[0.03, 0.06, 0.1, 0.15, 0.2].map((c) => inr(10 / c))]]) + '\n';
writeFileSync(join(out, 'unit-economics.md'), ue);

// ---------- Sensitivity ----------
let se = header('Dashuri — Sensitivity and break-even analysis');
se += 'One input changes at a time; everything else stays at the scenario setting. Metric: six-month profit after acquisition (equal to operating profit before acquisition when CAC is ₹0, the default). Ranked by swing.\n\n';
for (const k of SCENARIO_KEYS) {
  se += `## ${name(k)} (scenario result ${inr(sens[k].base)})\n\n` + table(['Variable', 'Who controls it', 'Low setting', 'Profit', 'High setting', 'Profit', 'Swing'], sens[k].rows.map((r) => [r.label, r.influence, r.loLabel, inr(r.lo), r.hiLabel, inr(r.hi), inr(r.swing)])) + '\n';
}
se += '## Break-even (from Month 6 of each run)\n\nFixed monthly cost = Free Call Card cost + operating expenses in Month 6. Break-even paid minutes = fixed cost ÷ contribution per paid minute.\n\n';
se += table(['Scenario', 'Contribution / paid min', 'Fixed monthly cost', 'Break-even paid minutes / month', 'Actual M6 paid minutes', 'Break-even paying customers', 'Break-even paid calls / day', 'Break-even monthly revenue', 'Runs reaching monthly break-even'], SCENARIO_KEYS.map((k) => {
  const runs = res[k].runs;
  const avg = (f) => runs.reduce((s, r) => s + f(r), 0) / runs.length;
  const be = (f) => avg((r) => (r.summary.breakEven.exists ? f(r.summary.breakEven) : NaN));
  return [name(k), inr2(avg((r) => r.summary.contributionPerPaidMinute)), inr(avg((r) => r.summary.breakEvenFixedMonthly)), n0(be((b) => b.minutes)), n0(avg((r) => r.months[5].paidMinutes)), n0(be((b) => b.payers)), be((b) => b.dailyCalls).toFixed(1), inr(be((b) => b.revenue)), `${res[k].reachesBreakEven}/5`];
})) + '\n';
se += `## Break-even acquisition cost\n\nMaximum average cost per install at which six-month operating profit would be zero (operating profit before acquisition ÷ installs):\n\n` + table(['Scenario', 'Break-even CAC per install', 'Range across runs'], SCENARIO_KEYS.map((k) => [name(k), inr2(S(k, 'breakEvenCacPerInstall').mean), `${inr2(S(k, 'breakEvenCacPerInstall').min)} to ${inr2(S(k, 'breakEvenCacPerInstall').max)}`])) + '\nNo CAC data exists for this category in India; these are thresholds to compare against real campaign costs, not estimates of CAC.\n';
writeFileSync(join(out, 'sensitivity-analysis.md'), se);

// ---------- Cash flow ----------
let cf = header('Dashuri — Cash flow and working capital');
cf += `## Settlement assumptions\n\n- Google Play pays a month's sales from **day ${DEFAULT_SCENARIOS.base.settlementDay} of the next month** ([official payout schedule](https://support.google.com/paymentscenter/answer/7159355), verified 2026-11-17), plus **${DEFAULT_SCENARIOS.base.bankTransitDays} days** bank transit (official: EFT 2–3, wire 5–7 business days). First settlement lands on day ${30 + DEFAULT_SCENARIOS.base.settlementDay + DEFAULT_SCENARIOS.base.bankTransitDays}.\n- Settlement = top-ups − refunds − Play fee − chargebacks (and − GST if Google remits).\n- GST paid by Dashuri on the 20th of the next month on that month's top-ups (principal, Dashuri remits; switchable). **Who remits GST on Play sales is unresolved (CA).**\n- Hosts: Beans held ${CONSTANTS.holdDays} days, weekly payouts, ₹${CONSTANTS.minWithdrawInr} minimum, ₹${DEFAULT_SCENARIOS.base.payoutFeeInr} transfer fee (**UNVERIFIED**; no provider has accepted Dashuri).\n- Chargebacks land 15–60 days after purchase and are deducted from the next settlement with a ₹${n0(DEFAULT_SCENARIOS.base.chargebackFeeInr)} bank fee each (**UNVERIFIED**, third-party reports of US$15–25 for orders after 3 Aug 2026).\n- Starting cash ₹0, so the lowest balance is the founder funding required. Pre-launch placeholder ₹${n0(DEFAULT_SCENARIOS.base.preLaunchInr)} paid on day 1.\n\n`;
cf += '## Peak cash requirement and reserve\n\n' + table(['Scenario', 'Peak requirement (mean)', 'Lowest run', 'Highest run', 'Reserve (worst run +10%)', 'Cash at day 180', 'Google receivable at day 180', 'Customer wallet liability M6', 'Host liability M6'], SCENARIO_KEYS.map((k) => [name(k), inr(S(k, 'peakFunding').mean), inr(S(k, 'peakFunding').min), inr(S(k, 'peakFunding').max), inr(S(k, 'peakFunding').max * 1.1), inr(S(k, 'closingCash').mean), inr(S(k, 'googleReceivable').mean), inr(S(k, 'm6WalletLiability').mean), inr(S(k, 'm6HostLiability').mean)])) + '\n';
for (const k of SCENARIO_KEYS) {
  const m = res[k].monthlyMean;
  cf += `## ${name(k)}: monthly cash\n\n` + table(['₹', 'M1', 'M2', 'M3', 'M4', 'M5', 'M6'], [
    ['Google settlements in', ...m.map((x) => inr(x.cashIn))], ['Host payouts + fees out', ...m.map((x) => inr(-x.cashOutHosts))], ['GST out', ...m.map((x) => inr(-x.cashOutGst))], ['Operating out', ...m.map((x) => inr(-x.cashOutOpex))], ['Pre-launch out', ...m.map((x) => inr(-x.cashOutPreLaunch))], ['Net movement', ...m.map((x) => inr(x.netCash))], ['**Closing balance**', ...m.map((x) => `**${inr(x.closingCash)}**`)], ['Lowest balance in month', ...m.map((x) => inr(x.minCashInMonth))],
    ['*Operating profit (accrual)*', ...m.map((x) => `*${inr(x.operatingProfit)}*`)],
  ]) + '\n';
}
cf += 'Cash lags profit because Google pays about 45–55 days after a purchase while GST and hosts are paid sooner. A profitable month can still leave the bank balance falling.\n';
writeFileSync(join(out, 'cash-flow-working-capital.md'), cf);

// ---------- Main report ----------
const m6 = (k, key) => res[k].monthlyMean[5][key];
const peakAll = Math.max(...SCENARIO_KEYS.map((k) => S(k, 'peakFunding').max));
const firstProfit = (k) => {
  const ms = res[k].runs.map((r) => r.summary.firstProfitMonth).filter(Boolean);
  if (!ms.length) return 'Not within six months (0/5 runs)';
  const a = Math.min(...ms);
  const b = Math.max(...ms);
  return `${a === b ? `Month ${a}` : `Month ${a} to ${b}`} (${ms.length}/5 runs)`;
};
let mr = header('Dashuri — Six-month financial simulation report');
mr += `## 1. Bottom line\n\n`;
mr += table(['', ...SCENARIO_KEYS.map(name)], [
  ['Six-month top-ups (cash in wallets, incl. GST)', ...SCENARIO_KEYS.map((k) => inr(S(k, 'topups').mean))],
  ['Recognised revenue (ex GST)', ...SCENARIO_KEYS.map((k) => inr(S(k, 'revenue').mean))],
  ['Contribution, paid calls', ...SCENARIO_KEYS.map((k) => inr(S(k, 'contribution').mean))],
  ['**Six-month operating profit (before acquisition)**', ...SCENARIO_KEYS.map((k) => `**${inr(S(k, 'operatingProfit').mean)}**`)],
  ['Range across 5 runs', ...SCENARIO_KEYS.map((k) => `${inr(S(k, 'operatingProfit').min)} to ${inr(S(k, 'operatingProfit').max)}`)],
  ['Month 6 operating profit', ...SCENARIO_KEYS.map((k) => inr(m6(k, 'operatingProfit')))],
  ['First month with operating profit', ...SCENARIO_KEYS.map(firstProfit)],
  ['Peak cash requirement (mean / worst run)', ...SCENARIO_KEYS.map((k) => `${inr(S(k, 'peakFunding').mean)} / ${inr(S(k, 'peakFunding').max)}`)],
  ['Break-even CAC per install', ...SCENARIO_KEYS.map((k) => inr2(S(k, 'breakEvenCacPerInstall').mean))],
  ['Month 6 paying customers', ...SCENARIO_KEYS.map((k) => n0(S(k, 'm6PayingCustomers').mean))],
  ['Month 6 active hosts / utilisation', ...SCENARIO_KEYS.map((k) => `${n0(m6(k, 'activeHosts'))} / ${pct(m6(k, 'utilisation'))}`)],
  ['Month 6 median host earnings', ...SCENARIO_KEYS.map((k) => inr(S(k, 'm6MedianHostEarning').mean))],
]) + '\n';
const fcBase = tot('base', 'freeCallHostCost');
const hpBase = tot('base', 'hostPaidExpense');
mr += `**Which scenario is viable?** Only the **Best case** produces a six-month operating profit (${inr(S('best', 'operatingProfit').mean)}) with room to pay for acquisition (up to ${inr2(S('best', 'breakEvenCacPerInstall').mean)} per install). The **Base case** turns monthly-profitable during the period (first profitable month: ${firstProfit('base')}) but ends six months at ${inr(S('base', 'operatingProfit').mean)}, mostly the ₹1,00,000 pre-launch placeholder, and its Month 6 profit (${inr(m6('base', 'operatingProfit'))}) cannot fund paid acquisition. The **Worst case** never breaks even and loses ${inr(-S('worst', 'operatingProfit').mean)}.\n\n`;
mr += `**Peak capital requirement:** ${inr(peakAll)} in the worst single run of any scenario (plus 10% buffer: ${inr(peakAll * 1.1)}). This excludes any marketing budget, which the founder manages separately, and includes the ₹1,00,000 pre-launch placeholder.\n\n`;
mr += `## 2. What drives the result\n\n`;
mr += `1. **Demand is the business.** In every scenario hosts are idle most of the time (Month 6 utilisation ${SCENARIO_KEYS.map((k) => `${name(k)} ${pct(m6(k, 'utilisation'))}`).join(', ')}). Supply is not the constraint; paying customers are. Apart from any paid acquisition cost (the largest swing of all), the top Base-case drivers are package mix (average top-up), moderation cost, free-to-paid conversion, top-ups per payer and repeat purchases.\n`;
mr += `2. **Unit margin is high.** At the confirmed 16,670 D = 10,000 Beans = ₹50, hosts receive about 13.5% of what customers pay. A fully spent ₹1,199 pack at 4,000 D/min contributes ${inr2(packageWaterfall(p1199, { rate: 4000 }).contribution)} (${pct(packageWaterfall(p1199, { rate: 4000 }).contributionPct)}). Contribution per paid minute in Month 6: ${SCENARIO_KEYS.map((k) => `${name(k)} ${inr2(S(k, 'contributionPerPaidMinute').mean)}`).join(', ')}.\n`;
mr += `3. **The Free Call Card is the largest host cost in the Base case.** Six-month free-call host compensation ${inr(fcBase)} vs paid-call host Beans ${inr(hpBase)}. Each converted payer costs ${inr(tot('base', 'freeCallCost') / Math.max(1, tot('base', 'newPayersFromFreeCall')))} in free calls at a 6% conversion rate. Each completed free call costs about ${inr2(tot('base', 'freeCallCost') / Math.max(1, tot('base', 'freeCallsCompleted')))}; against six-month contribution of ${inr(S('base', 'contributionPerPayer').mean)} per payer, the card only pays back if free-to-paid conversion is above about ${pct((tot('base', 'freeCallCost') / Math.max(1, tot('base', 'freeCallsCompleted'))) / S('base', 'contributionPerPayer').mean)} (before operating costs).\n`;
mr += `4. **Host earnings are low.** Median Month 6 earnings per active host: ${SCENARIO_KEYS.map((k) => `${name(k)} ${inr(S(k, 'm6MedianHostEarning').mean)}`).join(', ')}. New hosts start at ladder maximums of 500–2,000 D/min, which pay ₹1.50–₹6 per talking minute. Third-party reports put competitor hosts at about 10,000 Beans per US$1 (~₹88); Dashuri's ₹50 per 10,000 Beans pays roughly 43% less per Bean. This is a supply-retention risk the model does not capture (host churn here does not react to earnings).\n`;
mr += `5. **Moderation is a material cost.** The founder's 3-minute nudity bot (6 frames/min on both streams) costs about ₹${(Math.min(4.5, 3) * 6 * 2 * 0.0015 * 88).toFixed(2)} per Base-case call at an UNVERIFIED $0.0015 per frame, plus ₹${n0(DEFAULT_SCENARIOS.base.safetyOpsMonthlyInr)}/month on-call safety cover (hypothesis). Moderation cost is the third-largest sensitivity driver in the Base case.\n`;
mr += `6. **Video is negligible at this scale.** Stream's $100 monthly free usage covers the Worst and Base cases entirely.\n`;
mr += `7. **Cash lags profit.** Google pays 45–55 days after purchase; GST and hosts are paid sooner. Month 6 sales (${inr(S('base', 'googleReceivable').mean)} in Base) are still owed by Google at day 180.\n\n`;
mr += `## 3. Liabilities that are not Dashuri's money (Month 6, mean)\n\n` + table(['Scenario', 'Unspent purchased Diamonds (customer liability, incl. GST)', 'Earned Beans not yet paid (host liability)'], SCENARIO_KEYS.map((k) => [name(k), inr(S(k, 'm6WalletLiability').mean), inr(S(k, 'm6HostLiability').mean)])) + '\n';
mr += `## 4. Largest risks\n\n1. **No payout provider has accepted Dashuri.** Without one (or a lawyer-approved bank-transfer arrangement, modelled here only as a hypothetical ₹8/transfer), hosts cannot be paid.\n2. **Publishing under the BK Enterprises Play account ties Route to Dashuri's policy risk.** Google can suspend a developer account for repeated or severe policy violations, which would affect every app on it, including Route. Chamet was removed from Play in 2023 under the UGC policy. Consider a separate developer account and legal entity for Dashuri (needs founder decision and review of Play's account rules).\n3. **Moderation model compliance.** A bot only in the first three minutes, then reports, has not been shown to satisfy Google Play's Sexual Content/UGC policies or the IT Rules (2-hour takedown of intimate images on complaint after the 2026 amendment, reported). Explicit content after minute three is the exact risk that removed Chamet.\n4. **Demand assumptions have no data.** Installs, conversion, retention and top-up mix drive the result and are all hypotheses.\n5. **Host supply at these earnings.** Low earnings per online hour may not keep hosts online; the model holds host numbers as an input.\n6. **GST and Play-fee treatment.** Switching to the Play fee on the GST-inclusive price or a 30% fee cuts contribution noticeably (see unit economics).\n7. **Chargebacks after 3 Aug 2026 are reportedly borne by developers**, with bank fees per case (UNVERIFIED). Fraud through colluding accounts converts directly into cash losses.\n\n`;
mr += `## 5. Most important assumptions\n\n` + table(['Assumption', 'Worst', 'Base', 'Best', 'Evidence'], [
  ['Installs in Month 1 / growth', ...SCENARIO_KEYS.map((k) => `${n0(DEFAULT_SCENARIOS[k].installsM1)} / ${pct(DEFAULT_SCENARIOS[k].installGrowth, 0)}`), 'Hypothesis'],
  ['Free-to-paid conversion', ...SCENARIO_KEYS.map((k) => pct(DEFAULT_SCENARIOS[k].freeToPaidRate)), 'Hypothesis'],
  ['Repeat purchase rate per month', ...SCENARIO_KEYS.map((k) => pct(DEFAULT_SCENARIOS[k].payerRetention, 0)), 'Hypothesis'],
  ['Top-ups per active payer per month', ...SCENARIO_KEYS.map((k) => String(DEFAULT_SCENARIOS[k].purchasesPerPayer)), 'Hypothesis'],
  ['Package mix (Starter→Premium)', ...SCENARIO_KEYS.map((k) => DEFAULT_SCENARIOS[k].packageMix.map((x) => Math.round(x * 100)).join('/')), 'Hypothesis'],
  ['Average paid call', ...SCENARIO_KEYS.map((k) => `${DEFAULT_SCENARIOS[k].avgPaidCallMin} min`), 'Hypothesis'],
  ['Active hosts M1→M6', ...SCENARIO_KEYS.map((k) => `${DEFAULT_SCENARIOS[k].hostsByMonth[0]}→${DEFAULT_SCENARIOS[k].hostsByMonth[5]}`), 'Capacity input (founder recruits)'],
  ['Chargebacks incl. fraud', ...SCENARIO_KEYS.map((k) => pct(DEFAULT_SCENARIOS[k].chargebackRate)), 'Hypothesis'],
  ['Rate ladder', ...SCENARIO_KEYS.map((k) => RATE_LADDERS[DEFAULT_SCENARIOS[k].ladder].name), 'Proposal, not approved'],
  ['Play fee / GST', '15% / principal', '15% / principal', '15% / principal', 'Verified rate / CA review'],
  ['Pre-launch professional costs', '₹1,00,000', '₹1,00,000', '₹1,00,000', 'Placeholder'],
]) + '\nAll inputs with evidence status: `data/assumptions.csv` and the dashboard\'s *Assumptions & method* page.\n\n';
mr += `## 6. Requires professional review\n\n- **CA:** GST principal vs agent; who remits GST on Play sales; Play fee base; GST timing on advances; TDS section for host payouts; accounting for Diamond and Bean liabilities.\n- **Lawyer:** Bean payout structure (PPI / payment aggregator); IT Act s.67/67A and s.79; sufficiency of the 3-minute moderation model under the IT Rules 2026 amendment; DPDP; social-security levy applicability; host agreement.\n- **Payments:** written acceptance from a payout provider.\n- **Google Play:** whether Dashuri is in scope of the random-chat minor-blocking rules (Free Call Card), and the risk to the BK Enterprises account.\n\n`;
mr += `## 7. Files\n\n- \`monthly-projections.md\`: month-by-month tables for all three scenarios\n- \`unit-economics.md\`: package waterfalls, tax/fee alternatives, host earnings, Free Call Card\n- \`sensitivity-analysis.md\`: tornado tables and break-even\n- \`cash-flow-working-capital.md\`: settlement, payouts, peak funding\n- \`test-results.md\`: automated test output\n- \`data/*.csv\`: monthly projections, comparison, assumptions, sensitivity\n- Interactive dashboard: \`simulation/dist/dashuri-simulation.html\`\n`;
writeFileSync(join(out, 'six-month-simulation-report.md'), mr);

console.log('Reports written to docs/simulation/.');
for (const k of SCENARIO_KEYS) console.log(k, 'opProfit', inr(S(k, 'operatingProfit').mean), 'peak', inr(S(k, 'peakFunding').mean), 'peakMax', inr(S(k, 'peakFunding').max), 'first', firstProfit(k), 'beCAC', inr2(S(k, 'breakEvenCacPerInstall').mean));
console.log('free-call host cost base', inr(fcBase), 'paid host', inr(hpBase), 'peakAll', inr(peakAll));
