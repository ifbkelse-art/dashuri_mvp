// Pure financial formulas. No randomness. Unit-tested in tests/finance.test.js.
import { CONSTANTS } from './assumptions.js';

const C = CONSTANTS;

/** Beans earned for Diamonds spent: 16,670 D = 10,000 Beans (exact ratio, no early rounding). */
export function beansForDiamonds(diamonds) {
  return (diamonds * C.beansPerDiamondNumerator) / C.beansPerDiamondDenominator;
}

/** INR value of Beans. */
export function beansToInr(beans, inrPerBean = C.inrPerBean) {
  return beans * inrPerBean;
}

/** Host payout liability in INR for Diamonds spent. */
export function hostInrForDiamonds(diamonds, inrPerBean = C.inrPerBean) {
  return beansToInr(beansForDiamonds(diamonds), inrPerBean);
}

/**
 * Per-second proportional billing. Charge computed once at call end and rounded
 * down (in the customer's favour). Paused seconds are not billable.
 */
export function diamondsCharged(ratePerMinute, billableSeconds) {
  if (billableSeconds <= 0) return 0;
  return Math.floor((ratePerMinute * billableSeconds) / 60);
}

/** Billable seconds = connected seconds minus qualifying paused seconds. */
export function billableSeconds(connectedSeconds, pausedSeconds) {
  return Math.max(0, connectedSeconds - pausedSeconds);
}

/** GST contained in a GST-inclusive amount. */
export function gstIncluded(grossInclusive, rate = C.gstRate) {
  return (grossInclusive * rate) / (1 + rate);
}

/** Play fee on a purchase. feeBase 'net' = on GST-exclusive price; 'gross' = on price paid. */
export function playFee(gross, { playFeeRate = 0.15, feeBase = 'net', gstRate = C.gstRate } = {}) {
  const base = feeBase === 'gross' ? gross : gross / (1 + gstRate);
  return base * playFeeRate;
}

/**
 * GST attributable to a block of consumed Diamonds.
 * mode 'dashuri' or 'google': principal model, GST on the full price.
 * mode 'agent': hypothetical; GST only on Dashuri's margin (price minus host share). Needs CA review.
 */
export function gstForConsumption(grossConsumed, hostInr, mode = 'dashuri', rate = C.gstRate) {
  if (mode === 'agent') return gstIncluded(Math.max(0, grossConsumed - hostInr), rate);
  return gstIncluded(grossConsumed, rate);
}

/**
 * Unit economics of one package spent entirely at one host rate.
 * Returns every line so the dashboard can render the waterfall.
 */
export function packageWaterfall(pkg, opts = {}) {
  const {
    rate = 4000,
    inrPerBean = C.inrPerBean,
    playFeeRate = 0.15,
    feeBase = 'net',
    gstMode = 'dashuri',
    fxInrPerUsd = 88,
    videoUsdPer1000 = 1.5,
    participants = 2,
    moderationUsdPerFrame = 0.0015,
    moderationFramesPerMin = 6,
    moderationStreams = 2,
    moderationMinutes = 3,
    avgCallMin = 4.5,
    reservePct = 0.05,
  } = opts;
  const P = pkg.price;
  const D = pkg.diamonds;
  const minutes = D / rate;
  const host = hostInrForDiamonds(D, inrPerBean);
  const gst = gstForConsumption(P, host, gstMode);
  const net = P - gst;
  const fee = playFee(P, { playFeeRate, feeBase });
  const video = minutes * participants * (videoUsdPer1000 / 1000) * fxInrPerUsd;
  const calls = minutes / avgCallMin;
  const modMinutesPerCall = Math.min(avgCallMin, moderationMinutes);
  const moderation = calls * modMinutesPerCall * moderationFramesPerMin * moderationStreams * moderationUsdPerFrame * fxInrPerUsd;
  const reserve = net * reservePct;
  const contribution = net - fee - host - video - moderation - reserve;
  return {
    price: P, diamonds: D, rate, minutes, pricePerMinute: P / minutes,
    gst, net, fee, host, video, moderation, reserve, contribution,
    contributionPct: contribution / P, hostPct: host / P,
    beans: beansForDiamonds(D),
  };
}

/** Contribution per paid minute at a given average gross price per Diamond. */
export function contributionPerMinute({ grossPerDiamond, rate, inrPerBean = C.inrPerBean, playFeeRate = 0.15, feeBase = 'net', gstMode = 'dashuri', videoInrPerMin = 0, moderationInrPerMin = 0, lossPct = 0 }) {
  const gross = grossPerDiamond * rate;
  const host = hostInrForDiamonds(rate, inrPerBean);
  const gst = gstForConsumption(gross, host, gstMode);
  const net = gross - gst;
  const fee = playFee(gross, { playFeeRate, feeBase });
  return net - fee - host - videoInrPerMin - moderationInrPerMin - net * lossPct;
}

/**
 * Break-even from a steady state: fixed monthly cost and contribution per paid minute.
 * Returns null fields when no break-even exists (contribution per minute <= 0).
 */
export function breakEven({ fixedMonthly, contributionPerPaidMinute, minutesPerPayer, avgCallMin, revenuePerMinute }) {
  if (!(contributionPerPaidMinute > 0)) {
    return { exists: false, minutes: null, payers: null, dailyCalls: null, revenue: null };
  }
  const minutes = fixedMonthly / contributionPerPaidMinute;
  return {
    exists: true,
    minutes,
    payers: minutesPerPayer > 0 ? minutes / minutesPerPayer : null,
    dailyCalls: avgCallMin > 0 ? minutes / C.daysPerMonth / avgCallMin : null,
    revenue: minutes * revenuePerMinute,
  };
}

/** Level (1-based) for an XP total. */
export function levelForXp(xp, thresholds) {
  let level = 1;
  for (let i = 0; i < thresholds.length; i++) if (xp >= thresholds[i]) level = i + 1;
  return level;
}

/** XP = 8 × eligible Diamonds purchased + eligible Beans earned. */
export function xpFor(diamondsPurchased, beansEarned) {
  return 8 * diamondsPurchased + beansEarned;
}

/** Max permitted host rate at a level for a ladder, clamped to the founder's 500–10,000 range. */
export function maxRateForLevel(level, ladderMax) {
  const v = ladderMax[Math.min(level, ladderMax.length) - 1];
  return Math.min(C.maxRate, Math.max(C.minRate, v));
}
