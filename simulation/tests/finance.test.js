import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  beansForDiamonds, beansToInr, hostInrForDiamonds, diamondsCharged, billableSeconds, gstIncluded, playFee,
  gstForConsumption, packageWaterfall, breakEven, levelForXp, xpFor, maxRateForLevel, contributionPerMinute,
} from '../src/engine/finance.js';
import { DEFAULT_PACKAGES, DEFAULT_XP_THRESHOLDS, RATE_LADDERS } from '../src/engine/assumptions.js';

const close = (a, b, eps = 1e-6) => assert.ok(Math.abs(a - b) < eps, `${a} != ${b}`);

test('16,670 Diamonds spent = 10,000 Beans (exact, founder decision)', () => {
  close(beansForDiamonds(16670), 10000);
  close(beansForDiamonds(33340), 20000);
  close(beansForDiamonds(1), 10000 / 16670);
});

test('10,000 Beans = ₹50 at ₹0.005 per Bean', () => {
  close(beansToInr(10000), 50);
  close(hostInrForDiamonds(16670), 50);
  close(hostInrForDiamonds(1), 50 / 16670); // ≈ ₹0.0029994
});

test('₹500 minimum withdrawal = 100,000 Beans', () => {
  close(beansToInr(100000), 500);
});

test('per-second billing at 4,000 D/min matches founder examples, rounded in customer favour', () => {
  assert.equal(diamondsCharged(4000, 15), 1000);
  assert.equal(diamondsCharged(4000, 30), 2000);
  assert.equal(diamondsCharged(4000, 45), 3000);
  assert.equal(diamondsCharged(4000, 60), 4000);
  assert.equal(diamondsCharged(4000, 65), 4333); // 4,333.33 rounded down
  assert.equal(diamondsCharged(4000, 0), 0);
});

test('paused seconds are not billable; failed connection costs nothing', () => {
  assert.equal(billableSeconds(300, 20), 280);
  assert.equal(diamondsCharged(3000, billableSeconds(300, 20)), 14000);
  assert.equal(diamondsCharged(3000, billableSeconds(0, 0)), 0);
  assert.equal(billableSeconds(10, 30), 0);
});

test('GST contained in a GST-inclusive price', () => {
  close(gstIncluded(1180), 180);
  close(gstIncluded(1199), (1199 * 18) / 118);
});

test('Play fee on net-of-GST vs gross base', () => {
  close(playFee(1180, { playFeeRate: 0.15, feeBase: 'net' }), 150);
  close(playFee(1180, { playFeeRate: 0.15, feeBase: 'gross' }), 177);
  close(playFee(1180, { playFeeRate: 0.3, feeBase: 'net' }), 300);
});

test('agent-model GST applies only to the margin above host share', () => {
  close(gstForConsumption(1180, 180, 'agent'), (1000 * 18) / 118);
  close(gstForConsumption(1180, 180, 'dashuri'), 180);
  close(gstForConsumption(1180, 180, 'google'), 180);
});

test('₹1,199 pack waterfall reconciles line by line', () => {
  const w = packageWaterfall(DEFAULT_PACKAGES[3], { rate: 4000, moderationUsdPerFrame: 0.0015, avgCallMin: 4.5 });
  close(w.gst, 182.8983, 1e-3);
  close(w.net, 1016.1017, 1e-3);
  close(w.fee, 152.4153, 1e-3);
  close(w.host, 54000 * 50 / 16670, 1e-9); // ₹161.97
  close(w.minutes, 13.5);
  close(w.video, 13.5 * 2 * 0.0015 * 88, 1e-9);
  const sumLines = w.gst + w.fee + w.host + w.video + w.moderation + w.reserve + w.contribution;
  close(sumLines, 1199, 1e-6);
  assert.ok(w.hostPct > 0.13 && w.hostPct < 0.14);
});

test('break-even returns no result when contribution per minute is not positive', () => {
  const none = breakEven({ fixedMonthly: 50000, contributionPerPaidMinute: -1, minutesPerPayer: 10, avgCallMin: 4, revenuePerMinute: 30 });
  assert.equal(none.exists, false);
  const be = breakEven({ fixedMonthly: 50000, contributionPerPaidMinute: 20, minutesPerPayer: 10, avgCallMin: 5, revenuePerMinute: 30 });
  assert.equal(be.exists, true);
  close(be.minutes, 2500);
  close(be.payers, 250);
  close(be.dailyCalls, 2500 / 30 / 5);
  close(be.revenue, 75000);
});

test('XP formula and levels', () => {
  assert.equal(xpFor(1000, 0), 8000);
  assert.equal(xpFor(10000, 10000), 90000);
  assert.equal(levelForXp(0, DEFAULT_XP_THRESHOLDS), 1);
  assert.equal(levelForXp(31999, DEFAULT_XP_THRESHOLDS), 1);
  assert.equal(levelForXp(32000, DEFAULT_XP_THRESHOLDS), 2);
  assert.equal(levelForXp(40000000, DEFAULT_XP_THRESHOLDS), 10);
});

test('rate ladders stay inside founder 500–10,000 range', () => {
  for (const key of Object.keys(RATE_LADDERS)) {
    for (let l = 1; l <= 10; l++) {
      const r = maxRateForLevel(l, RATE_LADDERS[key].max);
      assert.ok(r >= 500 && r <= 10000);
    }
  }
});

test('contribution per minute is consistent with the package waterfall (no reserve, no moderation)', () => {
  const pkg = DEFAULT_PACKAGES[3];
  const w = packageWaterfall(pkg, { rate: 4000, moderationUsdPerFrame: 0, reservePct: 0, videoUsdPer1000: 0 });
  const cpm = contributionPerMinute({ grossPerDiamond: pkg.price / pkg.diamonds, rate: 4000 });
  close(cpm * w.minutes, w.contribution, 1e-6);
});
