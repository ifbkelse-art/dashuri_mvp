// Multi-seed runs, statistics and sensitivity analysis.
import { simulate } from './simulate.js';
import { cloneScenario } from './assumptions.js';

export function stats(values) {
  const v = values.filter((x) => Number.isFinite(x)).slice().sort((a, b) => a - b);
  const n = v.length;
  if (!n) return { n: 0, mean: NaN, median: NaN, min: NaN, max: NaN, sd: NaN };
  const mean = v.reduce((s, x) => s + x, 0) / n;
  const median = n % 2 ? v[(n - 1) / 2] : (v[n / 2 - 1] + v[n / 2]) / 2;
  const sd = n > 1 ? Math.sqrt(v.reduce((s, x) => s + (x - mean) ** 2, 0) / (n - 1)) : 0;
  return { n, mean, median, min: v[0], max: v[n - 1], sd, cv: mean !== 0 ? sd / Math.abs(mean) : 0 };
}

export const SUMMARY_KEYS = [
  'topups', 'revenue', 'hostObligations', 'hostPayoutsMade', 'contribution', 'operatingProfit', 'profitAfterAcquisition',
  'peakFunding', 'closingCash', 'googleReceivable', 'm6ActiveCustomers', 'm6PayingCustomers', 'm6ActiveHosts', 'm6PaidMinutes',
  'm6OperatingProfit', 'm6Utilisation', 'm6AvgRate', 'contributionPerPaidMinute', 'contributionPerPayer', 'uniquePayers',
  'breakEvenCacPerInstall', 'm6MedianHostEarning', 'm6WalletLiability', 'm6HostLiability',
];

/** Run one scenario over several seeds; returns per-seed runs, summary stats, and mean monthly series. */
export function runScenario(params, seeds) {
  const runs = seeds.map((s) => simulate(params, s));
  const summaryStats = {};
  for (const k of SUMMARY_KEYS) summaryStats[k] = stats(runs.map((r) => r.summary[k]));
  const monthKeys = Object.keys(runs[0].months[0]).filter((k) => typeof runs[0].months[0][k] === 'number');
  const monthlyMean = runs[0].months.map((_, i) => {
    const o = { month: i + 1 };
    for (const k of monthKeys) o[k] = runs.reduce((s, r) => s + r.months[i][k], 0) / runs.length;
    o.purchasesByPackage = runs[0].months[i].purchasesByPackage.map((_, j) => runs.reduce((s, r) => s + r.months[i].purchasesByPackage[j], 0) / runs.length);
    return o;
  });
  const monthlyRange = runs[0].months.map((_, i) => {
    const o = {};
    for (const k of ['operatingProfit', 'revenue', 'contribution', 'payingCustomers', 'paidMinutes', 'closingCash']) {
      const s = stats(runs.map((r) => r.months[i][k]));
      o[k] = { min: s.min, max: s.max };
    }
    return o;
  });
  const balanceMean = runs[0].balance.map((_, d) => runs.reduce((s, r) => s + r.balance[d], 0) / runs.length);
  const balanceMin = runs[0].balance.map((_, d) => Math.min(...runs.map((r) => r.balance[d])));
  const reachesBreakEven = runs.filter((r) => r.summary.reachesMonthlyBreakEven).length;
  return { params, seeds, runs, summaryStats, monthlyMean, monthlyRange, balanceMean, balanceMin, reachesBreakEven };
}

