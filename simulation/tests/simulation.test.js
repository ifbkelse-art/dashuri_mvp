import { test } from 'node:test';
import assert from 'node:assert/strict';
import { simulate } from '../src/engine/simulate.js';
import { runScenario, stats } from '../src/engine/runs.js';
import { DEFAULT_SCENARIOS, SEEDS, cloneScenario } from '../src/engine/assumptions.js';
import { gstIncluded } from '../src/engine/finance.js';

const close = (a, b, eps = 1e-3) => assert.ok(Math.abs(a - b) <= eps * Math.max(1, Math.abs(b)), `${a} != ${b}`);
const base = DEFAULT_SCENARIOS.base;

test('deterministic: same seed and inputs give identical results', () => {
  const a = simulate(base, 42);
  const b = simulate(base, 42);
  assert.deepEqual(a.summary, b.summary);
  assert.deepEqual(a.balance, b.balance);
});

test('different seeds give different results', () => {
  const a = simulate(base, 1);
  const b = simulate(base, 2);
  assert.notEqual(a.summary.topups, b.summary.topups);
});

for (const key of ['worst', 'base', 'best']) {
  test(`${key}: Diamond wallet reconciles (purchased − refunded − consumed = closing wallet)`, () => {
    const r = simulate(DEFAULT_SCENARIOS[key], SEEDS[key][0]);
    const { cumPurchasedD, cumRefundD, cumConsumedPurchasedD } = r.recon;
    close(cumPurchasedD - cumRefundD - cumConsumedPurchasedD, r.months[5].walletDiamonds, 1e-6);
  });

  test(`${key}: Bean ledger reconciles (earned − clawed back − withdrawn = held + available)`, () => {
    const r = simulate(DEFAULT_SCENARIOS[key], SEEDS[key][0]);
    const { cumBeansEarned, cumBeansClawed, cumBeansWithdrawn } = r.recon;
    const m6 = r.months[5];
    close(cumBeansEarned - cumBeansClawed - cumBeansWithdrawn, m6.beansInHold + m6.beansAvailable, 1e-6);
  });

  test(`${key}: revenue never exceeds top-ups net of GST (no recognising unspent Diamonds)`, () => {
    const r = simulate(DEFAULT_SCENARIOS[key], SEEDS[key][0]);
    const netTopups = r.totals.topupGross - r.totals.refundGross;
    assert.ok(r.totals.grossConsumed <= netTopups + 1e-6);
    assert.ok(r.totals.revenue <= netTopups / 1.18 + 1);
    // unspent value + consumed gross = net top-ups (pooled wallet value)
    close(r.totals.grossConsumed + r.months[5].walletValueGross, netTopups, 1e-6);
  });

  test(`${key}: monthly P&L lines add up (no double counting)`, () => {
    const r = simulate(DEFAULT_SCENARIOS[key], SEEDS[key][0]);
    for (const m of r.months) {
      close(m.revenue, m.grossConsumed - m.gstOnConsumption, 1e-9);
      const contrib = m.revenue - m.playFeeExpense - m.hostPaidExpense + m.clawbackRecovery - m.videoPaid - m.moderationPaid - m.chargebackLoss - m.chargebackFees;
      close(m.contribution, contrib, 1e-9);
      close(m.operatingProfit, m.contribution - m.freeCallCost - m.opex - m.preLaunch, 1e-9);
      close(m.freeCallHostCost, m.beansEarnedFree * 0.005, 1e-9);
    }
  });

  test(`${key}: cash balance equals the sum of daily cash movements`, () => {
    const r = simulate(DEFAULT_SCENARIOS[key], SEEDS[key][0]);
    const net = r.months.reduce((s, m) => s + m.netCash, 0);
    close(net, r.balance[r.balance.length - 1], 1e-6);
    close(r.summary.peakFunding, -Math.min(0, ...r.balance), 1e-9);
  });
}

test('free-call host cost is ₹10 per completed free call and capped at 20 per host per day', () => {
  const r = simulate(base, 7);
  for (const m of r.months) {
    close(m.freeCallHostCost, m.freeCallsCompleted * 10, 1e-6);
    assert.ok(m.freeCallsServed <= m.activeHosts * 20 * 30);
  }
});

test('host payouts happen only on weekly days and respect the ₹500 minimum', () => {
  const r = simulate(base, 11);
  for (const h of r.hosts) assert.ok(h.withdrawnInr === 0 || h.withdrawnInr >= 500 - 1e-9);
  // first payout cannot happen before the 7-day hold: no host cash before day 7
  for (let d = 0; d < 7; d++) assert.equal(r.dayLog[d].hosts, 0);
});

test('Google settlement for Month 1 arrives on day 15 of Month 2 plus transit', () => {
  const p = { ...cloneScenario(base), preLaunchInr: 0 };
  const r = simulate(p, 3);
  const day = 30 + 14 + p.bankTransitDays; // index of the settlement day
  assert.ok(r.dayLog[day].inflow !== 0);
  for (let d = 0; d < day; d++) assert.equal(r.dayLog[d].inflow, 0);
});

test('Google-remits GST mode: no GST cash out; Dashuri mode: GST paid on top-ups', () => {
  const g = simulate({ ...cloneScenario(base), gstMode: 'google' }, 5);
  assert.equal(g.months.reduce((s, m) => s + m.cashOutGst, 0), 0);
  const d = simulate({ ...cloneScenario(base), gstMode: 'dashuri', chargebackRate: 0 }, 5);
  const m1 = d.months[0];
  const m1NetTopups = m1.topupGross - m1.refundGross;
  close(m1.gstPayable, gstIncluded(m1NetTopups), 1e-6);
});

test('higher Play fee lowers six-month operating profit', () => {
  const lo = runScenario({ ...cloneScenario(base), playFeeRate: 0.15 }, SEEDS.base).summaryStats.operatingProfit.mean;
  const hi = runScenario({ ...cloneScenario(base), playFeeRate: 0.3 }, SEEDS.base).summaryStats.operatingProfit.mean;
  assert.ok(hi < lo);
});

test('stats helper', () => {
  const s = stats([1, 2, 3, 4, 100]);
  assert.equal(s.median, 3);
  assert.equal(s.min, 1);
  assert.equal(s.max, 100);
  assert.equal(s.mean, 22);
});

test('five seeds per scenario', () => {
  for (const k of Object.keys(SEEDS)) assert.ok(SEEDS[k].length >= 5);
});
