// Dashuri simulation dashboard. All numbers come from the engine at runtime.
import { DEFAULT_SCENARIOS, SEEDS, SCENARIO_KEYS, PARAM_META, SOURCES, RATE_LADDERS, DEFAULT_PACKAGES, DEFAULT_XP_THRESHOLDS, CONSTANTS, STATUS, cloneScenario } from '../engine/assumptions.js';
import { runScenario, sensitivity } from '../engine/runs.js';
import { packageWaterfall, breakEven, hostInrForDiamonds } from '../engine/finance.js';
import { monthlyCsv, assumptionsCsv, comparisonCsv } from '../engine/export.js';
import { lineChart, barChart, tornadoChart, histogram } from './charts.js';
import { renderMarkdown } from './markdown.js';

const REPORT_MD = window.__DASHURI_REPORT__ || '';
const BUILD_INFO = window.__DASHURI_BUILD__ || {};

// ---------- formatting ----------
const inrFmt = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 });
const inr = (v) => (Number.isFinite(v) ? (v < 0 ? '−₹' : '₹') + inrFmt.format(Math.abs(Math.round(v))) : '—');
const inrShort = (v) => {
  if (!Number.isFinite(v)) return '—';
  const a = Math.abs(v);
  const s = v < 0 ? '−₹' : '₹';
  if (a >= 1e7) return s + (a / 1e7).toFixed(2) + ' Cr';
  if (a >= 1e5) return s + (a / 1e5).toFixed(2) + ' L';
  if (a >= 1e3) return s + (a / 1e3).toFixed(1) + 'k';
  return s + Math.round(a);
};
const num = (v, d = 0) => (Number.isFinite(v) ? new Intl.NumberFormat('en-IN', { maximumFractionDigits: d, minimumFractionDigits: d }).format(v) : '—');
const numShort = (v) => {
  const a = Math.abs(v);
  if (a >= 1e7) return (v / 1e7).toFixed(1) + 'Cr';
  if (a >= 1e5) return (v / 1e5).toFixed(1) + 'L';
  if (a >= 1e3) return (v / 1e3).toFixed(1) + 'k';
  return String(Math.round(v));
};
const pct = (v, d = 1) => (Number.isFinite(v) ? (v * 100).toFixed(d) + '%' : '—');
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const color = (k) => getComputedStyle(document.documentElement).getPropertyValue(`--s-${k}`).trim();
const tok = (k) => getComputedStyle(document.documentElement).getPropertyValue(`--${k}`).trim();
const MONTH_LABELS = ['M1', 'M2', 'M3', 'M4', 'M5', 'M6'];

// ---------- state ----------
const state = {
  params: Object.fromEntries(SCENARIO_KEYS.map((k) => [k, cloneScenario(DEFAULT_SCENARIOS[k])])),
  packages: DEFAULT_PACKAGES.map((p) => ({ ...p })),
  results: {},
  sens: {},
  scenario: 'base',
  page: 'overview',
  unit: { pkg: 3, rate: 4000, gstMode: 'dashuri', playFeeRate: 0.15, feeBase: 'net', inrPerBean: 0.005, videoUsdPer1000: 1.5, reservePct: 0.05, moderationUsdPerFrame: 0.0015, avgCallMin: 4.5 },
  be: null,
};

const PAGES = [
  ['overview', 'Overview'],
  ['scenarios', 'Scenario comparison'],
  ['customers', 'Customers'],
  ['hosts', 'Hosts'],
  ['wallet', 'Wallets & liabilities'],
  ['unit', 'Unit economics'],
  ['cash', 'Cash flow'],
  ['sensitivity', 'Sensitivity & break-even'],
  ['report', 'Business model report'],
  ['method', 'Assumptions & method'],
];

function focusKey() {
  return state.scenario === 'compare' ? 'base' : state.scenario;
}

function runAll() {
  for (const k of SCENARIO_KEYS) {
    state.results[k] = runScenario({ ...state.params[k], packages: state.packages }, SEEDS[k]);
  }
  state.sens = {};
}

function runOne(k) {
  state.results[k] = runScenario({ ...state.params[k], packages: state.packages }, SEEDS[k]);
  delete state.sens[k];
}

// ---------- layout ----------
function shell() {
  const app = document.getElementById('app');
  app.innerHTML = `
  <header class="topbar">
    <div class="brand">
      <span class="brand-name">Dashuri</span>
      <span class="brand-sub">Six-month financial simulation</span>
    </div>
    <div class="seg" role="tablist" aria-label="Scenario">
      ${[['worst', 'Worst'], ['base', 'Base'], ['best', 'Best'], ['compare', 'Compare']].map(([k, l]) => `<button type="button" id="seg-${k}" class="seg-btn ${k}" data-scn="${k}" role="tab">${k !== 'compare' ? `<i class="dot dot-${k}"></i>` : ''}${l}</button>`).join('')}
    </div>
    <div class="top-actions">
      <button type="button" class="btn" id="btn-assumptions">Edit assumptions</button>
      <button type="button" class="btn" id="btn-export">Export CSV</button>
    </div>
  </header>
  <div class="notice" role="note"><strong>What-if model, not a forecast.</strong> Every result is conditional on labelled assumptions. Demand inputs have no market data behind them. Five seeded runs per scenario; same seed and inputs always give the same result.</div>
  <div class="layout">
    <nav class="sidenav" aria-label="Sections">${PAGES.map(([k, l]) => `<a href="#${k}" data-page="${k}">${l}</a>`).join('')}</nav>
    <main id="main" tabindex="-1"></main>
  </div>
  <div id="drawer" class="drawer" hidden></div>
  <div id="modal" class="modal" hidden></div>`;
  app.querySelectorAll('[data-scn]').forEach((b) => b.addEventListener('click', () => {
    state.scenario = b.dataset.scn;
    try { localStorage.setItem('dashuri-scn', state.scenario); } catch (e) { /* storage optional */ }
    render();
  }));
  document.getElementById('btn-assumptions').addEventListener('click', openDrawer);
  document.getElementById('btn-export').addEventListener('click', openExport);
}

function render() {
  document.querySelectorAll('[data-scn]').forEach((b) => b.setAttribute('aria-selected', b.dataset.scn === state.scenario ? 'true' : 'false'));
  document.querySelectorAll('[data-page]').forEach((a) => a.classList.toggle('active', a.dataset.page === state.page));
  const main = document.getElementById('main');
  const fn = { overview: pageOverview, scenarios: pageScenarios, customers: pageCustomers, hosts: pageHosts, wallet: pageWallet, unit: pageUnit, cash: pageCash, sensitivity: pageSensitivity, report: pageReport, method: pageMethod }[state.page] || pageOverview;
  main.innerHTML = '';
  fn(main);
}

const focusNote = () => (state.scenario === 'compare' ? '<p class="focus-note">Compare mode: this section shows the <b>Base case</b>. Pick Worst or Best above to switch.</p>' : '');
const scnName = (k) => state.params[k].name;
const sectionHead = (title, sub) => `<div class="page-head"><h1>${title}</h1>${sub ? `<p>${sub}</p>` : ''}</div>`;
const card = (title, body, cls = '') => `<section class="card ${cls}"><h2>${title}</h2>${body}</section>`;
const chartBox = (id, title, note) => `<section class="card"><h2>${title}</h2>${note ? `<p class="card-note">${note}</p>` : ''}<div id="${id}" class="chart-host"></div></section>`;
const mean = (k, key) => state.results[k].summaryStats[key].mean;
const rangeTxt = (k, key, f) => {
  const s = state.results[k].summaryStats[key];
  return `${f(s.min)} to ${f(s.max)}`;
};

// ---------- Overview ----------
function kpi(label, value, sub, tone = '') {
  return `<div class="kpi ${tone}"><div class="kpi-label">${label}</div><div class="kpi-value">${value}</div>${sub ? `<div class="kpi-sub">${sub}</div>` : ''}</div>`;
}

const KPI_DEFS = [
  ['topups', 'Customer top-ups (6 mo, incl. GST)', inrShort],
  ['revenue', 'Recognised revenue (ex GST)', inrShort],
  ['hostObligations', 'Host payout obligations', inrShort],
  ['hostPayoutsMade', 'Host payouts made', inrShort],
  ['contribution', 'Contribution, paid calls', inrShort],
  ['operatingProfit', 'Six-month operating profit', inrShort],
  ['peakFunding', 'Peak cash requirement', inrShort],
  ['m6ActiveCustomers', 'Month 6 active customers', (v) => num(v)],
  ['m6PayingCustomers', 'Month 6 paying customers', (v) => num(v)],
  ['m6ActiveHosts', 'Month 6 active hosts', (v) => num(v)],
  ['m6PaidMinutes', 'Month 6 paid minutes', (v) => num(v)],
];