/** Variables for one-at-a-time sensitivity. Each returns a modified copy of the params. */
export const SENSITIVITY_VARS = [
  { key: 'installsM1', label: 'Installs (paying-customer volume)', influence: 'Founder', lo: (p) => ({ installsM1: p.installsM1 * 0.5 }), hi: (p) => ({ installsM1: p.installsM1 * 1.5 }), loLabel: '−50%', hiLabel: '+50%' },
  { key: 'cacPerInstall', label: 'Acquisition cost per install', influence: 'Founder / market', lo: () => ({ cacPerInstall: 0 }), hi: () => ({ cacPerInstall: 15 }), loLabel: '₹0', hiLabel: '₹15 (what-if)' },
  { key: 'freeToPaidRate', label: 'Free-to-paid conversion', influence: 'Product', lo: (p) => ({ freeToPaidRate: p.freeToPaidRate * 0.5 }), hi: (p) => ({ freeToPaidRate: p.freeToPaidRate * 1.5 }), loLabel: '−50%', hiLabel: '+50%' },
  { key: 'payerRetention', label: 'Monthly repeat purchase rate', influence: 'Product', lo: (p) => ({ payerRetention: Math.max(0, p.payerRetention - 0.1) }), hi: (p) => ({ payerRetention: Math.min(0.95, p.payerRetention + 0.1) }), loLabel: '−10 pts', hiLabel: '+10 pts' },
  { key: 'packageMix', label: 'Average top-up (package mix)', influence: 'Pricing', lo: () => ({ packageMix: [0.5, 0.3, 0.12, 0.06, 0.02, 0] }), hi: () => ({ packageMix: [0.15, 0.25, 0.25, 0.2, 0.1, 0.05] }), loLabel: 'Small-pack heavy', hiLabel: 'Large-pack heavy' },
  { key: 'purchasesPerPayer', label: 'Top-ups per payer per month', influence: 'Product', lo: (p) => ({ purchasesPerPayer: Math.max(1, p.purchasesPerPayer - 0.3) }), hi: (p) => ({ purchasesPerPayer: p.purchasesPerPayer + 0.3 }), loLabel: '−0.3', hiLabel: '+0.3' },
  { key: 'walletBurnPerDay', label: 'Diamonds consumed (wallet burn)', influence: 'Product', lo: (p) => ({ walletBurnPerDay: p.walletBurnPerDay * 0.5 }), hi: (p) => ({ walletBurnPerDay: Math.min(0.5, p.walletBurnPerDay * 1.5) }), loLabel: '−50%', hiLabel: '+50%' },
  { key: 'ladder', label: 'Host rate ladder', influence: 'Founder', lo: () => ({ ladder: 'C' }), hi: () => ({ ladder: 'B' }), loLabel: 'C narrow', hiLabel: 'B fast' },
  { key: 'hostDailyAvailability', label: 'Host availability (utilisation)', influence: 'Hosts', lo: (p) => ({ hostDailyAvailability: p.hostDailyAvailability * 0.6 }), hi: (p) => ({ hostDailyAvailability: Math.min(1, p.hostDailyAvailability * 1.3) }), loLabel: '−40%', hiLabel: '+30%' },
  { key: 'avgPaidCallMin', label: 'Average paid call length', influence: 'Product', lo: (p) => ({ avgPaidCallMin: p.avgPaidCallMin * 0.6 }), hi: (p) => ({ avgPaidCallMin: p.avgPaidCallMin * 1.4 }), loLabel: '−40%', hiLabel: '+40%' },
  { key: 'videoUsdPer1000', label: 'Video price', influence: 'External', lo: () => ({ videoUsdPer1000: 0.75 }), hi: () => ({ videoUsdPer1000: 3.0 }), loLabel: 'SD $0.75', hiLabel: 'Full HD $3.00' },
  { key: 'playFeeRate', label: 'Google Play fee', influence: 'External', lo: () => ({ playFeeRate: 0.15 }), hi: () => ({ playFeeRate: 0.3 }), loLabel: '15%', hiLabel: '30%' },
  { key: 'gstMode', label: 'GST treatment', influence: 'External (CA)', lo: () => ({ gstMode: 'dashuri' }), hi: () => ({ gstMode: 'agent' }), loLabel: 'Principal', hiLabel: 'Agent (hyp.)' },
  { key: 'inrPerBean', label: 'Host payout conversion (Bean value)', influence: 'Founder', lo: () => ({ inrPerBean: 0.006 }), hi: () => ({ inrPerBean: 0.004 }), loLabel: '₹0.006', hiLabel: '₹0.004' },
  { key: 'chargebackRate', label: 'Refund & fraud rate', influence: 'Partly founder', lo: (p) => ({ chargebackRate: p.chargebackRate * 2, refundRate: p.refundRate * 2 }), hi: (p) => ({ chargebackRate: p.chargebackRate * 0.5, refundRate: p.refundRate * 0.5 }), loLabel: '×2', hiLabel: '×0.5' },
  { key: 'moderationUsdPerFrame', label: 'Moderation cost', influence: 'Founder (vendor)', lo: () => ({ moderationUsdPerFrame: 0.004, safetyOpsMonthlyInr: 30000 }), hi: () => ({ moderationUsdPerFrame: 0, safetyOpsMonthlyInr: 10000 }), loLabel: 'High', hiLabel: 'Low' },
  { key: 'fixedInfra', label: 'Fixed infrastructure', influence: 'Founder', lo: (p) => ({ supabaseUsd: p.supabaseUsd * 2, cloudRunUsd: p.cloudRunUsd * 3, otherFixedInr: p.otherFixedInr * 2 }), hi: (p) => ({ cloudRunUsd: 0, otherFixedInr: p.otherFixedInr * 0.5 }), loLabel: 'High', hiLabel: 'Low' },
];

/** One-at-a-time sensitivity on a metric (default: six-month operating profit). */
export function sensitivity(params, seeds, metric = 'operatingProfit', vars = SENSITIVITY_VARS) {
  const base = runScenario(params, seeds).summaryStats[metric].mean;
  const rows = vars.map((v) => {
    const lo = runScenario({ ...cloneScenario(params), ...v.lo(params) }, seeds).summaryStats[metric].mean;
    const hi = runScenario({ ...cloneScenario(params), ...v.hi(params) }, seeds).summaryStats[metric].mean;
    return { key: v.key, label: v.label, influence: v.influence, loLabel: v.loLabel, hiLabel: v.hiLabel, lo, hi, swing: Math.abs(hi - lo) };
  });
  rows.sort((a, b) => b.swing - a.swing);
  return { metric, base, rows };
}
