/* Dashuri Reels — six-month incremental financial model (EXPERIMENT).
 *
 * Scenario A = the existing Dashuri finance engine (docs/finance/engine/
 * dashuri-model.js), unchanged. Scenario B = the same engine with explicit
 * Reels levers applied to its inputs, plus Reels operating costs.
 * Incremental = B − A, so calls existing customers would make anyway are
 * never counted as Reels revenue.
 *
 * Pure and deterministic. UMD: window.ReelsModel or require().
 */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.ReelsModel = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  // status: verified (official price checked 22 Nov 2026) | implemented (in the
  // experiment code) | assumption (no data yet — edit freely).
  const A = [];
  function a(key, group, label, unit, values, status, source, ctl) {
    A.push({ key, group, label, unit, values: { conservative: values[0], base: values[1], optimistic: values[2] }, status, source, ...ctl });
  }

  // ---------------------------------------------------------------- usage
  a('adoption', 'Usage', 'MAU who watch Reels in a month', '%', [0.25, 0.45, 0.65], 'assumption', 'No Dashuri data. Short-video tabs in social apps typically reach a large share of actives; deliberately cautious.', { min: 0, max: 1, step: 0.01, pct: true });
  a('viewsPerViewer', 'Usage', 'Reel views per viewer per month', 'views', [60, 120, 250], 'assumption', 'A view = a reel shown long enough to start playing.', { min: 0, max: 1000, step: 5 });
  a('watchSeconds', 'Usage', 'Average watch time per view', 's', [8, 12, 18], 'assumption', 'Reels are 15–60 s; most views are partial.', { min: 1, max: 60, step: 1 });
  a('creatorShare', 'Usage', 'Non-host MAU who post at least one reel', '%', [0.015, 0.03, 0.06], 'assumption', 'Creators are a small minority in every UGC product.', { min: 0, max: 0.3, step: 0.005, pct: true });
  a('reelsPerCreator', 'Usage', 'Reels per regular creator per month', 'reels', [2, 3, 5], 'assumption', '', { min: 0, max: 30, step: 1 });
  a('hostPostingShare', 'Usage', 'Active hosts who post reels', '%', [0.4, 0.7, 0.9], 'assumption', 'Hosts have a direct earnings reason to post.', { min: 0, max: 1, step: 0.05, pct: true });
  a('reelsPerHost', 'Usage', 'Reels per posting host per month', 'reels', [4, 8, 15], 'assumption', '', { min: 0, max: 60, step: 1 });
  a('reelSeconds', 'Usage', 'Average reel length', 's', [35, 30, 28], 'implemented', 'Product rule: 15–60 s (enforced on upload and on the provider-reported duration).', { min: 15, max: 60, step: 1 });
  a('rejectShare', 'Usage', 'Uploads rejected or deleted', '%', [0.15, 0.1, 0.07], 'assumption', 'Rejected/deleted reels are purged after any 90-day evidence hold; storage counted conservatively.', { min: 0, max: 0.6, step: 0.01, pct: true });
  a('hostViewShare', 'Usage', 'Views that are of host reels', '%', [0.3, 0.35, 0.45], 'assumption', 'Hosts post more and rank with an availability boost.', { min: 0, max: 1, step: 0.05, pct: true });

  // ---------------------------------------------------------------- business impact (mapped onto the finance engine)
  a('churnReduction', 'Impact', 'Paying-customer churn reduction (relative)', '%', [0, 0.06, 0.15], 'assumption', 'Applied as payerChurn × (1 − x). Retention is the main hoped-for effect; zero in the conservative case.', { min: 0, max: 0.5, step: 0.01, pct: true });
  a('nonPayerRetentionUplift', 'Impact', 'Non-payer month-to-month retention uplift', 'pts', [0, 0.03, 0.08], 'assumption', 'Added to nonPayerRetention (points).', { min: 0, max: 0.3, step: 0.005, pct: true });
  a('laterConversionUplift', 'Impact', 'Later conversion uplift (non-payer → payer)', '%', [0, 0.1, 0.3], 'assumption', 'Applied as convLater × (1 + x): watching a host before calling. Cross-check with the CTA funnel below.', { min: 0, max: 1, step: 0.01, pct: true });
  a('signupUplift', 'Impact', 'Organic sign-up uplift from shared reels', '%', [0, 0.03, 0.1], 'assumption', 'Applied as organicNewM1 × (1 + x). Shares are links (no share SDK in the MVP).', { min: 0, max: 0.5, step: 0.01, pct: true });
  a('cannibalization', 'Impact', 'Calls per payer lost to time spent on Reels', '%', [0.03, 0, 0], 'assumption', 'Conservative case: Reels distracts from calls. Applied as callsPerPayer × (1 − x).', { min: 0, max: 0.3, step: 0.01, pct: true });
  a('ctaPer1000', 'Impact', 'Call-CTA clicks per 1,000 host-reel views', 'clicks', [2, 6, 12], 'assumption', 'Diagnostic only (does not drive revenue): compare implied attributed calls with measured ones.', { min: 0, max: 100, step: 1 });
  a('ctaToCall', 'Impact', 'Calls started per CTA click', '%', [0.15, 0.25, 0.35], 'assumption', 'Diagnostic only. Attribution rule: call within 30 min of the click, no paid call with that host in the prior 30 days.', { min: 0, max: 1, step: 0.01, pct: true });

  // ---------------------------------------------------------------- costs
  a('muxStoragePerMin', 'Costs', 'Mux storage per stored minute per month (720p, basic)', '$', [0.003, 0.0024, 0.0024], 'verified', 'mux.com/pricing: storage from $0.0024/min/month (720p, first tier). Conservative uses $0.003 (docs table).', { min: 0, max: 0.02, step: 0.0001 });
  a('muxDeliveryPerMin', 'Costs', 'Mux delivery per minute after free minutes (720p)', '$', [0.001, 0.0008, 0.0008], 'verified', 'mux.com/pricing: 720p delivery ~$0.0008/min; docs show $0.001/min — conservative uses that.', { min: 0, max: 0.01, step: 0.0001 });
  a('muxFreeDeliveryMin', 'Costs', 'Mux free delivery minutes per month', 'min', [100000, 100000, 100000], 'verified', 'mux.com/pricing: 100,000 free delivery minutes every month on every plan.', { min: 0, max: 1000000, step: 10000 });
  a('muxCreditUsd', 'Costs', 'Mux pay-as-you-go monthly usage credit', '$', [0, 20, 20], 'verified', 'mux.com/pricing: $20 monthly usage credit on pay-as-you-go. Conservative ignores it.', { min: 0, max: 100, step: 1 });
  a('muxEncodingPerMin', 'Costs', 'Mux encoding per minute (basic quality)', '$', [0, 0, 0], 'verified', 'mux.com/pricing: basic-quality encoding is free; plus is $0.03125/min.', { min: 0, max: 0.1, step: 0.001 });
  a('frameInterval', 'Costs', 'Seconds between moderation frames', 's', [2, 2, 2], 'implemented', 'REELS_MODERATION_FRAME_SECONDS default 2 (Sightengine’s own video default is 1 frame / 2 s).', { min: 1, max: 10, step: 1 });
  a('modelsPerFrame', 'Costs', 'Sightengine models per frame', 'models', [3, 3, 3], 'implemented', 'nudity-2.1, gore-2.0, offensive-2.0 (1 operation per model per frame — Sightengine FAQ).', { min: 1, max: 6, step: 1 });
  a('humanReviewShare', 'Costs', 'Uploads that need a human decision', '%', [0.3, 0.2, 0.15], 'implemented', 'Every creator’s first reel + uncertain/unavailable automated results + reports. Share is an estimate.', { min: 0, max: 1, step: 0.01, pct: true });
  a('reviewCost', 'Costs', 'Cost per human review', '₹', [10, 6, 4], 'assumption', '~1 minute of moderator time. ₹0 cash if the founder reviews (time is not free).', { min: 0, max: 100, step: 1 });
  a('computePer1kViews', 'Costs', 'Extra API/DB cost per 1,000 views', '₹', [3, 1.5, 1], 'assumption', 'Feed + events + signing on Cloud Run/Supabase; no load test yet.', { min: 0, max: 20, step: 0.5 });
  a('supportMonthly', 'Costs', 'Appeals, copyright and support handling per month', '₹', [4000, 2000, 2000], 'assumption', 'Copyright/takedown requests and appeals need a person.', { min: 0, max: 50000, step: 500 });
  a('oneTime', 'Costs', 'One-time: UGC/copyright policy legal review', '₹', [30000, 15000, 15000], 'assumption', 'Licensed-audio and takedown policy before launch (Month 1).', { min: 0, max: 200000, step: 5000 });

  const SCENARIOS = ['conservative', 'base', 'optimistic'];

  function defaults(scenario) {
    const o = {};
    for (const x of A) o[x.key] = x.values[scenario];
    return o;
  }

  /** Finance-engine inputs for Scenario B. */
  function engineOverrides(base, r) {
    return {
      payerChurn: base.payerChurn * (1 - r.churnReduction),
      nonPayerRetention: Math.min(0.98, base.nonPayerRetention + r.nonPayerRetentionUplift),
      convLater: base.convLater * (1 + r.laterConversionUplift),
      organicNewM1: base.organicNewM1 * (1 + r.signupUplift),
      callsPerPayer: base.callsPerPayer * (1 - r.cannibalization),
    };
  }

  /**
   * engine: the finance engine module; financeParams: its params (A);
   * r: Reels assumptions. Returns monthly rows and a summary.
   */
  function run(engine, financeParams, r) {
    const A_ = engine.run(financeParams);
    const pB = Object.assign({}, financeParams, engineOverrides(financeParams, r));
    const B = engine.run(pB);
    const fx = financeParams.usdInr;
    const rows = [];
    let storedMin = 0;
    for (let i = 0; i < A_.months.length; i++) {
      const a0 = A_.months[i], b0 = B.months[i];
      const mau = b0.mau;
      const hosts = b0.activeHosts;
      const viewers = mau * r.adoption;
      const views = viewers * r.viewsPerViewer;
      const watchMin = views * r.watchSeconds / 60;
      const creators = Math.max(0, mau - hosts) * r.creatorShare;
      const uploads = creators * r.reelsPerCreator + hosts * r.hostPostingShare * r.reelsPerHost;
      const published = uploads * (1 - r.rejectShare);
      const uploadMin = uploads * r.reelSeconds / 60;
      storedMin += uploadMin; // rejected media is kept 90 days as evidence: count it all (conservative)
      const deliveryUsd = Math.max(0, watchMin - r.muxFreeDeliveryMin) * r.muxDeliveryPerMin;
      const storageUsd = storedMin * r.muxStoragePerMin;
      const encodingUsd = uploadMin * r.muxEncodingPerMin;
      const muxUsd = Math.max(0, deliveryUsd + storageUsd + encodingUsd - r.muxCreditUsd);
      const framesPerReel = Math.max(1, Math.ceil(r.reelSeconds / r.frameInterval));
      const reelOps = uploads * framesPerReel * r.modelsPerFrame;
      const baseOps = b0.moderationOps; // call moderation already uses the same Sightengine plan
      const sightUsd = engine.sightengineUsd(baseOps + reelOps, financeParams.sightengineMultiplier) - engine.sightengineUsd(baseOps, financeParams.sightengineMultiplier);
      const video = muxUsd * fx;
      const moderationApi = sightUsd * fx;
      const humanReview = uploads * r.humanReviewShare * r.reviewCost;
      const compute = views / 1000 * r.computePer1kViews;
      const support = r.supportMonthly;
      const oneTime = i === 0 ? r.oneTime : 0;
      const reelsVariable = video + moderationApi + humanReview + compute;
      const reelsCost = reelsVariable + support + oneTime;
      const dRevenue = b0.revenueRecognized - a0.revenueRecognized;
      const dContributionEngine = b0.contribution - a0.contribution;
      const dOperatingEngine = b0.operatingProfit - a0.operatingProfit;
      const hostViews = views * r.hostViewShare;
      const ctaClicks = hostViews * r.ctaPer1000 / 1000;
      rows.push({
        month: i + 1,
        mauA: a0.mau, mauB: mau, payersA: a0.payingCustomers, payersB: b0.payingCustomers,
        viewers, views, watchMin, creators, hosts, uploads, published, storedMin,
        hostViews, ctaClicks, impliedAttributedCalls: ctaClicks * r.ctaToCall,
        profileVisits: hostViews * r.ctaPer1000 / 1000 * 3,
        video, moderationApi, humanReview, compute, support, oneTime, reelsVariable, reelsCost,
        reelOps, revenueA: a0.revenueRecognized, revenueB: b0.revenueRecognized, dRevenue,
        dPayers: b0.payingCustomers - a0.payingCustomers,
        dContribution: dContributionEngine - reelsVariable,
        dOperating: dOperatingEngine - reelsCost,
        operatingA: a0.operatingProfit, operatingB: b0.operatingProfit - reelsCost,
        dHostLiability: b0.beanLiability - a0.beanLiability,
        dHostEarnings: b0.hostEarnings - a0.hostEarnings,
        netCashA: a0.netCashFlow, netCashB: b0.netCashFlow - reelsCost,
      });
    }
    const sum = k => rows.reduce((s, x) => s + x[k], 0);
    let cum = 0, minCum = 0, cumA = 0, minA = 0, cumB = 0, minB = 0;
    for (const x of rows) {
      cum += x.netCashB - x.netCashA; minCum = Math.min(minCum, cum);
      cumA += x.netCashA; minA = Math.min(minA, cumA);
      cumB += x.netCashB; minB = Math.min(minB, cumB);
    }
    const views = sum('views'), reelsCost = sum('reelsCost'), reelsVariable = sum('reelsVariable');
    const dRevenue = sum('dRevenue'), dOperating = sum('dOperating');
    const viewersAvg = sum('viewers') / rows.length;
    // Value per view before Reels costs (engine Δ contribution / views).
    const valuePerView = views > 0 ? (sum('dContribution') + reelsVariable) / views : 0;
    const varPerView = views > 0 ? reelsVariable / views : 0;
    const fixed = sum('support') + sum('oneTime');
    const breakEvenViews = valuePerView > varPerView ? fixed / (valuePerView - varPerView) : null;
    const m6 = rows[rows.length - 1];
    const summary = {
      sixMonthReelsCost: reelsCost,
      sixMonthReelsVariable: reelsVariable,
      sixMonthDRevenue: dRevenue,
      sixMonthDContribution: sum('dContribution'),
      sixMonthDOperating: dOperating,
      operatingA: A_.cumOperatingProfit,
      operatingB: A_.cumOperatingProfit + dOperating,
      views, uploads: sum('uploads'), published: sum('published'),
      costPer1000Views: views > 0 ? reelsVariable / views * 1000 : null,
      costPerPublished: sum('published') > 0 ? reelsCost / sum('published') : null,
      dRevenuePerViewer: viewersAvg > 0 ? dRevenue / (viewersAvg * rows.length) : 0,
      contributionMargin: dRevenue > 0 ? sum('dContribution') / dRevenue : null,
      breakEvenViews,
      breakEvenViewsPerMonth: breakEvenViews == null ? null : breakEvenViews / rows.length,
      extraCash: -minCum,
      minCapitalA: -minA, minCapitalB: -minB,
      dHostLiabilityM6: m6.dHostLiability,
      dPayersM6: m6.dPayers,
      m6,
      improves: dOperating > 0,
      // Same Reels assumptions with zero business impact: the pure cost of running Reels.
      verdict: dOperating > 0 ? 'improves' : dOperating > -0.02 * Math.abs(A_.cumOperatingProfit) ? 'neutral' : 'worsens',
    };
    return { A: A_, B, rows, summary, overrides: engineOverrides(financeParams, r) };
  }

  /** Impact needed to cover Reels costs: the churn reduction at which Δ operating ≥ 0. */
  function breakEvenChurnReduction(engine, financeParams, r) {
    let lo = 0, hi = 0.6;
    const at = x => run(engine, financeParams, Object.assign({}, r, { churnReduction: x })).summary.sixMonthDOperating;
    if (at(hi) < 0) return null;
    for (let k = 0; k < 40; k++) { const mid = (lo + hi) / 2; if (at(mid) >= 0) hi = mid; else lo = mid; }
    return hi;
  }

  const COLUMNS = ['month', 'mauA', 'mauB', 'payersA', 'payersB', 'dPayers', 'viewers', 'views', 'watchMin', 'uploads', 'published', 'storedMin',
    'reelOps', 'video', 'moderationApi', 'humanReview', 'compute', 'support', 'oneTime', 'reelsCost', 'revenueA', 'revenueB', 'dRevenue',
    'dContribution', 'dOperating', 'operatingA', 'operatingB', 'dHostEarnings', 'dHostLiability', 'hostViews', 'ctaClicks', 'impliedAttributedCalls'];

  function toCSV(result) {
    const lines = [COLUMNS.join(',')];
    for (const r of result.rows) lines.push(COLUMNS.map(c => (typeof r[c] === 'number' ? Math.round(r[c] * 100) / 100 : r[c])).join(','));
    return lines.join('\n');
  }

  return { ASSUMPTIONS: A, SCENARIOS, defaults, run, engineOverrides, breakEvenChurnReduction, toCSV, COLUMNS };
});
