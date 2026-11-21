// CSV builders shared by the dashboard and the report generator.
import { PARAM_META } from './assumptions.js';

const esc = (v) => {
  if (v === null || v === undefined) return '';
  const s = typeof v === 'number' ? (Number.isInteger(v) ? String(v) : v.toFixed(2)) : String(v);
  return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
};
export const toCsv = (rows) => rows.map((r) => r.map(esc).join(',')).join('\n');

export const MONTHLY_COLUMNS = [
  ['installs', 'Installs'], ['registrations', 'Registrations'], ['eligible', 'Eligible users'],
  ['activeCustomers', 'Active customers'], ['payingCustomers', 'Paying customers'], ['newPayers', 'New payers'],
  ['freeCardUsers', 'Free Call Card users'], ['freeCallsServed', 'Free calls served'], ['freeCallsCompleted', 'Free calls completed'], ['newPayersFromFreeCall', 'Free-to-paid conversions'],
  ['activeHosts', 'Active hosts'], ['newHosts', 'New hosts (KYC)'], ['utilisation', 'Host utilisation'], ['avgRate', 'Avg Diamond rate (D/min)'],
  ['incomingCalls', 'Incoming calls'], ['acceptedCalls', 'Accepted calls'], ['connectedCalls', 'Connected calls'], ['completedCalls', 'Completed paid calls'],
  ['paidMinutes', 'Paid billable minutes'], ['freeCallMinutes', 'Free-call minutes'],
  ['purchases', 'Top-ups'], ['avgTopup', 'Average top-up (₹)'], ['topupGross', 'Top-up cash (₹, incl. GST)'], ['refundGross', 'Refunds (₹)'], ['chargebackGross', 'Chargebacks (₹)'],
  ['diamondsPurchased', 'Diamonds purchased'], ['diamondsConsumed', 'Diamonds consumed'], ['walletDiamonds', 'Unspent purchased Diamonds'],
  ['beansEarnedPaid', 'Beans earned (paid calls)'], ['beansEarnedFree', 'Beans earned (free calls)'], ['beansWithdrawn', 'Beans withdrawn'], ['beansInHold', 'Beans in 7-day hold'], ['beansAvailable', 'Beans withdrawable, not withdrawn'],
  ['grossConsumed', 'Gross value consumed (₹)'], ['gstOnConsumption', 'GST on consumption (₹)'], ['revenue', 'Recognised revenue (₹, ex GST)'],
  ['playFeeExpense', 'Play fee (₹)'], ['hostPaidExpense', 'Host Beans, paid calls (₹)'], ['clawbackRecovery', 'Clawback recovery (₹)'], ['videoPaid', 'Video, paid calls (₹)'], ['moderationPaid', 'Moderation bot, paid (₹)'],
  ['chargebackLoss', 'Chargeback loss (₹)'], ['chargebackFees', 'Chargeback fees (₹)'], ['contribution', 'Contribution, paid calls (₹)'],
  ['freeCallCost', 'Free Call Card cost (₹)'], ['safetyOps', 'Safety operations (₹)'], ['reportReview', 'Report review (₹)'], ['otp', 'OTP (₹)'], ['kyc', 'Host KYC (₹)'], ['payoutFees', 'Payout fees (₹)'], ['fixedInfra', 'Fixed infrastructure (₹)'], ['socialLevy', 'Social levy (₹)'], ['promoHostCost', 'Promo Diamond host cost (₹)'],
  ['opex', 'Operating expenses (₹)'], ['preLaunch', 'Pre-launch one-time (₹)'], ['operatingProfit', 'Operating profit before acquisition (₹)'],
  ['acquisitionSpend', 'Acquisition spend at what-if CAC (₹)'], ['profitAfterAcquisition', 'Profit after acquisition (₹)'],
  ['cashIn', 'Cash in: Google settlements (₹)'], ['cashOutHosts', 'Cash out: host payouts + fees (₹)'], ['cashOutGst', 'Cash out: GST (₹)'], ['cashOutOpex', 'Cash out: operating (₹)'], ['cashOutPreLaunch', 'Cash out: pre-launch (₹)'], ['cashOutAcquisition', 'Cash out: acquisition (₹)'],
  ['netCash', 'Net cash movement (₹)'], ['closingCash', 'Closing cash balance (₹)'], ['minCashInMonth', 'Lowest balance in month (₹)'],
  ['customerLiabilityInr', 'Customer wallet liability (₹, incl. GST)'], ['hostLiabilityInr', 'Host payout liability (₹)'], ['googleReceivable', 'Google receivable at end (₹)'],
];

export function monthlyCsv(monthly, scenarioName) {
  const header = ['Scenario', 'Metric', ...monthly.map((m) => `Month ${m.month}`), 'Six-month total / end'];
  const flowKeys = new Set(['walletDiamonds', 'beansInHold', 'beansAvailable', 'closingCash', 'minCashInMonth', 'customerLiabilityInr', 'hostLiabilityInr', 'googleReceivable', 'activeHosts', 'utilisation', 'avgRate', 'avgTopup', 'activeCustomers', 'payingCustomers']);
  const rows = MONTHLY_COLUMNS.map(([k, label]) => {
    const vals = monthly.map((m) => m[k] ?? 0);
    const agg = flowKeys.has(k) ? vals[vals.length - 1] : vals.reduce((s, x) => s + x, 0);
    return [scenarioName, label, ...vals, agg];
  });
  return toCsv([header, ...rows]);
}

export function assumptionsCsv(scenarios) {
  const keys = Object.keys(PARAM_META);
  const header = ['Parameter', 'Unit', 'Group', 'Evidence', ...Object.values(scenarios).map((s) => s.name), 'Note'];
  const fmt = (v) => (Array.isArray(v) ? v.join(' / ') : v);
  const rows = keys.map((k) => {
    const m = PARAM_META[k];
    return [m.label, m.unit, m.group, m.status, ...Object.values(scenarios).map((s) => fmt(s[k])), m.note || ''];
  });
  rows.push(['Package mix (Starter→Premium)', 'share', 'Spending', 'Hypothesis (no data)', ...Object.values(scenarios).map((s) => s.packageMix.join(' / ')), '']);
  return toCsv([header, ...rows]);
}

export function comparisonCsv(results) {
  const keys = ['topups', 'revenue', 'hostObligations', 'hostPayoutsMade', 'contribution', 'operatingProfit', 'peakFunding', 'closingCash', 'googleReceivable', 'm6ActiveCustomers', 'm6PayingCustomers', 'm6ActiveHosts', 'm6PaidMinutes', 'm6OperatingProfit', 'contributionPerPaidMinute', 'contributionPerPayer', 'breakEvenCacPerInstall', 'm6MedianHostEarning'];
  const header = ['Metric', ...results.flatMap((r) => [`${r.params.name} mean`, `${r.params.name} median`, `${r.params.name} min`, `${r.params.name} max`, `${r.params.name} sd`])];
  const rows = keys.map((k) => [k, ...results.flatMap((r) => {
    const s = r.summaryStats[k];
    return [s.mean, s.median, s.min, s.max, s.sd];
  })]);
  return toCsv([header, ...rows]);
}