function verdict(k) {
  const r = state.results[k];
  const s = r.summaryStats;
  const firstMonths = r.runs.map((x) => x.summary.firstProfitMonth).filter(Boolean);
  const reach = r.reachesBreakEven;
  const be = s.breakEvenCacPerInstall.mean;
  const op = s.operatingProfit.mean;
  let chip;
  if (reach === r.runs.length) chip = `<span class="pill good">Monthly break-even by Month ${Math.max(...firstMonths)} in ${reach}/${r.runs.length} runs</span>`;
  else if (reach > 0) chip = `<span class="pill warn">Monthly break-even in only ${reach}/${r.runs.length} runs</span>`;
  else chip = `<span class="pill bad">No monthly break-even within six months (0/${r.runs.length} runs)</span>`;
  const cum = op >= 0 ? `<span class="pill good">Six-month cumulative profit ${inrShort(op)}</span>` : `<span class="pill bad">Six-month cumulative loss ${inrShort(op)}</span>`;
  const cac = be > 0 ? `Paid acquisition is affordable only below <b>${inr(be)} per install</b> over six months.` : `<b>No paid acquisition is affordable</b> over six months: operating profit before acquisition is negative (break-even CAC ${inr(be)} per install).`;
  return `<div class="verdict">${chip}${cum}<p>${cac} The six-month result includes the ${inr(state.params[k].preLaunchInr)} pre-launch placeholder for incorporation and professional advice.</p></div>`;
}

const BLOCKERS = [
  ['critical', 'No payout provider has accepted Dashuri', 'Cashfree acceptance is unconfirmed. Bank bulk transfer is a hypothetical fallback that needs a lawyer\'s view. Hosts cannot be paid until this is resolved.'],
  ['critical', 'Moderation model not shown to be compliant', 'Founder model: nudity bot for the first 3 minutes, then report-based. IT Rules (2026 amendment, reported) require 2-hour takedown of intimate images on complaint. Not verified as sufficient for Play or the law.'],
  ['serious', 'GST and Play-fee base unresolved', 'Google pages conflict on who remits GST; principal vs agent treatment needs a CA. Modelled as switchable assumptions.'],
  ['serious', 'Legal structure for Bean payouts', 'Closed-loop Diamonds plus contractual Beans needs a lawyer\'s opinion (PPI / payment aggregator, IT Act s.67/67A, s.79 safe harbour).'],
  ['serious', 'Minor protection', 'Mandatory. Play requires minor-blocking tools for random-chat apps from 26 Aug 2026; the Free Call Card is random.'],
];

function pageOverview(main) {
  if (state.scenario === 'compare') {
    main.innerHTML = sectionHead('Overview: all scenarios', 'Means of five seeded runs per scenario.') +
      card('Headline results', compareTable(KPI_DEFS.map(([k, l, f]) => [k, l, f])), 'flush') +
      `<div class="grid2">${chartBox('ov-op', 'Monthly operating profit before acquisition')}${chartBox('ov-cash', 'Cash balance, daily (mean of seeds)')}</div>` +
      card('Launch blockers', blockerList());
    const series = (key) => SCENARIO_KEYS.map((k) => ({ name: scnName(k), color: color(k), values: state.results[k].monthlyMean.map((m) => m[key]) }));
    barChart(document.getElementById('ov-op'), { labels: MONTH_LABELS, series: series('operatingProfit'), yFormat: inrShort });
    lineChart(document.getElementById('ov-cash'), { labels: dayLabels(), series: SCENARIO_KEYS.map((k) => ({ name: scnName(k), color: color(k), values: thin(state.results[k].balanceMean) })), yFormat: inrShort });
    return;
  }
  const k = state.scenario;
  const r = state.results[k];
  main.innerHTML = sectionHead(`Overview: ${scnName(k)}`, 'Mean of five seeded runs. The small line under each figure shows the lowest and highest run.') +
    verdict(k) +
    `<div class="kpis">${KPI_DEFS.map(([key, label, f]) => kpi(label, f(mean(k, key)), `5 runs: ${rangeTxt(k, key, f)}`, key === 'operatingProfit' ? (mean(k, key) >= 0 ? 'good' : 'bad') : '')).join('')}</div>` +
    `<div class="grid2">${chartBox('ov-op', 'Monthly operating profit before acquisition', 'Bars: mean of runs. Includes pre-launch placeholder in Month 1.')}${chartBox('ov-rev', 'Top-ups vs recognised revenue', 'Top-ups are cash in wallets, not revenue. Revenue is recognised only when Diamonds are spent.')}</div>` +
    `<div class="grid2">${chartBox('ov-cash', 'Cash balance, daily', 'Solid: mean of runs. Dashed: worst run each day. Starting cash ₹0, so the lowest point is the funding needed.')}${card('Launch blockers', blockerList())}</div>`;
  barChart(document.getElementById('ov-op'), { labels: MONTH_LABELS, series: [{ name: 'Operating profit', color: color(k), values: r.monthlyMean.map((m) => m.operatingProfit) }], yFormat: inrShort });
  barChart(document.getElementById('ov-rev'), { labels: MONTH_LABELS, series: [{ name: 'Top-ups (incl. GST)', color: tok('series-neutral'), values: r.monthlyMean.map((m) => m.topupGross) }, { name: 'Recognised revenue (ex GST)', color: color(k), values: r.monthlyMean.map((m) => m.revenue) }], yFormat: inrShort });
  lineChart(document.getElementById('ov-cash'), { labels: dayLabels(), series: [{ name: 'Mean balance', color: color(k), values: thin(r.balanceMean) }, { name: 'Lowest run', color: color(k), dashed: true, values: thin(r.balanceMin) }], yFormat: inrShort });
}

function blockerList() {
  return `<ul class="blockers">${BLOCKERS.map(([sev, t, d]) => `<li><span class="pill ${sev === 'critical' ? 'bad' : 'warn'}">${sev === 'critical' ? 'Blocks payouts / launch' : 'Needs review'}</span><div><b>${t}</b><p>${d}</p></div></li>`).join('')}</ul>`;
}

const dayLabels = () => Array.from({ length: 36 }, (_, i) => `Day ${i * 5 + 5}`);
const thin = (arr) => Array.from({ length: 36 }, (_, i) => arr[i * 5 + 4]);

function compareTable(rows) {
  return `<div class="table-wrap"><table class="num"><thead><tr><th>Metric</th>${SCENARIO_KEYS.map((k) => `<th><i class="dot dot-${k}"></i>${scnName(k)}</th>`).join('')}</tr></thead><tbody>${rows.map(([key, label, f]) => `<tr><td>${label}</td>${SCENARIO_KEYS.map((k) => {
    const s = state.results[k].summaryStats[key];
    return `<td>${f(s.mean)}<div class="cell-sub">${f(s.min)} to ${f(s.max)}</div></td>`;
  }).join('')}</tr>`).join('')}</tbody></table></div>`;
}

// ---------- Scenario comparison ----------
function pageScenarios(main) {
  const rows = [
    ['topups', 'Top-ups (incl. GST)', inrShort], ['revenue', 'Recognised revenue', inrShort], ['contribution', 'Contribution', inrShort],
    ['operatingProfit', 'Operating profit (6 mo)', inrShort], ['m6OperatingProfit', 'Month 6 operating profit', inrShort], ['peakFunding', 'Peak cash requirement', inrShort],
    ['closingCash', 'Cash balance at day 180', inrShort], ['googleReceivable', 'Google receivable at day 180', inrShort], ['uniquePayers', 'Unique payers (6 mo)', (v) => num(v)],
    ['contributionPerPayer', 'Contribution per payer (6 mo)', inr], ['contributionPerPaidMinute', 'Contribution per paid minute (M6)', (v) => (Number.isFinite(v) ? (v < 0 ? '−₹' : '₹') + Math.abs(v).toFixed(2) : '—')],
    ['breakEvenCacPerInstall', 'Break-even CAC per install', inr], ['m6Utilisation', 'Month 6 host utilisation', (v) => pct(v)], ['m6AvgRate', 'Month 6 avg rate (D/min)', (v) => num(v)], ['m6MedianHostEarning', 'Month 6 median host earnings', inr],
  ];
  const stat = `<div class="table-wrap"><table class="num"><thead><tr><th>Metric</th>${SCENARIO_KEYS.map((k) => `<th colspan="5"><i class="dot dot-${k}"></i>${scnName(k)}</th>`).join('')}</tr><tr class="subhead"><th></th>${SCENARIO_KEYS.map(() => '<th>Mean</th><th>Median</th><th>Min</th><th>Max</th><th>SD</th>').join('')}</tr></thead><tbody>${rows.map(([key, label, f]) => `<tr><td>${label}</td>${SCENARIO_KEYS.map((k) => {
    const s = state.results[k].summaryStats[key];
    return `<td>${f(s.mean)}</td><td>${f(s.median)}</td><td>${f(s.min)}</td><td>${f(s.max)}</td><td>${f(s.sd)}</td>`;
  }).join('')}</tr>`).join('')}</tbody></table></div>`;
  const charts = [
    ['sc-rev', 'Recognised revenue', 'revenue', inrShort], ['sc-con', 'Contribution, paid calls', 'contribution', inrShort],
    ['sc-op', 'Operating profit before acquisition', 'operatingProfit', inrShort], ['sc-cash', 'Closing cash balance', 'closingCash', inrShort],
    ['sc-act', 'Active customers', 'activeCustomers', numShort], ['sc-pay', 'Paying customers', 'payingCustomers', numShort],
    ['sc-host', 'Active hosts', 'activeHosts', numShort], ['sc-min', 'Paid billable minutes', 'paidMinutes', numShort],
  ];
  main.innerHTML = sectionHead('Scenario comparison', 'Five seeds per scenario. SD is the spread between runs from random demand and conversion, not the uncertainty of the assumptions themselves.') +
    card('Statistics across runs', stat, 'flush') +
    `<div class="grid2">${charts.map(([id, t]) => chartBox(id, t)).join('')}</div>`;
  for (const [id, , key, f] of charts) {
    lineChart(document.getElementById(id), { labels: MONTH_LABELS, series: SCENARIO_KEYS.map((k) => ({ name: scnName(k), color: color(k), values: state.results[k].monthlyMean.map((m) => m[key]) })), yFormat: f, height: 200 });
  }
}

// ---------- Customers ----------
function funnel(steps) {
  const max = Math.max(...steps.map((s) => s[1]), 1);
  return `<div class="funnel">${steps.map(([l, v], i) => `<div class="funnel-row"><span class="funnel-label">${l}</span><span class="funnel-bar"><i style="width:${Math.max(0.5, (v / max) * 100)}%"></i></span><span class="funnel-val">${num(v)}${i ? `<small>${pct(v / Math.max(1, steps[i - 1][1]))} of previous</small>` : ''}</span></div>`).join('')}</div>`;
}

function pageCustomers(main) {
  const k = focusKey();
  const r = state.results[k];
  const t = (key) => r.monthlyMean.reduce((s, m) => s + m[key], 0);
  const p = state.params[k];
  const s = r.summaryStats;
  const steps = [['Installs', t('installs')], ['Registered (OTP)', t('registrations')], ['Eligible (18+)', t('eligible')], ['Used Free Call Card', t('freeCardUsers')], ['Free call served', t('freeCallsServed')], ['Free call completed', t('freeCallsCompleted')], ['Bought after free call', t('newPayersFromFreeCall')]];
  const pkgTotals = state.packages.map((_, j) => r.monthlyMean.reduce((sum, m) => sum + m.purchasesByPackage[j], 0));
  const ltv = s.contributionPerPayer.mean;
  const freeCostPerPayer = t('freeCallCost') / Math.max(1, t('newPayersFromFreeCall'));
  main.innerHTML = sectionHead(`Customers: ${scnName(k)}`, 'Funnel totals over six months, mean of runs.') + focusNote() +
    `<div class="grid2">${card('Registration and Free Call Card funnel', funnel(steps))}${card('Customer value (six-month window)', `
      <dl class="facts">
        <div><dt>Unique paying customers</dt><dd>${num(s.uniquePayers.mean)}</dd></div>
        <div><dt>Contribution per paying customer</dt><dd>${inr(ltv)}</dd></div>
        <div><dt>Free Call Card cost per converted payer</dt><dd>${inr(freeCostPerPayer)}</dd></div>
        <div><dt>Average top-up (M6)</dt><dd>${inr(r.monthlyMean[5].avgTopup)}</dd></div>
        <div><dt>Repeat purchase rate (input)</dt><dd>${pct(p.payerRetention, 0)} per month</dd></div>
        <div><dt>Top-ups per active payer (input)</dt><dd>${p.purchasesPerPayer}</dd></div>
      </dl>
      <p class="card-note">Lifetime value here is <b>six-month contribution ÷ unique payers</b>: paid-call contribution after GST, Play fee, host Beans, video, moderation and chargebacks. It excludes the Free Call Card, operating costs and acquisition. Customers retained after Month 6 add value the window does not capture; payers acquired late have had less time to spend.</p>`)}</div>` +
    `<div class="grid2">${chartBox('cu-act', 'Active vs paying customers')}${chartBox('cu-new', 'New paying customers by source', 'Free call = bought after a completed free call. Other = bought without using the card. Late = earlier non-payer converting.')}</div>` +
    `<div class="grid2">${chartBox('cu-top', 'Average top-up value')}${chartBox('cu-mix', 'Top-ups by package (6-month total)')}</div>`;
  lineChart(document.getElementById('cu-act'), { labels: MONTH_LABELS, series: [{ name: 'Active customers', color: tok('series-neutral'), values: r.monthlyMean.map((m) => m.activeCustomers) }, { name: 'Paying customers', color: color(k), values: r.monthlyMean.map((m) => m.payingCustomers) }], yFormat: numShort });
  barChart(document.getElementById('cu-new'), { labels: MONTH_LABELS, stacked: true, series: [{ name: 'Free call', color: color(k), values: r.monthlyMean.map((m) => m.newPayersFromFreeCall) }, { name: 'Other', color: tok('series-2'), values: r.monthlyMean.map((m) => m.newPayersOther) }, { name: 'Late', color: tok('series-neutral'), values: r.monthlyMean.map((m) => m.newPayersLate) }], yFormat: numShort });
  lineChart(document.getElementById('cu-top'), { labels: MONTH_LABELS, series: [{ name: 'Average top-up', color: color(k), values: r.monthlyMean.map((m) => m.avgTopup) }], yFormat: inrShort, zeroLine: true });
  barChart(document.getElementById('cu-mix'), { labels: state.packages.map((x) => `₹${x.price}`), series: [{ name: 'Top-ups', color: color(k), values: pkgTotals }], yFormat: numShort });
}

// ---------- Hosts ----------
function pageHosts(main) {
  const k = focusKey();
  const r = state.results[k];
  const p = state.params[k];
  const run0 = r.runs[0];
  const ladder = RATE_LADDERS[p.ladder].max;
  const ladderRows = ladder.map((mx, i) => `<tr><td>Level ${i + 1}</td><td>${num(DEFAULT_XP_THRESHOLDS[i])}</td><td>${num(mx)}</td><td>${inr(hostInrForDiamonds(mx) * 60)}</td><td>${inr(mx * (state.packages[3].price / state.packages[3].diamonds))}</td></tr>`).join('');
  main.innerHTML = sectionHead(`Hosts: ${scnName(k)}`, 'Host supply is a capacity input. Recruitment is managed by the founder and is not modelled as a plan.') + focusNote() +
    `<div class="kpis">${kpi('Month 6 active hosts', num(r.monthlyMean[5].activeHosts))}${kpi('Month 6 utilisation', pct(r.monthlyMean[5].utilisation), 'Share of online capacity used by paid and free calls')}${kpi('Month 6 average rate', num(r.monthlyMean[5].avgRate) + ' D/min', `Customer pays about ${inr(r.monthlyMean[5].avgRate * (state.packages[3].price / state.packages[3].diamonds))}/min`)}${kpi('Median host earnings, Month 6', inr(r.summaryStats.m6MedianHostEarning.mean), 'Per active host, paid + free calls', r.summaryStats.m6MedianHostEarning.mean < 3000 ? 'bad' : '')}</div>` +
    `<div class="grid2">${chartBox('ho-util', 'Host utilisation')}${chartBox('ho-rate', 'Average Diamond rate (minute-weighted)')}</div>` +
    `<div class="grid2">${chartBox('ho-earn', 'Host Beans earned (₹)', 'Paid-call Beans and ₹10 Free Call Card compensation.')}${chartBox('ho-pay', 'Host obligations vs payouts made')}</div>` +
    `<div class="grid2">${chartBox('ho-hist', 'Host earnings distribution, Month 6', `Run seed ${run0.seed}. Active hosts only.`)}${chartBox('ho-lvl', 'Host levels at end of Month 6', `Run seed ${run0.seed}. XP from paid-call Beans (hosts' own top-ups not modelled).`)}</div>` +
    card(`Rate ladder in use: ${esc(RATE_LADDERS[p.ladder].name)} (proposal, not approved)`, `<div class="table-wrap"><table class="num"><thead><tr><th>Level</th><th>XP threshold (P12)</th><th>Max rate D/min</th><th>Host earns per talk-hour</th><th>Customer pays per min (₹1,199 pack)</th></tr></thead><tbody>${ladderRows}</tbody></table></div><p class="card-note">Host earnings use the founder's conversion: 16,670 Diamonds = 10,000 Beans = ₹50, so a host earns about ₹0.003 per Diamond spent. Hosts set rates at about ${pct(p.ratePositioning, 0)} of their level maximum in this scenario.</p>`);
  lineChart(document.getElementById('ho-util'), { labels: MONTH_LABELS, series: [{ name: 'Utilisation', color: color(k), values: r.monthlyMean.map((m) => m.utilisation) }], yFormat: (v) => pct(v, 0) });
  lineChart(document.getElementById('ho-rate'), { labels: MONTH_LABELS, series: [{ name: 'Avg rate', color: color(k), values: r.monthlyMean.map((m) => m.avgRate) }], yFormat: numShort });
  barChart(document.getElementById('ho-earn'), { labels: MONTH_LABELS, stacked: true, series: [{ name: 'Paid calls', color: color(k), values: r.monthlyMean.map((m) => m.beansEarnedPaid * 0.005) }, { name: 'Free calls', color: tok('series-2'), values: r.monthlyMean.map((m) => m.beansEarnedFree * 0.005) }], yFormat: inrShort });
  barChart(document.getElementById('ho-pay'), { labels: MONTH_LABELS, series: [{ name: 'Earned (obligation)', color: tok('series-neutral'), values: r.monthlyMean.map((m) => (m.beansEarnedPaid + m.beansEarnedFree + m.beansEarnedPromo - m.beansClawedBack) * 0.005) }, { name: 'Paid out', color: color(k), values: r.monthlyMean.map((m) => m.payoutCash) }], yFormat: inrShort });
  histogram(document.getElementById('ho-hist'), { values: run0.summary.m6HostEarnings, color: color(k), format: inrShort });
  barChart(document.getElementById('ho-lvl'), { labels: run0.summary.levelDistribution.map((_, i) => `L${i + 1}`), series: [{ name: 'Hosts', color: color(k), values: run0.summary.levelDistribution }], yFormat: (v) => Math.round(v), height: 220 });
}

// ---------- Wallet ----------
function pageWallet(main) {
  const k = focusKey();
  const r = state.results[k];
  const run0 = r.runs[0];
  const rc = run0.recon;
  const m6 = run0.months[5];
  const beansHeld = m6.beansInHold + m6.beansAvailable;
  main.innerHTML = sectionHead(`Wallets & liabilities: ${scnName(k)}`, 'Unspent purchased Diamonds are owed to customers. Earned Beans are owed to hosts. Neither is Dashuri\'s money.') + focusNote() +
    `<div class="grid2">${chartBox('wa-d', 'Diamonds purchased vs consumed')}${chartBox('wa-wal', 'Unspent purchased Diamonds (end of month)')}</div>` +
    `<div class="grid2">${chartBox('wa-b', 'Beans: in hold, withdrawable, withdrawn')}${chartBox('wa-l', 'Liabilities at month end (₹)', 'Customer liability at the GST-inclusive price paid. Host liability at ₹0.005 per Bean.')}</div>` +
    `<div class="grid2">${card('Diamond reconciliation (run seed ' + run0.seed + ')', `<table class="num recon"><tbody>
      <tr><td>Purchased</td><td>${num(rc.cumPurchasedD)}</td></tr>
      <tr><td>− Refunded before use</td><td>${num(rc.cumRefundD)}</td></tr>
      <tr><td>− Consumed in paid calls</td><td>${num(rc.cumConsumedPurchasedD)}</td></tr>
      <tr class="total"><td>= Closing unspent</td><td>${num(rc.cumPurchasedD - rc.cumRefundD - rc.cumConsumedPurchasedD)}</td></tr>
      <tr><td>Wallet balance in model</td><td>${num(m6.walletDiamonds)}</td></tr>
      <tr><td>Promotional Diamonds granted / expired</td><td>${num(run0.months.reduce((s, m) => s + m.promoDiamondsGranted, 0))} / ${num(run0.months.reduce((s, m) => s + m.promoDiamondsExpired, 0))}</td></tr></tbody></table>`)}
      ${card('Bean reconciliation (run seed ' + run0.seed + ')', `<table class="num recon"><tbody>
      <tr><td>Earned (paid + free + promo)</td><td>${num(rc.cumBeansEarned)}</td></tr>
      <tr><td>− Clawed back on chargebacks</td><td>${num(rc.cumBeansClawed)}</td></tr>
      <tr><td>− Withdrawn</td><td>${num(rc.cumBeansWithdrawn)}</td></tr>
      <tr class="total"><td>= Still owed</td><td>${num(rc.cumBeansEarned - rc.cumBeansClawed - rc.cumBeansWithdrawn)}</td></tr>
      <tr><td>In 7-day hold + withdrawable in model</td><td>${num(beansHeld)}</td></tr>
      <tr><td>Host liability (₹)</td><td>${inr(m6.hostLiabilityInr)}</td></tr></tbody></table>`)}</div>`;
  barChart(document.getElementById('wa-d'), { labels: MONTH_LABELS, series: [{ name: 'Purchased', color: tok('series-neutral'), values: r.monthlyMean.map((m) => m.diamondsPurchased) }, { name: 'Consumed', color: color(k), values: r.monthlyMean.map((m) => m.diamondsConsumed) }], yFormat: numShort });
  lineChart(document.getElementById('wa-wal'), { labels: MONTH_LABELS, series: [{ name: 'Unspent Diamonds', color: color(k), values: r.monthlyMean.map((m) => m.walletDiamonds) }], yFormat: numShort });
  barChart(document.getElementById('wa-b'), { labels: MONTH_LABELS, series: [{ name: 'In hold (end)', color: tok('series-2'), values: r.monthlyMean.map((m) => m.beansInHold) }, { name: 'Withdrawable (end)', color: tok('series-neutral'), values: r.monthlyMean.map((m) => m.beansAvailable) }, { name: 'Withdrawn (month)', color: color(k), values: r.monthlyMean.map((m) => m.beansWithdrawn) }], yFormat: numShort });
  lineChart(document.getElementById('wa-l'), { labels: MONTH_LABELS, series: [{ name: 'Customer wallets', color: tok('series-neutral'), values: r.monthlyMean.map((m) => m.customerLiabilityInr) }, { name: 'Hosts', color: color(k), values: r.monthlyMean.map((m) => m.hostLiabilityInr) }], yFormat: inrShort });
}

// ---------- Unit economics ----------
function pageUnit(main) {
  const u = state.unit;
  const opt = (v, l, cur) => `<option value="${v}" ${String(v) === String(cur) ? 'selected' : ''}>${l}</option>`;
  main.innerHTML = sectionHead('Unit economics', 'One package spent entirely with one host rate. Change any input and the breakdown updates immediately.') +
    `<section class="card"><h2>Inputs</h2><div class="form-grid">
      <label>Package<select id="u-pkg">${state.packages.map((p, i) => opt(i, `${p.name}: ₹${p.price} → ${num(p.diamonds)} D`, u.pkg)).join('')}</select></label>
      <label>Host rate <output id="u-rate-o">${num(u.rate)} D/min</output><input type="range" id="u-rate" min="500" max="10000" step="100" value="${u.rate}"></label>
      <label>GST treatment<select id="u-gst">${opt('dashuri', 'Principal, Dashuri remits', u.gstMode)}${opt('google', 'Principal, Google remits', u.gstMode)}${opt('agent', 'Agent model (hypothetical, CA)', u.gstMode)}</select></label>
      <label>Play fee<select id="u-fee">${opt(0.15, '15% (first US$1M/yr, enrolled)', u.playFeeRate)}${opt(0.3, '30% (above US$1M/yr)', u.playFeeRate)}${opt(0.11, '11% (alt. billing, NOT assumed available)', u.playFeeRate)}</select></label>
      <label>Play fee charged on<select id="u-base">${opt('net', 'GST-exclusive price', u.feeBase)}${opt('gross', 'Price paid (incl. GST)', u.feeBase)}</select></label>
      <label>Bean value (₹)<input type="number" id="u-bean" step="0.0005" min="0" value="${u.inrPerBean}"></label>
      <label>Video, US$ per 1,000 participant-min<select id="u-video">${opt(0.75, 'SD $0.75', u.videoUsdPer1000)}${opt(1.5, 'HD $1.50', u.videoUsdPer1000)}${opt(3, 'Full HD $3.00', u.videoUsdPer1000)}</select></label>
      <label>Refund & fraud reserve <output id="u-res-o">${pct(u.reservePct, 0)}</output><input type="range" id="u-res" min="0" max="0.2" step="0.01" value="${u.reservePct}"></label>
      <label>Moderation, US$ per frame<input type="number" id="u-mod" step="0.0005" min="0" value="${u.moderationUsdPerFrame}"></label>
      <label>Average call length (min)<input type="number" id="u-call" step="0.5" min="0.5" value="${u.avgCallMin}"></label>
    </div></section>
    <div class="grid2"><section class="card"><h2 id="u-title">Where the money goes</h2><div id="u-water"></div></section><section class="card"><h2>Per minute and per call</h2><div id="u-per"></div></section></div>
    <section class="card flush"><h2>All packages at these settings</h2><div id="u-all"></div></section>`;
  const bind = (id, key, parse = Number) => document.getElementById(id).addEventListener('input', (e) => {
    u[key] = parse(e.target.value);
    updateUnit();
  });
  bind('u-pkg', 'pkg');
  bind('u-rate', 'rate');
  bind('u-gst', 'gstMode', String);
  bind('u-fee', 'playFeeRate');
  bind('u-base', 'feeBase', String);
  bind('u-bean', 'inrPerBean');
  bind('u-video', 'videoUsdPer1000');
  bind('u-res', 'reservePct');
  bind('u-mod', 'moderationUsdPerFrame');
  bind('u-call', 'avgCallMin');
  updateUnit();
}

function updateUnit() {
  const u = state.unit;
  const o = { rate: u.rate, inrPerBean: u.inrPerBean, playFeeRate: u.playFeeRate, feeBase: u.feeBase, gstMode: u.gstMode, videoUsdPer1000: u.videoUsdPer1000, reservePct: u.reservePct, moderationUsdPerFrame: u.moderationUsdPerFrame, avgCallMin: u.avgCallMin, fxInrPerUsd: state.params.base.fxInrPerUsd };
  document.getElementById('u-rate-o').textContent = `${num(u.rate)} D/min`;
  document.getElementById('u-res-o').textContent = pct(u.reservePct, 0);
  const pkg = state.packages[u.pkg];
  const w = packageWaterfall(pkg, o);
  document.getElementById('u-title').textContent = `Where ₹${num(pkg.price)} goes`;
  const parts = [['GST', w.gst, 'tax'], ['Google Play fee', w.fee, 'fee'], ['Host Beans', w.host, 'host'], ['Video', w.video, 'cost'], ['Moderation bot', w.moderation, 'cost'], ['Refund & fraud reserve', w.reserve, 'cost'], ['Contribution', w.contribution, 'contrib']];
  document.getElementById('u-water').innerHTML = `<div class="stackbar">${parts.map(([l, v, c]) => `<i class="sb-${c}" style="width:${Math.max(0, (v / pkg.price) * 100)}%" title="${l}: ${inr(v)}"></i>`).join('')}</div>
    <table class="num waterfall"><tbody>${[['Customer pays', pkg.price, '']].concat(parts.map(([l, v, c]) => [l, -v, c])).map(([l, v, c], i) => `<tr class="${c === 'contrib' ? 'total' : ''}"><td>${c ? `<i class="sw sb-${c}"></i>` : ''}${l}</td><td>${c === 'contrib' ? inr(w.contribution) : (i ? '−' : '') + inr(Math.abs(v))}</td><td>${pct(Math.abs(v) / pkg.price)}</td></tr>`).join('')}</tbody></table>
    <p class="card-note">Contribution is <b>not profit</b>. It still has to pay for the Free Call Card, safety operations, OTP, KYC, payout fees, infrastructure, professional fees, acquisition and income tax, and it assumes every Diamond in the pack is spent.</p>`;
  const calls = w.minutes / u.avgCallMin;
  document.getElementById('u-per').innerHTML = `<dl class="facts">
    <div><dt>Minutes the pack buys</dt><dd>${num(w.minutes, 1)}</dd></div>
    <div><dt>Customer price per minute</dt><dd>${inr(w.pricePerMinute)}</dd></div>
    <div><dt>Host earns per minute</dt><dd>₹${(w.host / w.minutes).toFixed(2)}</dd></div>
    <div><dt>Host share of price</dt><dd>${pct(w.hostPct)}</dd></div>
    <div><dt>Contribution per minute</dt><dd>₹${(w.contribution / w.minutes).toFixed(2)}</dd></div>
    <div><dt>Contribution per call (${u.avgCallMin} min)</dt><dd>₹${(w.contribution / calls).toFixed(2)}</dd></div>
    <div><dt>Beans earned by host</dt><dd>${num(w.beans)}</dd></div>
    <div><dt>Host earns per talk-hour</dt><dd>${inr((w.host / w.minutes) * 60)}</dd></div></dl>`;
  const rows = state.packages.map((p) => {
    const x = packageWaterfall(p, o);
    return `<tr><td>${p.name}</td><td>${inr(p.price)}</td><td>${num(p.diamonds)}</td><td>${num(x.minutes, 1)}</td><td>${inr(x.gst)}</td><td>${inr(x.fee)}</td><td>${inr(x.host)}</td><td>${inr(x.video + x.moderation)}</td><td>${inr(x.reserve)}</td><td><b>${inr(x.contribution)}</b></td><td>${pct(x.contributionPct)}</td></tr>`;
  }).join('');
  document.getElementById('u-all').innerHTML = `<div class="table-wrap"><table class="num"><thead><tr><th>Package</th><th>Price</th><th>Diamonds</th><th>Minutes</th><th>GST</th><th>Play fee</th><th>Host</th><th>Video + mod.</th><th>Reserve</th><th>Contribution</th><th>%</th></tr></thead><tbody>${rows}</tbody></table></div>`;
}

// ---------- Cash flow ----------
function pageCash(main) {
  const k = focusKey();
  const r = state.results[k];
  const p = state.params[k];
  const s = r.summaryStats;
  const mm = r.monthlyMean;
  const peak = s.peakFunding.max;
  const rows = [
    ['cashIn', 'Google settlements received', 1], ['cashOutHosts', 'Host payouts + transfer fees', -1], ['cashOutGst', 'GST paid by Dashuri', -1], ['cashOutOpex', 'Operating & infrastructure', -1], ['cashOutPreLaunch', 'Pre-launch one-time (placeholder)', -1], ['cashOutAcquisition', 'Acquisition at what-if CAC', -1], ['netCash', 'Net cash movement', 0], ['closingCash', 'Closing balance', 0], ['minCashInMonth', 'Lowest balance in month', 0],
  ];
  main.innerHTML = sectionHead(`Cash flow: ${scnName(k)}`, 'Cash is not profit. Google pays the month\'s sales from the 15th of the next month plus bank transit; hosts are paid weekly after a 7-day hold.') + focusNote() +
    `<div class="kpis">${kpi('Peak cash requirement (mean)', inrShort(s.peakFunding.mean), `5 runs: ${rangeTxt(k, 'peakFunding', inrShort)}`, 'bad')}${kpi('Minimum reserve to hold', inrShort(peak * 1.1), 'Worst run peak + 10% buffer')}${kpi('Cash at day 180', inrShort(s.closingCash.mean), 'Mean of runs')}${kpi('Google receivable at day 180', inrShort(s.googleReceivable.mean), 'Month 6 sales not yet paid out')}</div>` +
    chartBox('ca-bal', 'Daily cash balance', 'Starting from ₹0. Solid: mean of runs. Dashed: lowest run on each day.') +
    `<section class="card flush"><h2>Monthly cash (mean of runs)</h2><div class="table-wrap"><table class="num"><thead><tr><th>₹</th>${MONTH_LABELS.map((l) => `<th>${l}</th>`).join('')}</tr></thead><tbody>${rows.map(([key, l, sign]) => `<tr class="${key === 'closingCash' ? 'total' : ''}"><td>${l}</td>${mm.map((m) => `<td>${inr(sign < 0 ? -m[key] : m[key])}</td>`).join('')}</tr>`).join('')}</tbody></table></div></section>` +
    `<div class="grid2">${card('Settlement timing used', `<dl class="facts">
      <div><dt>Google payout</dt><dd>Day ${p.settlementDay} of the next month</dd></div>
      <div><dt>Bank transit</dt><dd>${p.bankTransitDays} days (official: 2–7 business days)</dd></div>
      <div><dt>First settlement lands</dt><dd>Day ${30 + p.settlementDay + p.bankTransitDays}</dd></div>
      <div><dt>Bean hold</dt><dd>${CONSTANTS.holdDays} days, payouts every ${CONSTANTS.payoutIntervalDays} days, minimum ₹${CONSTANTS.minWithdrawInr}</dd></div>
      <div><dt>GST</dt><dd>${p.gstMode === 'google' ? 'Withheld by Google from settlement' : 'Paid by Dashuri on the 20th of the next month'}</dd></div>
      <div><dt>Chargebacks</dt><dd>Deducted from the next settlement, plus ${inr(p.chargebackFeeInr)} bank fee each (UNVERIFIED)</dd></div></dl>
      <p class="card-note">The model assumes Diamonds are spent soon after purchase, which is conservative. Payouts start only after incorporation and payout onboarding (founder decision R3-7); this simulation assumes that work is complete before Month 1.</p>`)}
      ${card('Peak requirement by scenario', `<table class="num"><thead><tr><th>Scenario</th><th>Mean</th><th>Worst run</th><th>Reserve (+10%)</th></tr></thead><tbody>${SCENARIO_KEYS.map((x) => `<tr><td><i class="dot dot-${x}"></i>${scnName(x)}</td><td>${inr(mean(x, 'peakFunding'))}</td><td>${inr(state.results[x].summaryStats.peakFunding.max)}</td><td>${inr(state.results[x].summaryStats.peakFunding.max * 1.1)}</td></tr>`).join('')}</tbody></table>`)}</div>`;
  lineChart(document.getElementById('ca-bal'), { labels: dayLabels(), series: [{ name: 'Mean balance', color: color(k), values: thin(r.balanceMean) }, { name: 'Lowest run', color: color(k), dashed: true, values: thin(r.balanceMin) }], yFormat: inrShort, height: 260 });
}

// ---------- Sensitivity ----------
const QUICK = [
  ['installsM1', 'Installs in Month 1', 500, 30000, 500],
  ['freeToPaidRate', 'Free-to-paid conversion', 0, 0.3, 0.005],
  ['payerRetention', 'Repeat purchase rate', 0, 0.9, 0.01],
  ['purchasesPerPayer', 'Top-ups per payer per month', 1, 4, 0.1],
  ['cacPerInstall', 'Acquisition cost per install (₹)', 0, 100, 1],
  ['freeCardUseRate', 'Free Call Card use', 0, 1, 0.05],
  ['inrPerBean', 'Bean value (₹)', 0.002, 0.01, 0.0005],
  ['playFeeRate', 'Play fee', 0.11, 0.3, 0.01],
];

function pageSensitivity(main) {
  const k = focusKey();
  const p = state.params[k];
  const r = state.results[k];
  const run0 = r.runs[0].summary;
  const be = run0.breakEven;
  state.be = state.be && state.be.k === k ? state.be : { k, fixed: Math.round(run0.breakEvenFixedMonthly), cpm: +run0.contributionPerPaidMinute.toFixed(2), mpp: +(r.runs[0].months[5].paidMinutes / Math.max(1, r.runs[0].months[5].payingCustomers)).toFixed(1), call: p.avgPaidCallMin, rpm: +(r.runs[0].months[5].revenue / Math.max(1, r.runs[0].months[5].paidMinutes)).toFixed(2) };
  main.innerHTML = sectionHead(`Sensitivity & break-even: ${scnName(k)}`, 'One input changes at a time; everything else stays at the scenario setting. Metric: six-month profit after acquisition (equals operating profit when CAC is ₹0).') + focusNote() +
    `<section class="card"><h2>What moves six-month profit most</h2><div id="se-tor" class="chart-host"><p class="muted">Running ${SENS_RUNS()} simulations…</p></div><p class="card-note" id="se-infl"></p></section>` +
    `<div class="grid2"><section class="card"><h2>Live what-if</h2><p class="card-note">Changes apply to the ${esc(scnName(k))} and rerun its five seeds at once.</p><div class="form-grid one">${QUICK.map(([key, label, mn, mx, st]) => `<label>${label} <output id="q-${key}-o">${fmtQuick(key, p[key])}</output><input type="range" id="q-${key}" min="${mn}" max="${mx}" step="${st}" value="${p[key]}"></label>`).join('')}</div><div id="q-out" class="q-out"></div></section>
     <section class="card"><h2>Break-even calculator</h2><p class="card-note">Seeded from Month 6 of run ${r.runs[0].seed}. Fixed monthly cost = Free Call Card + operating costs in Month 6.</p><div class="form-grid">
      <label>Fixed monthly cost (₹)<input type="number" id="b-fixed" value="${state.be.fixed}"></label>
      <label>Contribution per paid minute (₹)<input type="number" step="0.1" id="b-cpm" value="${state.be.cpm}"></label>
      <label>Paid minutes per payer per month<input type="number" step="0.5" id="b-mpp" value="${state.be.mpp}"></label>
      <label>Average call (min)<input type="number" step="0.5" id="b-call" value="${state.be.call}"></label>
      <label>Revenue per paid minute (₹)<input type="number" step="0.1" id="b-rpm" value="${state.be.rpm}"></label></div><div id="b-out"></div>
      <p class="card-note">Model run result: ${be.exists ? `break-even needs about <b>${num(be.minutes)}</b> paid minutes a month vs <b>${num(r.runs[0].months[5].paidMinutes)}</b> in Month 6.` : 'contribution per minute is not positive, so no break-even exists.'}</p></section></div>`;
  QUICK.forEach(([key]) => {
    const input = document.getElementById(`q-${key}`);
    input.addEventListener('input', () => {
      document.getElementById(`q-${key}-o`).textContent = fmtQuick(key, +input.value);
    });
    input.addEventListener('change', () => {
      p[key] = +input.value;
      runOne(k);
      quickOut(k);
      drawTornado(k, true);
    });
  });
  ['fixed', 'cpm', 'mpp', 'call', 'rpm'].forEach((x) => document.getElementById(`b-${x}`).addEventListener('input', (e) => {
    state.be[x] = +e.target.value;
    beOut();
  }));
  quickOut(k);
  beOut();
  setTimeout(() => drawTornado(k), 30);
}

const SENS_RUNS = () => 2 * 17 * 3 + 3;
function fmtQuick(key, v) {
  if (key === 'installsM1') return num(v);
  if (key === 'cacPerInstall') return inr(v);
  if (key === 'purchasesPerPayer') return Number(v).toFixed(1);
  if (key === 'inrPerBean') return '₹' + Number(v).toFixed(4);
  return pct(v, 1);
}
function quickOut(k) {
  const s = state.results[k].summaryStats;
  document.getElementById('q-out').innerHTML = `<dl class="facts"><div><dt>Six-month operating profit</dt><dd class="${s.operatingProfit.mean >= 0 ? 'pos' : 'neg'}">${inr(s.operatingProfit.mean)}</dd></div><div><dt>Profit after acquisition</dt><dd class="${s.profitAfterAcquisition.mean >= 0 ? 'pos' : 'neg'}">${inr(s.profitAfterAcquisition.mean)}</dd></div><div><dt>Peak cash requirement</dt><dd>${inr(s.peakFunding.mean)}</dd></div><div><dt>Month 6 paying customers</dt><dd>${num(s.m6PayingCustomers.mean)}</dd></div><div><dt>Break-even CAC per install</dt><dd>${inr(s.breakEvenCacPerInstall.mean)}</dd></div></dl>`;
}
function beOut() {
  const b = state.be;
  const res = breakEven({ fixedMonthly: b.fixed, contributionPerPaidMinute: b.cpm, minutesPerPayer: b.mpp, avgCallMin: b.call, revenuePerMinute: b.rpm });
  document.getElementById('b-out').innerHTML = res.exists ? `<dl class="facts"><div><dt>Break-even paid minutes / month</dt><dd>${num(res.minutes)}</dd></div><div><dt>Break-even paying customers</dt><dd>${num(res.payers)}</dd></div><div><dt>Break-even completed paid calls / day</dt><dd>${num(res.dailyCalls, 1)}</dd></div><div><dt>Break-even monthly revenue (ex GST)</dt><dd>${inr(res.revenue)}</dd></div></dl>` : '<p class="pill bad">No break-even: contribution per paid minute must be above ₹0.</p>';
}
function drawTornado(k, force) {
  const host = document.getElementById('se-tor');
  if (!host) return;
  if (!state.sens[k] || force) {
    const seeds = SEEDS[k].slice(0, 3);
    state.sens[k] = sensitivity({ ...state.params[k], packages: state.packages }, seeds, 'profitAfterAcquisition');
  }
  const sres = state.sens[k];
  tornadoChart(host, { rows: sres.rows, base: sres.base, format: inrShort, loColor: tok('series-2'), hiColor: color(k) });
  document.getElementById('se-infl').innerHTML = 'Who controls each input: ' + sres.rows.map((x) => `<span class="tag">${esc(x.label)}: ${esc(x.influence)}</span>`).join(' ') + ' Uses the first three seeds of the scenario for speed.';
}

// ---------- Report ----------
function pageReport(main) {
  const { html, toc } = renderMarkdown(REPORT_MD);
  main.innerHTML = sectionHead('Business model report', 'The complete current docs/business-model-report.md, unedited. Labels like FOUNDER, CLAUDE and UNVERIFIED are highlighted.') +
    `<div class="report-layout"><nav class="toc" aria-label="Report contents">${toc.filter((t) => t.level <= 2).map((t) => `<a href="#report" data-anchor="${t.id}" class="toc-${t.level}">${esc(t.text)}</a>`).join('')}</nav><article class="report">${html}</article></div>`;
  main.querySelectorAll('[data-anchor]').forEach((a) => a.addEventListener('click', (e) => {
    e.preventDefault();
    const t = document.getElementById(a.dataset.anchor);
    if (t) t.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }));
}

// ---------- Method ----------
function pageMethod(main) {
  const fmtVal = (key, v) => {
    if (Array.isArray(v)) return v.join(' / ');
    if (key === 'ladder') return RATE_LADDERS[v].name;
    if (PARAM_META[key].pct) return pct(v, v < 0.01 && v > 0 ? 2 : 1);
    return typeof v === 'number' ? num(v, v % 1 ? 4 : 0) : esc(v);
  };
  const statusCls = (s) => (s === STATUS.VERIFIED || s === STATUS.FOUNDER ? 'good' : s === STATUS.UNVERIFIED || s === STATUS.PRO ? 'bad' : 'warn');
  const groups = [...new Set(Object.values(PARAM_META).map((m) => m.group))];
  const table = groups.map((g) => `<tr class="group"><td colspan="6">${g}</td></tr>` + Object.entries(PARAM_META).filter(([, m]) => m.group === g).map(([key, m]) => `<tr><td>${m.label}${m.note ? `<div class="cell-sub">${esc(m.note)}</div>` : ''}</td><td>${esc(m.unit)}</td>${SCENARIO_KEYS.map((k) => `<td>${fmtVal(key, state.params[k][key])}</td>`).join('')}<td><span class="pill ${statusCls(m.status)}">${esc(m.status)}</span></td></tr>`).join('')).join('') +
    `<tr class="group"><td colspan="6">Package mix (share of top-ups, Starter → Premium)</td></tr><tr><td>Package mix</td><td>share</td>${SCENARIO_KEYS.map((k) => `<td>${state.params[k].packageMix.map((x) => pct(x, 0)).join(' / ')}</td>`).join('')}<td><span class="pill warn">${STATUS.HYPOTHESIS}</span></td></tr>`;
  main.innerHTML = sectionHead('Assumptions & method', 'Every input, where it comes from, and how the numbers are computed.') +
    `<section class="card flush"><h2>All inputs by scenario</h2><div class="table-wrap"><table class="num left"><thead><tr><th>Input</th><th>Unit</th>${SCENARIO_KEYS.map((k) => `<th><i class="dot dot-${k}"></i>${scnName(k)}</th>`).join('')}<th>Evidence</th></tr></thead><tbody>${table}</tbody></table></div></section>` +
    `<section class="card flush"><h2>External prices and policies (retrieved ${SOURCES[0] ? '2026-11-17' : ''})</h2><div class="table-wrap"><table class="left"><thead><tr><th>Source</th><th>Unit</th><th>Conditions</th><th>Status</th></tr></thead><tbody>${SOURCES.map((s) => `<tr><td>${/^http/.test(s.url) ? `<a href="${s.url}" target="_blank" rel="noopener">${esc(s.name)}</a>` : esc(s.name)}</td><td>${esc(s.unit)}</td><td>${esc(s.conditions)}</td><td><span class="pill ${statusCls(s.status)}">${esc(s.status)}</span></td></tr>`).join('')}</tbody></table></div></section>` +
    `<div class="grid2">${card('Formulas', `<ul class="formulas">
      <li><b>Beans</b> = Diamonds spent × 10,000 ÷ 16,670 (founder decision, no early rounding)</li>
      <li><b>Host liability</b> = Beans × ₹0.005 ≈ ₹0.0029994 per Diamond</li>
      <li><b>Call charge</b> = floor(rate × billable seconds ÷ 60); billable = connected − paused</li>
      <li><b>GST in a price</b> = price × 18 ÷ 118 (agent hypothetical: on price − host share)</li>
      <li><b>Play fee</b> = rate × (price ÷ 1.18) or × price, per the fee-base setting; deferred and expensed as Diamonds are spent</li>
      <li><b>Revenue</b> = gross value of purchased Diamonds consumed − GST on that value</li>
      <li><b>Contribution</b> = revenue − Play fee − host Beans (paid calls) + clawbacks − video − moderation bot − chargeback losses and fees</li>
      <li><b>Operating profit</b> = contribution − Free Call Card cost − operating costs − pre-launch placeholder</li>
      <li><b>Video</b> = max(0, participant-min × $/1,000 − $100 credit) × ₹/US$</li>
      <li><b>Moderation bot</b> = calls × min(call length, 3 min) × frames/min × streams × $/frame × ₹/US$</li>
      <li><b>Google settlement</b> = month's top-ups − refunds − Play fee − (GST if Google remits) − chargebacks, paid day 15 of next month + transit</li>
      <li><b>Peak cash requirement</b> = −(lowest daily cash balance) starting from ₹0</li>
      <li><b>Break-even CAC per install</b> = six-month operating profit before acquisition ÷ installs</li></ul>`)}
      ${card('Simulation design', `<ul class="formulas">
      <li>Daily steps over 180 days (six 30-day months). Monthly reporting.</li>
      <li>Seeds: Worst ${SEEDS.worst.join(', ')}; Base ${SEEDS.base.join(', ')}; Best ${SEEDS.best.join(', ')}. Deterministic per seed.</li>
      <li>Customers: binomial draws for registration, eligibility, Free Call Card use, conversion and retention. Top-up counts are Poisson; packages drawn from the mix.</li>
      <li>Hosts simulated individually: daily availability, online hours, free-pool opt-in, XP from paid-call Beans, level, rate within the ladder.</li>
      <li>Demand: a share of each wallet is spent daily, allocated to online hosts by spare capacity with a mild preference for lower rates; unmet demand stays in wallets.</li>
      <li>Free calls served first, max 20 per opted-in host per day, ₹10 per completed free call; unserved card users lapse at month end.</li>
      <li>Chargebacks land 15–60 days after purchase; a share of related Beans still in hold is clawed back.</li>
      <li>Hosts withdraw all withdrawable Beans at weekly payouts if ≥ ₹500.</li></ul>`)}</div>` +
    `<div class="grid2">${card('Known limitations', `<ul class="formulas">
      <li>No market data exists for installs, conversion, retention, top-up mix or call length. They are labelled hypotheses.</li>
      <li>Prices do not change demand (no elasticity). A cheaper host gives more minutes for the same Diamonds.</li>
      <li>Host supply is an input; host churn does not respond to low earnings, which in reality it would.</li>
      <li>Customer XP and levels are not used for pricing; only host levels gate rates. Hosts' own top-ups are ignored.</li>
      <li>Income tax, TDS timing, depreciation and the founder's time are excluded.</li>
      <li>Promotional Diamonds default to zero because no grant has been decided.</li>
      <li>Results after Month 6 (receivables, liabilities, late chargebacks) are reported but not simulated further.</li></ul>`)}
      ${card('Needs a CA or lawyer', `<ul class="formulas">
      <li>GST: principal vs agent; who remits on Play sales; whether Play fee applies to GST-inclusive price (all switchable here).</li>
      <li>TDS section on host payouts (194-O 0.1% or other).</li>
      <li>Social-security levy (1–2% of turnover) notification and applicability (switchable, default 0%).</li>
      <li>Legality of the Bean payout structure; PPI / payment aggregator risk.</li>
      <li>Whether 3-minute bot moderation plus reports meets IT Rules and Play policy.</li>
      <li>Payout provider acceptance (no written confirmation).</li></ul>`)}</div>` +
    card('Unresolved business-model decisions', `<ul class="formulas"><li>Host level thresholds, names, rewards and the rate ladder (three proposals modelled: A, B, C).</li><li>Final Diamond package prices (evaluation set used).</li><li>Exact interruption thresholds (modelled as a paused share of time).</li><li>Promotional Diamond grants.</li><li>Pvt Ltd vs OPC.</li><li>Customer acquisition budget (none assumed; break-even CAC reported).</li></ul>`) +
    `<p class="muted build">Built ${esc(BUILD_INFO.builtAt || '')} from engine version ${esc(BUILD_INFO.version || '')}. Report source: ${esc(BUILD_INFO.reportFile || '')}.</p>`;
}

// ---------- Assumptions drawer ----------
function openDrawer() {
  const k = focusKey();
  const p = state.params[k];
  const d = document.getElementById('drawer');
  const groups = [...new Set(Object.values(PARAM_META).map((m) => m.group))];
  const field = (key, m) => {
    const v = p[key];
    const id = `in-${key}`;
    if (key === 'ladder') return `<label>${m.label}<select id="${id}">${Object.entries(RATE_LADDERS).map(([lk, l]) => `<option value="${lk}" ${lk === v ? 'selected' : ''}>${esc(l.name)}</option>`).join('')}</select></label>`;
    if (key === 'gstMode') return `<label>${m.label}<select id="${id}"><option value="dashuri" ${v === 'dashuri' ? 'selected' : ''}>Principal, Dashuri remits</option><option value="google" ${v === 'google' ? 'selected' : ''}>Principal, Google remits</option><option value="agent" ${v === 'agent' ? 'selected' : ''}>Agent model (hypothetical)</option></select></label>`;
    if (key === 'feeBase') return `<label>${m.label}<select id="${id}"><option value="net" ${v === 'net' ? 'selected' : ''}>GST-exclusive price</option><option value="gross" ${v === 'gross' ? 'selected' : ''}>Price paid</option></select></label>`;
    if (Array.isArray(v)) return `<label>${m.label} <small>comma-separated, M1–M6</small><input id="${id}" value="${v.join(', ')}"></label>`;
    return `<label>${m.label}${m.unit ? ` <small>${esc(m.unit)}${m.pct ? ' (0–1)' : ''}</small>` : ''}<input id="${id}" type="number" step="any" value="${v}"></label>`;
  };
  d.innerHTML = `<div class="drawer-panel" role="dialog" aria-label="Edit assumptions">
    <div class="drawer-head"><h2>Assumptions: ${esc(scnName(k))}</h2><button type="button" class="btn ghost" id="dr-close">Close</button></div>
    <p class="card-note">Edits apply to this scenario only. Packages apply to all scenarios. Results rerun when you press Apply.</p>
    ${groups.map((g) => `<fieldset><legend>${g}</legend>${Object.entries(PARAM_META).filter(([, m]) => m.group === g).map(([key, m]) => field(key, m)).join('')}</fieldset>`).join('')}
    <fieldset><legend>Package mix (shares, Starter → Premium)</legend><label>Shares <small>comma-separated, sums normalised</small><input id="in-packageMix" value="${p.packageMix.join(', ')}"></label></fieldset>
    <fieldset><legend>Diamond packages (all scenarios)</legend>${state.packages.map((pk, i) => `<div class="pkg-row"><span>${pk.name}</span><label>₹<input id="pk-p-${i}" type="number" value="${pk.price}"></label><label>Diamonds<input id="pk-d-${i}" type="number" value="${pk.diamonds}"></label></div>`).join('')}</fieldset>
    <div class="drawer-foot"><button type="button" class="btn primary" id="dr-apply">Apply and rerun</button><button type="button" class="btn ghost" id="dr-reset">Reset this scenario</button><span id="dr-msg" class="muted"></span></div></div>`;
  d.hidden = false;
  document.getElementById('dr-close').onclick = () => { d.hidden = true; };
  document.getElementById('dr-reset').onclick = () => {
    state.params[k] = cloneScenario(DEFAULT_SCENARIOS[k]);
    state.packages = DEFAULT_PACKAGES.map((x) => ({ ...x }));
    runAll();
    openDrawer();
    render();
  };
  document.getElementById('dr-apply').onclick = () => {
    const msg = document.getElementById('dr-msg');
    try {
      for (const [key, m] of Object.entries(PARAM_META)) {
        const input = document.getElementById(`in-${key}`);
        if (!input) continue;
        if (['ladder', 'gstMode', 'feeBase'].includes(key)) p[key] = input.value;
        else if (Array.isArray(p[key])) {
          const arr = input.value.split(',').map((x) => Number(x.trim())).filter((x) => Number.isFinite(x));
          if (arr.length !== 6) throw new Error(`${m.label}: enter six numbers.`);
          p[key] = arr;
        } else {
          const v = Number(input.value);
          if (!Number.isFinite(v)) throw new Error(`${m.label}: enter a number.`);
          if (m.pct && (v < 0 || v > 1)) throw new Error(`${m.label}: use a value from 0 to 1.`);
          p[key] = v;
        }
      }
      const mix = document.getElementById('in-packageMix').value.split(',').map((x) => Number(x.trim()));
      if (mix.length !== state.packages.length || mix.some((x) => !(x >= 0))) throw new Error('Package mix: enter six non-negative shares.');
      const tot = mix.reduce((s, x) => s + x, 0) || 1;
      p.packageMix = mix.map((x) => x / tot);
      state.packages = state.packages.map((pk, i) => ({ ...pk, price: Number(document.getElementById(`pk-p-${i}`).value), diamonds: Number(document.getElementById(`pk-d-${i}`).value) }));
      runAll();
      render();
      msg.textContent = 'Applied. All scenarios rerun.';
    } catch (e) {
      msg.textContent = e.message;
    }
  };
}

// ---------- Export ----------
function openExport() {
  const k = focusKey();
  const modal = document.getElementById('modal');
  const items = [
    ['monthly', `Monthly projections: ${scnName(k)}`, () => monthlyCsv(state.results[k].monthlyMean, scnName(k)), `dashuri-monthly-${k}.csv`],
    ['monthly-all', 'Monthly projections: all scenarios', () => SCENARIO_KEYS.map((x) => monthlyCsv(state.results[x].monthlyMean, scnName(x))).join('\n'), 'dashuri-monthly-all.csv'],
    ['comparison', 'Scenario comparison (mean, median, min, max, SD)', () => comparisonCsv(SCENARIO_KEYS.map((x) => state.results[x])), 'dashuri-scenario-comparison.csv'],
    ['assumptions', 'Assumptions with evidence status', () => assumptionsCsv(state.params), 'dashuri-assumptions.csv'],
  ];
  modal.innerHTML = `<div class="modal-panel" role="dialog" aria-label="Export"><div class="drawer-head"><h2>Export CSV</h2><button type="button" class="btn ghost" id="ex-close">Close</button></div>
    <p class="card-note">Download saves a CSV file (in the hosted page you confirm the save first). Copy puts the CSV on your clipboard for pasting into a spreadsheet.</p>
    ${items.map(([id, label]) => `<div class="ex-row"><span>${label}</span><button type="button" class="btn" data-dl="${id}">Download</button><button type="button" class="btn" data-cp="${id}">Copy</button></div>`).join('')}
    <textarea id="ex-text" rows="8" readonly aria-label="CSV preview"></textarea><p id="ex-msg" class="muted"></p></div>`;
  modal.hidden = false;
  document.getElementById('ex-close').onclick = () => { modal.hidden = true; };
  const find = (id) => items.find((x) => x[0] === id);
  modal.querySelectorAll('[data-dl]').forEach((b) => b.addEventListener('click', async () => {
    const [, , make, file] = find(b.dataset.dl);
    const csv = make();
    document.getElementById('ex-text').value = csv;
    const msg = document.getElementById('ex-msg');
    // Hosted page: ask the viewer through the downloads capability.
    if (window.claude && typeof window.claude.use === 'function') {
      let dl = null;
      try { dl = await window.claude.use('downloads'); } catch (e) { dl = null; }
      if (dl) {
        try {
          await dl.save({ filename: file, data: csv });
          msg.textContent = `Saved ${file}.`;
        } catch (e) {
          const code = e && e.code;
          msg.textContent = code === 'declined' ? 'Save cancelled.' : code === 'rate_limited' ? 'A save prompt is already open. Try again in a moment.' : 'Saving is not available here. Use Copy.';
        }
        return;
      }
    }
    // Local file: plain browser download.
    try {
      const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv' }));
      const a = document.createElement('a');
      a.href = url;
      a.download = file;
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
      document.getElementById('ex-msg').textContent = `Download started: ${file}. If nothing happened, use Copy.`;
    } catch (e) {
      document.getElementById('ex-msg').textContent = 'Download blocked here. Use Copy.';
    }
  }));
  modal.querySelectorAll('[data-cp]').forEach((b) => b.addEventListener('click', () => {
    const csv = find(b.dataset.cp)[2]();
    const ta = document.getElementById('ex-text');
    ta.value = csv;
    const done = (ok) => { document.getElementById('ex-msg').textContent = ok ? 'Copied to clipboard.' : 'Copy blocked. The CSV is selected in the box; press Ctrl/Cmd+C.'; };
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(csv).then(() => done(true), () => { ta.select(); done(false); });
    else { ta.select(); done(false); }
  }));
}

// ---------- routing & boot ----------
function route() {
  const h = (location.hash || '').replace('#', '');
  state.page = PAGES.some(([k]) => k === h) ? h : 'overview';
  render();
  const main = document.getElementById('main');
  if (main) main.scrollTop = 0;
}

function boot() {
  try {
    const s = localStorage.getItem('dashuri-scn');
    if (s && ['worst', 'base', 'best', 'compare'].includes(s)) state.scenario = s;
  } catch (e) { /* storage optional */ }
  shell();
  runAll();
  window.addEventListener('hashchange', route);
  let rt;
  let lastW = window.innerWidth;
  window.addEventListener('resize', () => {
    clearTimeout(rt);
    rt = setTimeout(() => {
      if (Math.abs(window.innerWidth - lastW) > 40 && state.page !== 'report') {
        lastW = window.innerWidth;
        render();
      }
    }, 250);
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      document.getElementById('drawer').hidden = true;
      document.getElementById('modal').hidden = true;
    }
  });
  route();
}

boot();
