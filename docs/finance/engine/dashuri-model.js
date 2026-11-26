/*
 * Dashuri six-month financial model — calculation engine.
 *
 * Pure, deterministic functions. No DOM, no I/O, no randomness. The same file
 * runs in Node (build/export/tests) and is inlined into the HTML simulator,
 * so every number on the dashboard comes from these equations.
 *
 * Business rules below are copied from the implementation, not invented:
 *   - backend/internal/modules/economy/rules.go            (Founder() rule set)
 *   - supabase/migrations/20261117000300_economy_and_ledger.sql (rule_sets seed)
 *   - supabase/migrations/20261121000100_mvp_foundation.sql     (diamond_packages seed)
 *   - backend/internal/modules/calls/{settle.go,timeline.go}   (settlement)
 *   - backend/internal/modules/purchases/service.go            (refund reversal)
 *   - docs/mvp/MVP_DECISIONS_AND_CONTRACT.md §2.5              (moderation frames)
 *
 * Money is in rupees (₹) unless a name says paise. Diamonds (D) and Beans (B)
 * are counts.
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.DashuriModel = api;
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  // ------------------------------------------------------------------ RULES
  // Implemented economy (rule set '2026-11-17-founder'). Not editable in the
  // simulator's base case: changing these means changing the product.
  const RULES = Object.freeze({
    ruleSetVersion: '2026-11-17-founder',
    beansNumerator: 10000,          // 16,670 Diamonds spent = 10,000 Beans
    diamondsDenominator: 16670,
    paisePerBean: 0.5,              // 1 Bean = ½ paisa = ₹0.005
    minRatePerMinute: 500,          // host rate range, D/min
    maxRatePerMinute: 10000,
    defaultRatePerMinute: 500,      // hosting.host_profiles default
    levelRateCaps: null,            // ladder UNRESOLVED: any host may set up to 10,000
    freeCallSeconds: 60,
    freeCallHostCompPaise: 1000,    // ₹10 = 2,000 Beans, only for a full minute
    freeCallMaxPerHostPerDay: 20,
    beanHoldDays: 7,
    minWithdrawalPaise: 50000,      // ₹500
    promoDiamondTtlDays: 30,
    minStartBalanceSeconds: 60,
    lowBalanceWarnSeconds: 30,
    interruptionThresholdSeconds: 10,
    spendOrder: 'promotional_first',
    moderationWindowSeconds: 180,   // nudity checks during the first 3 minutes
    moderationFrameIntervalSeconds: 20, // each participant, own camera
    payoutsEnabled: false,          // PAYOUTS_ENABLED=false (R3-7)
    cashfreeEnabled: false,         // CASHFREE_ENABLED=false
    gstIncludedInPrice: true        // migration comment: "Prices include GST"
  });

  // economy.diamond_packages seed — provisional (design D-14), GST-inclusive.
  const PACKAGES = Object.freeze([
    { id: 'diamonds_4000',   label: 'Starter', diamonds: 4000,   pricePaise: 9900 },
    { id: 'diamonds_12500',  label: 'Small',   diamonds: 12500,  pricePaise: 29900 },
    { id: 'diamonds_26000',  label: 'Medium',  diamonds: 26000,  pricePaise: 59900 },
    { id: 'diamonds_54000',  label: 'Popular', diamonds: 54000,  pricePaise: 119900 },
    { id: 'diamonds_140000', label: 'Large',   diamonds: 140000, pricePaise: 299900 },
    { id: 'diamonds_290000', label: 'Premium', diamonds: 290000, pricePaise: 599900 }
  ]);

  // Exact integer rules, mirroring rules.go (used by the reconciliation tests).
  const exact = {
    diamondsForSeconds: (rate, seconds) => (seconds <= 0 || rate <= 0) ? 0 : Math.floor(rate * seconds / 60),
    beansForDiamonds: (d) => Math.floor(d * RULES.beansNumerator / RULES.diamondsDenominator),
    paiseForBeans: (b) => Math.floor(b * 1 / 2),
    beansForPaise: (p) => p * 2,
    secondsAffordable: (bal, rate) => (rate <= 0 || bal <= 0) ? 0 : Math.floor(bal * 60 / rate),
    canStartCall: (bal, rate) => exact.secondsAffordable(bal, rate) >= RULES.minStartBalanceSeconds,
    framesPerParticipant: (callSeconds) => Math.floor(Math.min(callSeconds, RULES.moderationWindowSeconds) / RULES.moderationFrameIntervalSeconds),
    reversalAmount: (purchaseDiamonds, purchased, promotional, reserved) => {
      const committed = Math.max(reserved - promotional, 0);
      return Math.max(Math.min(purchaseDiamonds, purchased - committed), 0);
    }
  };

  // Continuous equivalents used in the monthly aggregate model.
  const BEANS_PER_DIAMOND = RULES.beansNumerator / RULES.diamondsDenominator; // 0.59988
  const HOST_RUPEES_PER_DIAMOND = BEANS_PER_DIAMOND * RULES.paisePerBean / 100; // ₹0.0029994
  const FREE_CALL_COMP_RUPEES = RULES.freeCallHostCompPaise / 100;             // ₹10

  // ------------------------------------------------------------ ASSUMPTIONS
  // status: code (read from the implementation) · verified (official source,
  // date given) · unverified (third-party or partial source) · estimate (no
  // data; reasoned) · placeholder (get a quote) · decision (founder setting).
  // v = [conservative, base, optimistic]
  const A = [];
  function a(key, group, label, unit, v, status, confidence, source, why, ctl) {
    A.push(Object.assign({ key, group, label, unit, values: { conservative: v[0], base: v[1], optimistic: v[2] }, status, confidence, source, why }, ctl || {}));
  }

  // Acquisition
  a('organicNewM1', 'Acquisition', 'Organic registrations in Month 1', 'users', [500, 1200, 2500], 'estimate', 'low',
    'No install or registration data exists.', 'A new 18+ video-chat app with no brand and no paid push. 1,200 OTP-verified sign-ups in month one needs active community seeding by the founder.', { min: 0, max: 50000, step: 100, sim: true, simLabel: 'Organic sign-ups, Month 1' });
  a('organicGrowth', 'Acquisition', 'Organic registration growth per month', '%/mo', [0.06, 0.15, 0.25], 'estimate', 'low',
    'No data.', 'Word of mouth and store ranking compound slowly without paid installs; 15% is a modest base.', { min: -0.5, max: 1, step: 0.01, pct: true, sim: true });
  a('marketingBudget', 'Acquisition', 'Paid marketing budget per month', '₹/mo', [15000, 15000, 15000], 'decision', 'high',
    'Founder-controlled discretionary spend.', 'Kept equal across scenarios so the scenario gap shows market response, not spend. Set to 0 to test organic only.', { min: 0, max: 1000000, step: 1000, sim: true });
  a('cac', 'Acquisition', 'Paid cost per verified registration (CAC)', '₹', [120, 70, 45], 'estimate', 'low',
    'No campaign data. Cost per OTP-verified 18+ sign-up, not per install.', 'Indian social-app installs are cheap, but only ~55–65% of installs finish phone OTP, and 18+ dating/social categories carry ad restrictions that lift CPMs.', { min: 5, max: 1000, step: 5, sim: true });
  a('eligibleShare', 'Acquisition', 'Registrations that pass 18+ and account checks', '%', [0.92, 0.95, 0.96], 'estimate', 'medium',
    'Age gate and account checks are implemented (identity module).', 'Most adults pass; a few are blocked as minors or abandon onboarding.', { min: 0.5, max: 1, step: 0.01, pct: true });
  a('spikeMonth', 'Acquisition', 'Usage spike month (stress test)', 'month', [0, 0, 0], 'decision', 'high', 'Stress-test control.', '0 = no spike.', { min: 0, max: 6, step: 1 });
  a('spikeMultiplier', 'Acquisition', 'Usage spike: × registrations that month', '×', [1, 1, 1], 'decision', 'high', 'Stress-test control.', 'Used for the 10× usage test.', { min: 1, max: 20, step: 1 });

  // Engagement
  a('nonPayerRetention', 'Engagement', 'Non-paying users still active next month', '%', [0.20, 0.28, 0.35], 'estimate', 'low',
    'No data.', 'Free users have only one free call card (single use, no re-issue — D-05), so there is little for them to come back to.', { min: 0, max: 0.9, step: 0.01, pct: true });
  a('dauMau', 'Engagement', 'Daily active ÷ monthly active', '%', [0.12, 0.18, 0.25], 'estimate', 'low', 'No data.', 'Display and infrastructure sizing only.', { min: 0.02, max: 0.8, step: 0.01, pct: true });

  // Free Call Card
  a('freeCallUse', 'Free Call Card', 'Eligible new users who start their free call', '%', [0.50, 0.60, 0.70], 'estimate', 'low', 'One card per phone and per device (freecall module).', 'The card is the onboarding hook; not everyone tries a random match.', { min: 0, max: 1, step: 0.01, pct: true });
  a('freeCallComplete', 'Free Call Card', 'Free calls reaching the full 60 s (host is paid ₹10)', '%', [0.75, 0.80, 0.85], 'estimate', 'low', 'settle.go: compensation only when billable ≥ 60 s.', 'Random matches are often skipped early.', { min: 0, max: 1, step: 0.01, pct: true });
  a('freeCallHostOptIn', 'Free Call Card', 'Active hosts opted into the free-call pool', '%', [0.50, 0.60, 0.70], 'estimate', 'low', 'host free_call_opt_in flag; 20 free calls per host per day cap (code).', 'Caps free-call capacity.', { min: 0, max: 1, step: 0.01, pct: true });

  // Conversion
  a('convFreeCall', 'Conversion', 'Free-call users who buy Diamonds in the same month', '%', [0.03, 0.06, 0.09], 'estimate', 'low', 'No data. The single most important unknown.', '3–9% first-purchase conversion is typical of freemium social apps with a strong first experience; Dashuri has none yet.', { min: 0, max: 0.5, step: 0.005, pct: true, sim: true, simLabel: 'Paying conversion (free-call users)' });
  a('convOther', 'Conversion', 'Other new users who buy in their first month', '%', [0.01, 0.015, 0.02], 'estimate', 'low', 'No data.', 'Users who skip the free call rarely pay straight away.', { min: 0, max: 0.3, step: 0.005, pct: true });
  a('convLater', 'Conversion', 'Active non-payers who first buy in a later month', '%/mo', [0.005, 0.01, 0.015], 'estimate', 'low', 'No data.', 'Slow drip of late converters.', { min: 0, max: 0.2, step: 0.005, pct: true });

  // Paying customers
  a('payerChurn', 'Spending', 'Paying customers who stop buying each month (churn)', '%/mo', [0.60, 0.45, 0.35], 'estimate', 'low', 'No data.', 'Paid-companionship spend is impulsive and concentrated; most first-time buyers do not return. 45% monthly churn means a payer lasts ~2.2 months on average.', { min: 0.02, max: 0.95, step: 0.01, pct: true, sim: true, simLabel: 'Monthly payer churn' });
  a('purchasesPerPayer', 'Spending', 'Diamond purchases per active payer per month', 'purchases', [1.2, 1.4, 1.7], 'estimate', 'low', 'No data.', 'Most payers buy once a month; a few heavy users buy repeatedly.', { min: 0.2, max: 10, step: 0.1, sim: true, simLabel: 'Purchase frequency' });
  a('packageMix', 'Spending', 'Package mix (Starter → Premium)', 'share', [[0.40, 0.30, 0.15, 0.10, 0.04, 0.01], [0.30, 0.30, 0.20, 0.12, 0.06, 0.02], [0.25, 0.28, 0.22, 0.14, 0.08, 0.03]], 'estimate', 'low', 'Carried from docs/simulation (17 Nov) — hypothesis, no data.', 'Small packs dominate early in Indian microtransaction apps.', { mix: true });
  a('topUpShare', 'Spending', 'Shortfall covered by an extra top-up when a payer runs out', '%', [0.4, 0.6, 0.7], 'estimate', 'low', 'No in-call top-up in the MVP (D-10); the low-balance banner links to the wallet after the call.', 'Some payers who run out buy again the same month; the rest stop calling.', { min: 0, max: 1, step: 0.05, pct: true });
  a('purchaseValueMultiplier', 'Spending', 'Average purchase value vs package mix', '×', [1, 1, 1], 'decision', 'high', 'Simulator control: scales package counts toward bigger packs.', '1 = the mix above. 1.5 = buyers spend 50% more per purchase (same ₹ per Diamond).', { min: 0.3, max: 4, step: 0.05, sim: true, simLabel: 'Average purchase value (× base mix)' });

  // Calls
  a('callsPerPayer', 'Calls', 'Paid call attempts per active payer per month', 'calls', [4, 5, 6], 'estimate', 'low', 'No data.', 'Set so that Diamonds bought and Diamonds used roughly balance in the base case.', { min: 0, max: 60, step: 0.5, sim: true, simLabel: 'Paid calls per payer per month' });
  a('callConnectRate', 'Calls', 'Call attempts that the host accepts and that connect', '%', [0.75, 0.82, 0.88], 'estimate', 'low', 'No data. Failed/declined calls are released unbilled (settle.go).', 'Hosts miss or decline calls; networks fail.', { min: 0.1, max: 1, step: 0.01, pct: true });
  a('avgCallMinutes', 'Calls', 'Average connected paid call length', 'min', [4, 5, 6], 'estimate', 'low', 'No data.', 'Short calls dominate pay-per-minute video; 60 s minimum balance to start (code).', { min: 1, max: 60, step: 0.5, sim: true, simLabel: 'Average call duration (min)' });
  a('interruptionShare', 'Calls', 'Connected time not billed (pauses ≥ 10 s, host video off)', '%', [0.04, 0.02, 0.01], 'estimate', 'medium', 'Billing follows host video; interruptions ≥ 10 s are not billed (timeline.go).', 'Mobile networks in India drop often.', { min: 0, max: 0.5, step: 0.01, pct: true });
  a('avgRate', 'Calls', 'Average host rate', 'D/min', [1000, 1500, 2000], 'estimate', 'low', 'Range 500–10,000 D/min, default 500 (code). Level ladder unresolved, so hosts may set any rate in range.', 'Most hosts will price near the low end until demand is proven.', { min: 500, max: 10000, step: 100 });
  a('avgRateRef', 'Calls', 'Reference rate for demand response', 'D/min', [1000, 1500, 2000], 'estimate', 'low', 'Internal: equals the scenario rate.', 'Demand response to a rate change is measured against this.', { hidden: true });
  a('rateElasticity', 'Calls', 'Call-minute demand response to the per-minute price', 'elasticity', [0.8, 0.6, 0.5], 'estimate', 'low', 'No data.', 'A 10% higher ₹/min cuts minutes demanded by ~6% (base).', { min: 0, max: 2, step: 0.05 });
  a('priceElasticity', 'Calls', 'Purchase response to ₹ per Diamond', 'elasticity', [0.8, 0.6, 0.5], 'estimate', 'low', 'No data.', 'Used only when package prices or sizes change.', { min: 0, max: 2, step: 0.05 });

  // Hosts
  a('hostsStart', 'Hosts', 'Approved, active hosts at launch', 'hosts', [10, 15, 25], 'estimate', 'low', 'Recruitment is founder-managed; manual KYC (code).', 'A launch pool the founder can recruit and verify by hand.', { min: 1, max: 2000, step: 1 });
  a('hostApplications', 'Hosts', 'New host applications per month', 'apps/mo', [15, 20, 30], 'estimate', 'low', 'No data.', '', { min: 0, max: 5000, step: 1 });
  a('hostApprovalRate', 'Hosts', 'Applications approved after manual KYC', '%', [0.5, 0.6, 0.7], 'estimate', 'low', 'Moderator decision; DOB ≥ 18 required (code).', '', { min: 0, max: 1, step: 0.01, pct: true });
  a('hostChurn', 'Hosts', 'Active hosts who stop each month', '%/mo', [0.30, 0.20, 0.12], 'estimate', 'low', 'No data.', 'High: host earnings are low and payouts are switched off.', { min: 0, max: 0.9, step: 0.01, pct: true });
  a('hostOnlineDaysShare', 'Hosts', 'Days a host comes online', '%', [0.5, 0.6, 0.7], 'estimate', 'low', 'No data.', '', { min: 0.05, max: 1, step: 0.01, pct: true });
  a('hostOnlineHours', 'Hosts', 'Hours online per online day', 'h', [2, 2.5, 3], 'estimate', 'low', 'No data.', '', { min: 0.5, max: 12, step: 0.5, sim: true, simLabel: 'Host hours online per day' });
  a('maxBusyShare', 'Hosts', 'Max share of online time a host can spend in calls', '%', [0.6, 0.6, 0.6], 'estimate', 'medium', 'Physical limit (gaps between calls).', '', { min: 0.1, max: 1, step: 0.05, pct: true });
  a('hostReviewCost', 'Hosts', 'Manual KYC review cost per application', '₹', [150, 100, 80], 'estimate', 'medium', 'Manual moderator review (no KYC vendor).', '~20 min of a ₹300/h reviewer, plus re-checks.', { min: 0, max: 2000, step: 10 });
  a('hostShareMultiplier', 'Hosts', 'Host earnings vs implemented Bean rule', '×', [1, 1, 1], 'decision', 'high', 'Simulator control. 1 = 16,670 D → 10,000 Beans (code).', 'Use >1 to test a higher host share.', { min: 0.5, max: 4, step: 0.05 });

  // Risk
  a('refundRate', 'Risk', 'Purchase value refunded before use', '%', [0.03, 0.015, 0.01], 'estimate', 'low', 'Refund reverses only unspent Diamonds (purchases/service.go).', '', { min: 0, max: 0.3, step: 0.005, pct: true });
  a('chargebackRate', 'Risk', 'Purchase value charged back after use (incl. fraud)', '%', [0.02, 0.01, 0.005], 'estimate', 'low', 'Spent Diamonds cannot be recovered; audited as reversal_shortfall (code).', 'Stolen cards and friendly fraud on spent value.', { min: 0, max: 0.3, step: 0.005, pct: true });
  a('chargebackFee', 'Risk', 'Fee per chargeback case', '₹', [1500, 1300, 1300], 'unverified', 'low', 'Third-party reports of US$15–25 per case passed to developers after 3 Aug 2026 (docs/simulation).', 'Confirm in Play Console.', { min: 0, max: 5000, step: 50 });
  a('beanClawbackShare', 'Risk', 'Host Beans recovered on a chargeback', '%', [0.4, 0.5, 0.6], 'estimate', 'low', 'BeanClawback reverses Beans still in the 7-day hold (ledger templates).', 'Payouts are off, so held and available Beans are both reachable today.', { min: 0, max: 1, step: 0.05, pct: true });

  // Fees & tax
  a('gstRate', 'Fees & tax', 'GST included in Diamond prices', '%', [0.18, 0.18, 0.18], 'verified', 'high', 'Migration: "Prices include GST". 18% on online services (statute).', 'Who remits GST on Play sales needs CA confirmation.', { min: 0, max: 0.28, step: 0.01, pct: true });
  a('playFee', 'Fees & tax', 'Google Play service fee', '%', [0.20, 0.15, 0.15], 'unverified', 'medium', '15% on the first US$1M/year (Google help page; India-specific 2026–27 schedule unconfirmed). Conservative uses 20% (reported new non-recurring rate).', 'Google is changing India fees; check Play Console before launch.', { min: 0, max: 0.4, step: 0.01, pct: true });
  a('playFeeOnGross', 'Fees & tax', 'Play fee charged on the GST-inclusive price', 'yes/no', [1, 0, 0], 'unverified', 'low', 'Unconfirmed; conservative charges on the inclusive price.', '', { bool: true });
  a('usdInr', 'Fees & tax', 'Exchange rate', '₹ per US$', [90, 89, 88], 'estimate', 'medium', 'Market rate, Nov 2026 (approx.).', '', { min: 60, max: 120, step: 0.5 });
  a('googleLagMonths', 'Fees & tax', 'Months until Google pays out a sale', 'months', [1, 1, 1], 'verified', 'high', 'Google pays merchants around the 15th of the following month (docs/simulation, verified 17 Nov).', '', { min: 0, max: 2, step: 1 });
  a('gstLagMonths', 'Fees & tax', 'Months until GST is paid', 'months', [1, 1, 1], 'verified', 'high', 'GSTR-3B due on the 20th of the following month.', '', { min: 0, max: 2, step: 1 });

  // Video
  a('streamPer1000', 'Video & safety', 'Stream video price per 1,000 participant-minutes', 'US$', [3.0, 1.5, 1.5], 'verified', 'medium', 'Stream pricing guide: HD (720p) $1.50, Full HD $3.00 per 1,000 participant-min (checked 22 Nov 2026). Calls are set to 1280×720 (stream.go).', 'Conservative assumes Stream bills at the Full HD tier (its aggregate-resolution rule).', { min: 0, max: 20, step: 0.1, sim: true, simLabel: 'Stream price (US$ per 1,000 participant-min)' });
  a('streamFreeUsd', 'Video & safety', 'Stream free usage per month', 'US$', [0, 100, 100], 'verified', 'medium', 'Stream: first $100 of usage free each month (pricing page; wording varies).', 'Conservative assumes no free tier.', { min: 0, max: 500, step: 10 });
  a('overheadMinPerCall', 'Video & safety', 'Unbilled Stream minutes per call (ringing, setup, pauses)', 'min', [0.6, 0.4, 0.3], 'estimate', 'low', 'Participants join before billing starts (lifecycle.go).', '', { min: 0, max: 5, step: 0.1 });
  a('sightengineMultiplier', 'Video & safety', 'Sightengine price vs published plans', '×', [1.25, 1, 1], 'unverified', 'medium', 'Sightengine pricing page: free 2,000 ops; Starter $29 / 10k ops; Pro $99 / 40k ops; +$0.002/op (checked 22 Nov 2026).', 'One nudity check = 1 operation (assumed).', { min: 0, max: 5, step: 0.05 });
  a('reportsPer1000Calls', 'Video & safety', 'User reports per 1,000 calls', 'reports', [8, 5, 4], 'estimate', 'low', 'No data.', '', { min: 0, max: 100, step: 1 });
  a('reviewCostPerReport', 'Video & safety', 'Human review cost per report', '₹', [40, 30, 25], 'estimate', 'low', 'No data.', '', { min: 0, max: 500, step: 5 });
  a('safetyOpsMonthly', 'Video & safety', 'On-call safety / takedown cover', '₹/mo', [15000, 10000, 8000], 'estimate', 'medium', 'IT Rules takedown timelines; grievance officer (integration checklist).', 'Someone must be reachable every day. ₹0 only if the founder does it personally.', { min: 0, max: 200000, step: 1000 });

  // SMS
  a('smsPrice', 'Infrastructure', 'OTP SMS price', '₹/SMS', [7.4, 2.5, 0.3], 'unverified', 'low', 'Twilio India $0.0832/SMS (official page, 22 Nov 2026) = ₹7.4. Base assumes a cheaper Supabase-supported provider (unquoted). Optimistic: Indian DLT gateway via an SMS hook.', 'The provider is not chosen; get quotes.', { min: 0, max: 15, step: 0.1 });
  a('smsPerRegistration', 'Infrastructure', 'OTP SMS per registration (incl. retries)', 'SMS', [1.4, 1.3, 1.2], 'estimate', 'medium', '', '', { min: 1, max: 5, step: 0.1 });
  a('smsPerMauReauth', 'Infrastructure', 'Re-login OTP SMS per active user per month', 'SMS', [0.15, 0.10, 0.08], 'estimate', 'low', '', '', { min: 0, max: 2, step: 0.01 });

  // Infrastructure
  a('supabaseUsd', 'Infrastructure', 'Supabase Pro plan', 'US$/mo', [25, 25, 25], 'verified', 'high', 'Supabase Pro $25/month incl. $10 compute credit (pricing page).', 'Free tier pauses idle projects; production needs Pro.', { min: 0, max: 2000, step: 5 });
  a('cloudRunUsd', 'Infrastructure', 'Cloud Run API + worker at launch', 'US$/mo', [30, 20, 15], 'estimate', 'low', 'No load test. One warm instance for webhooks and call evaluation.', 'Scales with active users (below).', { min: 0, max: 2000, step: 5 });
  a('gcpOtherUsd', 'Infrastructure', 'Other Google Cloud (Secret Manager, Pub/Sub RTDN, logs, registry)', 'US$/mo', [10, 6, 5], 'estimate', 'medium', '', '', { min: 0, max: 500, step: 1 });
  a('infraPerKMau', 'Infrastructure', 'Variable infrastructure per 1,000 active users', '₹', [500, 300, 250], 'estimate', 'low', 'DB compute, storage, egress, Cloud Run scaling.', '', { min: 0, max: 5000, step: 50 });
  a('infraMultiplier', 'Infrastructure', 'Infrastructure cost multiplier (stress)', '×', [1, 1, 1], 'decision', 'high', 'Stress-test control.', '', { min: 0.2, max: 10, step: 0.1 });

  // Operations
  a('supportPerKMau', 'Operations', 'Customer support per 1,000 active users', '₹', [1500, 1000, 800], 'estimate', 'low', 'Email + grievance form (D-22).', 'Payment and refund disputes dominate.', { min: 0, max: 10000, step: 100 });
  a('accountingMonthly', 'Operations', 'Accounting, GST filings (CA)', '₹/mo', [6000, 4000, 3500], 'placeholder', 'medium', 'Get quotes.', 'Monthly GSTR-1/3B, books, TDS later.', { min: 0, max: 100000, step: 500 });
  a('legalMonthly', 'Operations', 'Legal and compliance retainer', '₹/mo', [4000, 2500, 2000], 'placeholder', 'low', 'Get quotes.', '', { min: 0, max: 100000, step: 500 });
  a('domainEmailMonthly', 'Operations', 'Domain, email, website', '₹/mo', [700, 500, 400], 'estimate', 'medium', '', '', { min: 0, max: 20000, step: 100 });
  a('toolsMonthly', 'Operations', 'Monitoring, tools, misc. SaaS', '₹/mo', [1500, 800, 500], 'estimate', 'medium', '', '', { min: 0, max: 50000, step: 100 });
  a('otherFixedMonthly', 'Operations', 'Other fixed operating costs', '₹/mo', [3000, 2000, 1500], 'estimate', 'low', '', 'Phone, banking, test devices (amortised).', { min: 0, max: 500000, step: 500, sim: true, simLabel: 'Other operating expenses (₹/month)' });
  a('founderSalary', 'Operations', 'Founder salary', '₹/mo', [0, 0, 0], 'decision', 'high', 'Founder decision.', 'Excluded by default. Add it to see the true cost of the business.', { min: 0, max: 500000, step: 5000 });
  a('oneTimeSetup', 'Operations', 'One-time setup in Month 1', '₹', [125000, 90000, 75000], 'placeholder', 'low', 'Get quotes: incorporation, legal review of terms/privacy/host agreement, trademark, Play developer account (US$25).', 'Payouts and Cashfree need a company and written approvals.', { min: 0, max: 2000000, step: 5000 });

  // Payouts & finance
  a('payoutsEnabled', 'Payouts & cash', 'Host payouts switched on', 'yes/no', [0, 0, 0], 'code', 'high', 'PAYOUTS_ENABLED=false; no payout provider (code).', 'Withdrawals are recorded but not paid.', { bool: true });
  a('payoutStartMonth', 'Payouts & cash', 'Month payouts start (if switched on)', 'month', [4, 4, 4], 'decision', 'high', 'Stress-test control.', '', { min: 1, max: 6, step: 1 });
  a('withdrawShare', 'Payouts & cash', 'Withdrawable Bean balance hosts withdraw each month', '%', [0.9, 0.8, 0.8], 'estimate', 'low', '₹500 minimum, 7-day hold (code).', 'Hosts withdraw almost everything they can.', { min: 0, max: 1, step: 0.05, pct: true });
  a('payoutFee', 'Payouts & cash', 'Payout transfer fee', '₹/transfer', [10, 8, 6], 'unverified', 'low', 'No payout provider has been chosen.', '', { min: 0, max: 100, step: 1 });
  a('startingCash', 'Payouts & cash', 'Starting cash', '₹', [200000, 200000, 200000], 'decision', 'high', 'Founder input.', 'Compared with the computed capital requirement.', { min: 0, max: 50000000, step: 10000 });
  a('reserveMonths', 'Payouts & cash', 'Cash reserve to keep (months of fixed cost)', 'months', [3, 3, 3], 'decision', 'high', '', '', { min: 0, max: 12, step: 1 });

  // Optimisation levers (off by default)
  a('priceMultiplier', 'Levers', 'Package prices vs current', '×', [1, 1, 1], 'decision', 'high', 'Lever. 1 = seeded prices.', '', { min: 0.5, max: 2, step: 0.01 });
  a('diamondsMultiplier', 'Levers', 'Diamonds per package vs current', '×', [1, 1, 1], 'decision', 'high', 'Lever. 1 = seeded quantities.', '', { min: 0.5, max: 2, step: 0.01 });
  a('bulkBonusCut', 'Levers', 'Cut the extra Diamonds on Large and Premium', '%', [0, 0, 0], 'decision', 'high', 'Lever. 1 = Large/Premium give the same Diamonds per ₹ as Popular.', '', { min: 0, max: 1, step: 0.05, pct: true });
  a('promoBonusPct', 'Levers', 'Loyalty bonus: promotional Diamonds as % of purchase', '%', [0, 0, 0], 'decision', 'high', 'No promo grants are issued in the MVP (only expiry is coded; 30-day TTL, spent first).', 'Promo Diamonds earn hosts Beans but bring no revenue.', { min: 0, max: 0.5, step: 0.01, pct: true });
  a('promoChurnEffect', 'Levers', 'Payer churn reduction from the loyalty bonus', 'pts', [0, 0, 0], 'estimate', 'low', 'No data.', '', { min: 0, max: 0.3, step: 0.01, pct: true });
  a('referralRate', 'Levers', 'Referred sign-ups per active payer per month', 'users', [0, 0, 0], 'decision', 'high', 'No referral feature exists.', '', { min: 0, max: 2, step: 0.05 });
  a('referralPromoDiamonds', 'Levers', 'Promo Diamonds per referred sign-up', 'D', [0, 0, 0], 'decision', 'high', '', '', { min: 0, max: 50000, step: 500 });

  const ASSUMPTIONS = Object.freeze(A);
  const SCENARIOS = ['conservative', 'base', 'optimistic'];
  const SCENARIO_LABEL = { conservative: 'Conservative', base: 'Base case', optimistic: 'Optimistic' };

  function defaults(scenario) {
    const p = {};
    for (const x of ASSUMPTIONS) p[x.key] = clone(x.values[scenario || 'base']);
    return p;
  }
  function clone(v) { return Array.isArray(v) ? v.slice() : v; }

  // --------------------------------------------------------------- HELPERS
  function sightengineUsd(ops, mult) {
    if (ops <= 2000) return 0;
    const starter = 29 + Math.max(0, ops - 10000) * 0.002;
    const pro = 99 + Math.max(0, ops - 40000) * 0.002;
    return Math.min(starter, pro) * mult;
  }
  function supabaseComputeUsd(mau) {
    // Pro includes Micro compute. Estimated upgrades as active users grow (unverified).
    if (mau > 100000) return 200; if (mau > 40000) return 100; if (mau > 15000) return 50; return 0;
  }

  // Effective packages after levers.
  function packagesFor(p) {
    const popular = PACKAGES[3];
    const popularDPerPaise = popular.diamonds / popular.pricePaise;
    return PACKAGES.map((pk, i) => {
      let d = pk.diamonds;
      if (p.bulkBonusCut > 0 && i >= 4) {
        const flat = pk.pricePaise * popularDPerPaise; // same D per ₹ as Popular
        d = d - (d - flat) * p.bulkBonusCut;
      }
      return Object.assign({}, pk, { diamonds: d * p.diamondsMultiplier, price: pk.pricePaise / 100 * p.priceMultiplier, basePrice: pk.pricePaise / 100, baseDiamonds: pk.diamonds });
    });
  }

  // Package mix shifted toward larger packs by purchaseValueMultiplier
  // (exponential tilt; keeps shares positive and summing to 1).
  function tiltedMix(mix, valueMult) {
    if (Math.abs(valueMult - 1) < 1e-9) return mix.slice();
    const prices = PACKAGES.map(pk => pk.pricePaise / 100);
    const target = valueMult * mix.reduce((s, m, i) => s + m * prices[i], 0);
    const lo = Math.log(prices[0]), hi = Math.log(prices[prices.length - 1]);
    const mean = (t) => { let w = 0, s = 0; for (let i = 0; i < mix.length; i++) { const x = mix[i] * Math.exp(t * Math.log(prices[i])); w += x; s += x * prices[i]; } return s / w; };
    let a0 = -20, b0 = 20;
    if (target >= prices[prices.length - 1]) return mix.map((_, i) => i === mix.length - 1 ? 1 : 0);
    if (target <= prices[0]) return mix.map((_, i) => i === 0 ? 1 : 0);
    for (let k = 0; k < 80; k++) { const m = (a0 + b0) / 2; if (mean(m) < target) a0 = m; else b0 = m; }
    const t = (a0 + b0) / 2; void lo; void hi;
    const raw = mix.map((m, i) => m * Math.exp(t * Math.log(prices[i])));
    const tot = raw.reduce((s, x) => s + x, 0);
    return raw.map(x => x / tot);
  }

  // ------------------------------------------------------------------ MODEL
  const MONTHS = 6;

  function run(input) {
    const p = Object.assign(defaults('base'), input || {});
    const pk = packagesFor(p);
    const mix = tiltedMix(p.packageMix, p.purchaseValueMultiplier);
    const fx = p.usdInr;

    // Per-purchase averages (constant within a run).
    const avgPrice = mix.reduce((s, m, i) => s + m * pk[i].price, 0);
    const avgDiamonds = mix.reduce((s, m, i) => s + m * pk[i].diamonds, 0);
    const grossPerDiamond = avgPrice / avgDiamonds;                 // ₹ incl. GST
    const exGstPerDiamond = grossPerDiamond / (1 + p.gstRate);      // ₹ recognised per purchased Diamond used
    // Demand responses to levers.
    const basePk = packagesFor(Object.assign({}, p, { priceMultiplier: 1, diamondsMultiplier: 1, bulkBonusCut: 0 }));
    const baseGrossPerDiamond = mix.reduce((s, m, i) => s + m * basePk[i].price, 0) / mix.reduce((s, m, i) => s + m * basePk[i].diamonds, 0);
    const purchaseResponse = Math.pow(grossPerDiamond / baseGrossPerDiamond, -p.priceElasticity);
    const minuteResponse = Math.pow(p.avgRate / p.avgRateRef, -p.rateElasticity) * Math.pow(grossPerDiamond / baseGrossPerDiamond, -p.rateElasticity);
    const hostRupeesPerDiamond = HOST_RUPEES_PER_DIAMOND * p.hostShareMultiplier;
    const payerChurn = Math.max(0.01, p.payerChurn - (p.promoBonusPct > 0 ? p.promoChurnEffect : 0));
    const framesPaidCall = exact.framesPerParticipant(Math.round(p.avgCallMinutes * 60)) || 0;
    const framesFreeCall = exact.framesPerParticipant(RULES.freeCallSeconds);

    const months = [];
    let st = {
      totalReg: 0, activeNonPayers: 0, activePayers: 0, everPayers: 0, hosts: p.hostsStart, registeredHosts: p.hostsStart / Math.max(p.hostApprovalRate, 0.01),
      activePool: 0, dormantPool: 0, deferredPlayFee: 0, beanLiability: 0, cash: p.startingCash, cumCashFlow: 0,
      receivable: [], gstDue: [], cumRevenue: 0, cumOpex: 0, cumOp: 0
    };

    for (let m = 1; m <= MONTHS; m++) {
      const r = { month: m };
      // ---- Customers
      const spike = (p.spikeMonth === m) ? p.spikeMultiplier : 1;
      r.newOrganic = p.organicNewM1 * Math.pow(1 + p.organicGrowth, m - 1) * spike;
      r.newPaid = p.cac > 0 ? p.marketingBudget / p.cac : 0;
      r.newReferred = st.activePayers * p.referralRate;
      r.newRegistrations = r.newOrganic + r.newPaid + r.newReferred;
      const eligibleNew = r.newRegistrations * p.eligibleShare;
      st.totalReg += r.newRegistrations;
      r.totalRegistered = st.totalReg;

      // ---- Hosts (start of month)
      if (m > 1) {
        r.newHostsApproved = p.hostApplications * p.hostApprovalRate;
        st.hosts = st.hosts * (1 - p.hostChurn) + r.newHostsApproved;
      } else r.newHostsApproved = 0;
      r.hostApplications = m > 1 ? p.hostApplications : p.hostsStart / Math.max(p.hostApprovalRate, 0.01);
      if (m > 1) st.registeredHosts += p.hostApplications;
      r.registeredHosts = st.registeredHosts;
      r.activeHosts = st.hosts;
      r.approvedHosts = st.hosts;
      const onlineMinutes = st.hosts * p.hostOnlineDaysShare * 30 * p.hostOnlineHours * 60;
      r.onlineHostsAvg = st.hosts * p.hostOnlineDaysShare * p.hostOnlineHours / 24; // average concurrently online
      r.hostOnlineMinutes = onlineMinutes;

      // ---- Free Call Card (one per phone/device, 20/host/day)
      const fcDemand = eligibleNew * p.freeCallUse;
      const fcCapacity = st.hosts * p.freeCallHostOptIn * p.hostOnlineDaysShare * 30 * RULES.freeCallMaxPerHostPerDay;
      r.freeCallsStarted = Math.min(fcDemand, fcCapacity);
      r.freeCallsUnserved = fcDemand - r.freeCallsStarted;
      r.freeCallsCompleted = r.freeCallsStarted * p.freeCallComplete;
      r.freeCallMinutes = r.freeCallsCompleted * 1 + (r.freeCallsStarted - r.freeCallsCompleted) * 0.4;

      // ---- Conversion and activity
      const newPayersFree = r.freeCallsStarted * p.convFreeCall;
      const newPayersOther = Math.max(0, eligibleNew - r.freeCallsStarted) * p.convOther;
      const retainedNonPayers = st.activeNonPayers * p.nonPayerRetention;
      const laterPayers = retainedNonPayers * p.convLater;
      r.newPayers = newPayersFree + newPayersOther + laterPayers;
      const retainedPayers = st.activePayers * (1 - payerChurn);
      st.activePayers = retainedPayers + r.newPayers;
      st.activeNonPayers = retainedNonPayers - laterPayers + eligibleNew - newPayersFree - newPayersOther;
      st.everPayers += r.newPayers;
      r.payingCustomers = st.activePayers;
      r.everPayers = st.everPayers;
      r.mau = st.activePayers + st.activeNonPayers;
      r.dau = r.mau * p.dauMau;
      r.payingShare = r.mau > 0 ? r.payingCustomers / r.mau : 0;

      // ---- Wallets: purchased Diamonds are a liability until spent
      const dormantMove = st.activePool * payerChurn;               // balances of payers who stop
      st.activePool -= dormantMove; st.dormantPool += dormantMove;

      // ---- Purchases (Google Play only; Cashfree off). Planned purchases,
      // then top-ups by payers whose demand exceeds their balance.
      const effMinPerCall = p.avgCallMinutes * (1 - p.interruptionShare);
      r.callAttempts = st.activePayers * p.callsPerPayer * minuteResponse;
      const demandMinutes = r.callAttempts * p.callConnectRate * effMinPerCall;
      const capacityMinutes = Math.max(0, onlineMinutes * p.maxBusyShare - r.freeCallMinutes);
      const plannedPurchases = st.activePayers * p.purchasesPerPayer * purchaseResponse;
      const promoFromPlanned = plannedPurchases * avgDiamonds * p.promoBonusPct;
      const walletAfterPlanned = st.activePool + plannedPurchases * avgDiamonds * (1 - p.refundRate) + promoFromPlanned + r.newReferred * p.referralPromoDiamonds;
      const shortfallD = Math.max(0, Math.min(demandMinutes, capacityMinutes) * p.avgRate - walletAfterPlanned);
      r.topUpPurchases = shortfallD * p.topUpShare / (avgDiamonds * (1 - p.refundRate) * (1 + p.promoBonusPct));
      r.purchases = plannedPurchases + r.topUpPurchases;
      r.packagesSold = mix.map(x => x * r.purchases);
      r.grossByPackage = r.packagesSold.map((n, i) => n * pk[i].price);
      r.grossPurchaseValue = r.grossByPackage.reduce((s, x) => s + x, 0);
      r.diamondsPurchased = r.packagesSold.reduce((s, n, i) => s + n * pk[i].diamonds, 0);
      r.refunds = r.grossPurchaseValue * p.refundRate;
      const refundDiamonds = r.diamondsPurchased * p.refundRate;
      const netSales = r.grossPurchaseValue - r.refunds;
      r.gstOnSales = netSales * p.gstRate / (1 + p.gstRate);
      r.netSalesExGst = netSales - r.gstOnSales;
      r.playFee = p.playFee * (p.playFeeOnGross ? netSales : r.netSalesExGst);   // deducted by Google at sale (cash)
      r.netPaymentProceeds = netSales - r.playFee;                  // what Google remits (before chargebacks)
      r.chargebacks = r.grossPurchaseValue * p.chargebackRate;      // spent value clawed back by card networks
      r.chargebackCases = r.purchases * p.chargebackRate;
      r.chargebackFees = r.chargebackCases * p.chargebackFee;
      st.activePool += r.diamondsPurchased - refundDiamonds;
      st.deferredPlayFee += r.playFee;                              // matched to Diamond use (P&L)
      const promoGranted = r.diamondsPurchased * p.promoBonusPct + r.newReferred * p.referralPromoDiamonds;
      let promoPool = promoGranted;                                 // expires within 30 days (TTL)

      // ---- Paid calls
      const walletMinutes = (st.activePool + promoPool) / p.avgRate;
      r.paidMinutes = Math.max(0, Math.min(demandMinutes, walletMinutes, capacityMinutes));
      r.unmetMinutesWallet = Math.max(0, Math.min(demandMinutes, capacityMinutes) - r.paidMinutes);
      r.unmetMinutesCapacity = Math.max(0, demandMinutes - capacityMinutes);
      r.connectedCalls = effMinPerCall > 0 ? r.paidMinutes / effMinPerCall : 0;
      r.failedCalls = p.callConnectRate > 0 ? r.connectedCalls / p.callConnectRate - r.connectedCalls : 0;
      r.diamondsConsumed = r.paidMinutes * p.avgRate;
      const fromPromo = Math.min(promoPool, r.diamondsConsumed);    // spend order: promotional first
      const fromPurchased = r.diamondsConsumed - fromPromo;
      promoPool -= fromPromo;
      r.promoDiamondsUsed = fromPromo; r.promoDiamondsExpired = promoPool;
      const poolBefore = st.activePool + st.dormantPool;
      st.activePool -= fromPurchased;
      r.diamondsConsumedPurchased = fromPurchased;
      // Play fee expense follows the Diamonds used (incremental cost of the contract).
      r.playFeeExpense = poolBefore > 0 ? st.deferredPlayFee * fromPurchased / poolBefore : 0;
      st.deferredPlayFee -= r.playFeeExpense;
      r.deferredPlayFee = st.deferredPlayFee;

      // ---- Revenue recognition: only purchased Diamonds actually spent
      r.revenueRecognized = fromPurchased * exGstPerDiamond;
      r.unspentDiamonds = st.activePool + st.dormantPool;
      r.diamondLiability = r.unspentDiamonds * exGstPerDiamond;       // deferred revenue (ex GST)
      r.diamondLiabilityCustomerValue = r.unspentDiamonds * grossPerDiamond;

      // ---- Host earnings (Beans) — expense and liability, never platform profit
      r.beansEarnedPaid = r.diamondsConsumed * BEANS_PER_DIAMOND * p.hostShareMultiplier;
      r.hostEarningsPaid = r.diamondsConsumed * hostRupeesPerDiamond;
      r.freeCallComp = r.freeCallsCompleted * FREE_CALL_COMP_RUPEES;
      const cbDiamonds = r.diamondsPurchased * p.chargebackRate;
      r.beanClawback = cbDiamonds * hostRupeesPerDiamond * p.beanClawbackShare;
      r.hostEarnings = r.hostEarningsPaid + r.freeCallComp - r.beanClawback;
      r.beansEarned = r.hostEarnings / (RULES.paisePerBean / 100);
      let payout = 0, payoutTransfers = 0;
      if (p.payoutsEnabled && m >= p.payoutStartMonth) {
        payout = st.beanLiability * p.withdrawShare;               // opening balance is past the 7-day hold
        payoutTransfers = Math.min(st.hosts, payout / 500);
      }
      r.hostPayouts = payout;
      r.payoutFees = payoutTransfers * p.payoutFee;
      st.beanLiability += r.hostEarnings - payout;
      r.beanLiability = st.beanLiability;
      r.hostUtilization = onlineMinutes > 0 ? (r.paidMinutes + r.freeCallMinutes) / onlineMinutes : 0;
      r.callsPerHost = st.hosts > 0 ? (r.connectedCalls + r.freeCallsCompleted) / st.hosts : 0;
      r.earningsPerHost = st.hosts > 0 ? r.hostEarnings / st.hosts : 0;
      r.hostEarnPerOnlineHour = onlineMinutes > 0 ? r.hostEarnings / (onlineMinutes / 60) : 0;

      // ---- Usage costs
      const attempts = r.connectedCalls + r.failedCalls;
      r.streamParticipantMinutes = 2 * (r.paidMinutes / Math.max(0.01, 1 - p.interruptionShare) + r.freeCallMinutes + attempts * p.overheadMinPerCall + r.freeCallsStarted * p.overheadMinPerCall);
      r.streamCost = Math.max(0, r.streamParticipantMinutes / 1000 * p.streamPer1000 - p.streamFreeUsd) * fx;
      r.moderationOps = 2 * (r.connectedCalls * framesPaidCall + r.freeCallsStarted * framesFreeCall);
      r.moderationApiCost = sightengineUsd(r.moderationOps, p.sightengineMultiplier) * fx;
      r.humanReviewCost = (r.connectedCalls + r.freeCallsStarted) / 1000 * p.reportsPer1000Calls * p.reviewCostPerReport;
      r.chargebackLoss = r.chargebacks / (1 + p.gstRate) + r.chargebackFees;   // GST portion reclaimed by credit note (CA to confirm)
      r.smsCost = (r.newRegistrations * p.smsPerRegistration + r.mau * p.smsPerMauReauth) * p.smsPrice;
      r.infraCloud = ((p.supabaseUsd + supabaseComputeUsd(r.mau)) + p.cloudRunUsd * (1 + r.mau / 20000) + p.gcpOtherUsd) * fx * p.infraMultiplier;
      r.infraVariable = r.mau / 1000 * p.infraPerKMau * p.infraMultiplier;
      r.supportCost = r.mau / 1000 * p.supportPerKMau;
      r.hostOnboardingCost = r.hostApplications * p.hostReviewCost;
      r.marketing = p.marketingBudget;
      r.fixedOps = p.accountingMonthly + p.legalMonthly + p.domainEmailMonthly + p.toolsMonthly + p.otherFixedMonthly + p.safetyOpsMonthly + p.founderSalary;
      r.oneTime = m === 1 ? p.oneTimeSetup : 0;

      // ---- P&L
      r.directCosts = (r.hostEarningsPaid - r.beanClawback) + r.playFeeExpense + r.streamCost + r.moderationApiCost + r.humanReviewCost + r.chargebackLoss;
      r.grossProfit = r.revenueRecognized - r.directCosts;
      r.grossMargin = r.revenueRecognized > 0 ? r.grossProfit / r.revenueRecognized : null;
      r.otherVariable = r.freeCallComp + r.smsCost + r.infraVariable + r.supportCost + r.hostOnboardingCost + r.payoutFees;
      r.contribution = r.grossProfit - r.otherVariable;
      r.contributionMargin = r.revenueRecognized > 0 ? r.contribution / r.revenueRecognized : null;
      r.fixedCosts = r.fixedOps + r.infraCloud;
      r.operatingProfit = r.contribution - r.fixedCosts - r.marketing - r.oneTime;
      r.variableInfra = r.streamCost + r.moderationApiCost + r.smsCost + r.infraVariable;
      r.totalExpenses = r.directCosts + r.otherVariable + r.fixedCosts + r.marketing + r.oneTime;

      // ---- Cash (Google pays next month; GST paid next month; payouts only if on)
      st.receivable.push(r.netPaymentProceeds - r.chargebacks - r.chargebackFees);
      st.gstDue.push(r.gstOnSales - r.chargebacks * p.gstRate / (1 + p.gstRate));
      const recIdx = m - 1 - p.googleLagMonths, gstIdx = m - 1 - p.gstLagMonths;
      r.cashFromGoogle = recIdx >= 0 ? st.receivable[recIdx] : 0;
      r.gstPaid = gstIdx >= 0 ? st.gstDue[gstIdx] : 0;
      r.cashOpex = r.streamCost + r.moderationApiCost + r.humanReviewCost + r.smsCost + r.infraCloud + r.infraVariable + r.supportCost + r.hostOnboardingCost + r.marketing + r.fixedOps + r.oneTime + r.payoutFees;
      r.netCashFlow = r.cashFromGoogle - r.gstPaid - r.cashOpex - r.hostPayouts;
      st.cash += r.netCashFlow; st.cumCashFlow += r.netCashFlow;
      r.closingCash = st.cash;
      r.cumCashFlow = st.cumCashFlow;
      r.googleReceivable = st.receivable.slice(Math.max(0, m - p.googleLagMonths)).reduce((s, x) => s + x, 0);
      r.gstPayable = st.gstDue.slice(Math.max(0, m - p.gstLagMonths)).reduce((s, x) => s + x, 0);
      r.cashAfterHostLiability = r.closingCash - r.beanLiability;
      r.economicCash = r.closingCash + r.googleReceivable - r.gstPayable - r.beanLiability;

      // ---- Unit metrics
      r.arppu = r.payingCustomers > 0 ? r.grossPurchaseValue / r.payingCustomers : 0;
      r.revenuePerPayer = r.payingCustomers > 0 ? r.revenueRecognized / r.payingCustomers : 0;
      r.arpmau = r.mau > 0 ? r.revenueRecognized / r.mau : 0;
      r.costPerMau = r.mau > 0 ? r.totalExpenses / r.mau : 0;
      r.ratePerMinuteRupees = p.avgRate * grossPerDiamond;
      r.hostPerMinuteRupees = p.avgRate * hostRupeesPerDiamond;

      st.cumRevenue += r.revenueRecognized; st.cumOpex += r.totalExpenses; st.cumOp += r.operatingProfit;
      months.push(r);
    }
    return summarise(p, months, { avgPrice, avgDiamonds, grossPerDiamond, exGstPerDiamond, mix, packages: pk, hostRupeesPerDiamond, payerChurn });
  }

  function sum(ms, k) { return ms.reduce((s, r) => s + (r[k] || 0), 0); }

  function summarise(p, months, unit) {
    const m6 = months[MONTHS - 1];
    const s = { params: p, months, unit };
    s.cumRevenue = sum(months, 'revenueRecognized');
    s.cumGross = sum(months, 'grossPurchaseValue');
    s.cumExpenses = sum(months, 'totalExpenses');
    s.cumOperatingProfit = sum(months, 'operatingProfit');
    s.cumGrossProfit = sum(months, 'grossProfit');
    s.cumContribution = sum(months, 'contribution');
    s.grossMargin = s.cumRevenue > 0 ? s.cumGrossProfit / s.cumRevenue : null;
    s.contributionMargin = s.cumRevenue > 0 ? s.cumContribution / s.cumRevenue : null;
    s.cumNetCash = sum(months, 'netCashFlow');
    // Capital: deepest point of cumulative cash flow from zero.
    let lowest = 0; for (const r of months) lowest = Math.min(lowest, r.cumCashFlow);
    s.peakCashNeed = -lowest;
    s.reserve = p.reserveMonths * (m6.fixedCosts + m6.marketing + Math.max(0, -m6.contribution));
    s.minCapital = s.peakCashNeed;
    s.recommendedCapital = s.peakCashNeed + s.reserve + m6.beanLiability;   // fund host liabilities before payouts start
    s.burnRate = -Math.min(0, s.cumNetCash) / MONTHS;
    const be = months.find(r => r.operatingProfit >= 0);
    s.breakEvenMonth = be ? be.month : null;
    s.m6 = m6;
    s.closingCash = m6.closingCash;
    s.minClosingCash = Math.min(...months.map(r => r.closingCash));

    // Break-even (steady state at Month 6 unit economics). Formulas in METHODOLOGY.
    const payers = m6.payingCustomers;
    const fixed = m6.fixedCosts + m6.marketing;
    const cpp = payers > 0 ? m6.contribution / payers : 0;                 // contribution per active payer (after free-call, SMS, support)
    const gpp = payers > 0 ? m6.grossProfit / payers : 0;
    s.contributionPerPayer = cpp;
    s.grossProfitPerPayer = gpp;
    s.breakEvenPayers = cpp > 0 ? fixed / cpp : null;
    s.breakEvenPayersExMarketing = cpp > 0 ? m6.fixedCosts / cpp : null;
    s.breakEvenRevenue = s.breakEvenPayers != null ? s.breakEvenPayers * m6.revenuePerPayer : null;
    s.breakEvenMau = s.breakEvenPayers != null && m6.payingShare > 0 ? s.breakEvenPayers / m6.payingShare : null;
    const minPerPayer = payers > 0 ? m6.paidMinutes / payers : 0;
    s.breakEvenMinutes = s.breakEvenPayers != null ? s.breakEvenPayers * minPerPayer : null;
    const busyMinPerHost = p.hostOnlineDaysShare * 30 * p.hostOnlineHours * 60;
    s.breakEvenHostsAtMaxBusy = s.breakEvenMinutes != null ? s.breakEvenMinutes / (busyMinPerHost * p.maxBusyShare) : null;
    s.breakEvenHostsAt25 = s.breakEvenMinutes != null ? s.breakEvenMinutes / (busyMinPerHost * 0.25) : null;
    // Average purchase value needed with Month-6 payers and purchase frequency.
    const gpPerRupeeBooked = m6.grossPurchaseValue > 0 ? m6.grossProfit / m6.grossPurchaseValue : 0;
    const needGP = fixed + m6.otherVariable;
    s.requiredGrossBookings = gpPerRupeeBooked > 0 ? needGP / gpPerRupeeBooked : null;
    s.requiredAvgPurchase = (s.requiredGrossBookings != null && m6.purchases > 0) ? s.requiredGrossBookings / m6.purchases : null;
    s.minGrossMarginToBreakEven = m6.revenueRecognized > 0 ? (m6.otherVariable + fixed) / m6.revenueRecognized : null;

    // LTV and CAC.
    const churn = unit.payerChurn;
    s.payerLifetimeMonths = 1 / churn;
    s.ltvPayer = gpp / churn;                                              // gross profit per payer over expected life
    const totalNewEligible = sum(months, 'newRegistrations') * p.eligibleShare;
    s.payerConversion = totalNewEligible > 0 ? sum(months, 'newPayers') / sum(months, 'newRegistrations') : 0;
    const fcCostPerReg = sum(months, 'newRegistrations') > 0 ? (sum(months, 'freeCallComp') + sum(months, 'smsCost')) / sum(months, 'newRegistrations') : 0;
    s.ltvPerRegistration = s.ltvPayer * s.payerConversion - fcCostPerReg;
    s.ltvCac = p.cac > 0 ? s.ltvPerRegistration / p.cac : null;
    s.maxAffordableCac = Math.max(0, s.ltvPerRegistration);
    s.targetCac = Math.max(0, s.ltvPerRegistration / 3);
    // Months for a paid registration to repay its CAC from expected gross profit:
    // cumulative GP after k months = conv × gpp × (1 − (1−c)^k) / c.
    const x = (gpp > 0 && s.payerConversion > 0) ? p.cac * churn / (s.payerConversion * gpp) : Infinity;
    s.paybackMonths = x < 1 ? Math.log(1 - x) / Math.log(1 - churn) : null;

    s.risks = riskFlags(p, s);
    return s;
  }

  // -------------------------------------------------------------- RISK FLAGS
  function riskFlags(p, s) {
    const m6 = s.m6, out = [];
    const add = (id, level, title, detail) => out.push({ id, level, title, detail });
    if (m6.contribution < 0) add('contribution', 'critical', 'Negative contribution margin', 'Month 6 contribution is ' + inr(m6.contribution) + ': each extra active user loses money before fixed costs.');
    else if (s.contributionMargin != null && s.contributionMargin < 0.25) add('contribution', 'warning', 'Thin contribution margin', 'Six-month contribution margin is ' + pct(s.contributionMargin) + '.');
    if (m6.cashAfterHostLiability < 0) add('liab', 'critical', 'Cash does not cover host earnings', 'Closing cash ' + inr(m6.closingCash) + ' vs ' + inr(m6.beanLiability) + ' owed to hosts. Switching payouts on would empty the bank.');
    else if (m6.beanLiability > 0.5 * Math.max(1, m6.closingCash)) add('liab', 'warning', 'Host liabilities are large against cash', inr(m6.beanLiability) + ' owed to hosts vs ' + inr(m6.closingCash) + ' cash.');
    if (s.minClosingCash < 0) add('cash', 'critical', 'Cash runs out', 'Lowest balance ' + inr(s.minClosingCash) + ' with ' + inr(p.startingCash) + ' starting cash. Minimum capital needed: ' + inr(s.minCapital) + '.');
    else if (s.closingCash < s.reserve) add('cash', 'warning', 'Cash reserve below target', 'Month 6 cash ' + inr(s.closingCash) + ' vs a ' + p.reserveMonths + '-month reserve of ' + inr(s.reserve) + '.');
    if (p.marketingBudget > 0) {
      if (s.ltvPerRegistration <= 0 || p.cac > s.maxAffordableCac) add('cac', 'critical', 'CAC above what a user is worth', 'CAC ' + inr(p.cac) + ' vs lifetime gross profit per registration ' + inr(s.ltvPerRegistration) + '. Paid marketing destroys cash.');
      else if (s.ltvCac < 3) add('cac', 'warning', 'LTV:CAC below 3', 'LTV:CAC is ' + s.ltvCac.toFixed(2) + '.');
    }
    if (s.unit.payerChurn >= 0.5) add('retention', 'critical', 'Poor payer retention', pct(s.unit.payerChurn) + ' of payers stop each month; average payer life ' + s.payerLifetimeMonths.toFixed(1) + ' months.');
    else if (s.unit.payerChurn >= 0.35) add('retention', 'warning', 'Payer retention is weak', pct(s.unit.payerChurn) + ' monthly payer churn.');
    const usage = sum(s.months, 'streamCost') + sum(s.months, 'moderationApiCost') + sum(s.months, 'smsCost');
    if (s.cumRevenue > 0 && usage / s.cumRevenue > 0.15) add('infra', 'warning', 'Usage costs are a large share of revenue', 'Stream + moderation + SMS = ' + pct(usage / s.cumRevenue) + ' of recognised revenue.');
    const smsShare = s.cumExpenses > 0 ? sum(s.months, 'smsCost') / s.cumExpenses : 0;
    if (smsShare > 0.08) add('sms', 'warning', 'OTP SMS is a major cost', pct(smsShare) + ' of all expenses go to SMS.');
    if (m6.earningsPerHost < 1500) add('hosts', 'warning', 'Host earnings are too low to keep supply', 'Month 6 average host earns ' + inr(m6.earningsPerHost) + '/month (' + inr(m6.hostEarnPerOnlineHour) + ' per online hour), and cannot withdraw it.');
    if (m6.hostUtilization < 0.1) add('util', 'warning', 'Hosts are mostly idle', 'Month 6 utilisation ' + pct(m6.hostUtilization) + '.');
    if (m6.unmetMinutesCapacity > 0.05 * Math.max(1, m6.paidMinutes)) add('capacity', 'critical', 'Not enough hosts', Math.round(m6.unmetMinutesCapacity).toLocaleString('en-IN') + ' minutes of paid demand unserved in Month 6.');
    if (m6.freeCallsUnserved > 0.05 * Math.max(1, m6.freeCallsStarted)) add('fc', 'warning', 'Free calls exceed host capacity', Math.round(m6.freeCallsUnserved).toLocaleString('en-IN') + ' new users could not get a free call in Month 6 (20/host/day cap).');
    if (m6.revenuePerPayer > 0 && m6.contribution / Math.max(1, m6.payingCustomers) < 0) add('cohort', 'critical', 'Paying customers are unprofitable', 'Contribution per paying customer is ' + inr(m6.contribution / m6.payingCustomers) + ' in Month 6.');
    const breakage = m6.diamondsPurchased > 0 ? m6.unspentDiamonds / sum(s.months, 'diamondsPurchased') : 0;
    if (breakage > 0.4) add('unspent', 'warning', 'Customers are sitting on unspent Diamonds', pct(breakage) + ' of Diamonds bought are unspent: a refund and complaint exposure, not revenue.');
    return out;
  }

  // -------------------------------------------------------------- ANALYSES
  const SENSITIVITY = [
    ['organicNewM1', 'Organic sign-ups', 0.5, 1.5],
    ['organicGrowth', 'Organic growth', 0.5, 1.5],
    ['convFreeCall', 'Free-call → paying conversion', 0.5, 1.5],
    ['payerChurn', 'Payer churn', 1.25, 0.75],
    ['purchasesPerPayer', 'Purchase frequency', 0.75, 1.25],
    ['purchaseValueMultiplier', 'Average purchase value', 0.75, 1.25],
    ['callsPerPayer', 'Calls per payer', 0.6, 1.4],
    ['avgCallMinutes', 'Call duration', 0.7, 1.5],
    ['playFee', 'Google Play fee', 2, 0.73],
    ['streamPer1000', 'Stream price', 2, 0.5],
    ['cac', 'CAC', 2, 0.5],
    ['hostShareMultiplier', 'Host earnings per Diamond', 1.5, 1],
    ['safetyOpsMonthly', 'Safety operations', 1.5, 0.5],
    ['smsPrice', 'SMS price', 3, 0.12],
    ['refundRate', 'Refunds', 3, 0.5],
    ['chargebackRate', 'Chargebacks', 3, 0.5],
    ['oneTimeSetup', 'One-time setup', 1.5, 0.6],
    ['nonPayerRetention', 'Free-user retention', 0.6, 1.4]
  ];

  function sensitivity(params) {
    const base = run(params);
    const rows = SENSITIVITY.map(([key, label, lo, hi]) => {
      const low = run(Object.assign({}, params, { [key]: params[key] * lo }));
      const high = run(Object.assign({}, params, { [key]: params[key] * hi }));
      return { key, label, lowMult: lo, highMult: hi,
        worse: low.cumOperatingProfit - base.cumOperatingProfit, better: high.cumOperatingProfit - base.cumOperatingProfit,
        worseCapital: low.minCapital - base.minCapital, betterCapital: high.minCapital - base.minCapital };
    });
    rows.forEach(r => { r.swing = Math.abs(r.better - r.worse); });
    rows.sort((x, y) => y.swing - x.swing);
    return { base: base.cumOperatingProfit, rows };
  }

  // Stress tests: overrides relative to the given params.
  const STRESS = [
    { id: 'g25', group: 'Customer growth', label: 'Customer growth −25%', f: p => ({ organicNewM1: p.organicNewM1 * 0.75, organicGrowth: p.organicGrowth * 0.75, cac: p.cac / 0.75 }) },
    { id: 'g50', group: 'Customer growth', label: 'Customer growth −50%', f: p => ({ organicNewM1: p.organicNewM1 * 0.5, organicGrowth: p.organicGrowth * 0.5, cac: p.cac / 0.5 }) },
    { id: 'g75', group: 'Customer growth', label: 'Customer growth −75%', f: p => ({ organicNewM1: p.organicNewM1 * 0.25, organicGrowth: p.organicGrowth * 0.25, cac: p.cac / 0.25 }) },
    { id: 'c25', group: 'Paying conversion', label: 'Paying conversion −25%', f: p => ({ convFreeCall: p.convFreeCall * 0.75, convOther: p.convOther * 0.75, convLater: p.convLater * 0.75 }) },
    { id: 'c50', group: 'Paying conversion', label: 'Paying conversion −50%', f: p => ({ convFreeCall: p.convFreeCall * 0.5, convOther: p.convOther * 0.5, convLater: p.convLater * 0.5 }) },
    { id: 'c75', group: 'Paying conversion', label: 'Paying conversion −75%', f: p => ({ convFreeCall: p.convFreeCall * 0.25, convOther: p.convOther * 0.25, convLater: p.convLater * 0.25 }) },
    { id: 'dur', group: 'Calls', label: 'Calls 50% longer (same call count)', f: p => ({ avgCallMinutes: p.avgCallMinutes * 1.5 }) },
    { id: 's25', group: 'Stream', label: 'Stream cost +25%', f: p => ({ streamPer1000: p.streamPer1000 * 1.25 }) },
    { id: 's50', group: 'Stream', label: 'Stream cost +50%', f: p => ({ streamPer1000: p.streamPer1000 * 1.5 }) },
    { id: 's100', group: 'Stream', label: 'Stream cost +100%, no free tier', f: p => ({ streamPer1000: p.streamPer1000 * 2, streamFreeUsd: 0 }) },
    { id: 'play', group: 'Fees', label: 'Play fee 30% on inclusive price', f: () => ({ playFee: 0.30, playFeeOnGross: 1 }) },
    { id: 'ref', group: 'Risk', label: 'Refunds and chargebacks ×3', f: p => ({ refundRate: p.refundRate * 3, chargebackRate: p.chargebackRate * 3 }) },
    { id: 'util', group: 'Hosts', label: 'Host utilisation halves (twice the hosts online, same demand)', f: p => ({ hostsStart: p.hostsStart * 2, hostApplications: p.hostApplications * 2 }) },
    { id: 'host', group: 'Hosts', label: 'Host earnings +50% per Diamond', f: p => ({ hostShareMultiplier: p.hostShareMultiplier * 1.5 }) },
    { id: 'cac', group: 'Marketing', label: 'CAC doubles', f: p => ({ cac: p.cac * 2 }) },
    { id: 'churn', group: 'Retention', label: 'Payer churn +15 points', f: p => ({ payerChurn: Math.min(0.95, p.payerChurn + 0.15), nonPayerRetention: p.nonPayerRetention * 0.8 }) },
    { id: 'mod', group: 'Safety', label: 'Moderation cost ×2', f: p => ({ sightengineMultiplier: p.sightengineMultiplier * 2, reviewCostPerReport: p.reviewCostPerReport * 2, safetyOpsMonthly: p.safetyOpsMonthly * 2 }) },
    { id: 'infra', group: 'Infrastructure', label: 'Infrastructure costs ×3', f: p => ({ infraMultiplier: p.infraMultiplier * 3 }) },
    { id: 'q1', group: 'What if', label: 'Customers buy Diamonds but barely use them', f: p => ({ callsPerPayer: p.callsPerPayer * 0.3 }) },
    { id: 'q2', group: 'What if', label: 'Customers use Diamonds twice as fast', f: p => ({ callsPerPayer: p.callsPerPayer * 2 }) },
    { id: 'q3', group: 'What if', label: 'Hosts online but few calls (3× hosts)', f: p => ({ hostsStart: p.hostsStart * 3, hostApplications: p.hostApplications * 3 }) },
    { id: 'q4', group: 'What if', label: 'High growth, low conversion', f: p => ({ organicNewM1: p.organicNewM1 * 2, organicGrowth: p.organicGrowth * 1.5, convFreeCall: p.convFreeCall * 0.4, convOther: p.convOther * 0.4 }) },
    { id: 'q5', group: 'What if', label: 'Host liabilities grow faster (+60% host share, more free calls)', f: p => ({ hostShareMultiplier: p.hostShareMultiplier * 1.6, freeCallUse: Math.min(1, p.freeCallUse * 1.3) }) },
    { id: 'q6', group: 'What if', label: 'Sudden 10× sign-ups in Month 4', f: () => ({ spikeMonth: 4, spikeMultiplier: 10 }) },
    { id: 'q7', group: 'What if', label: 'Payouts switched on from Month 4', f: () => ({ payoutsEnabled: 1, payoutStartMonth: 4 }) },
    { id: 'q8', group: 'What if', label: 'Stream bills 4× the assumed rate', f: p => ({ streamPer1000: p.streamPer1000 * 4, streamFreeUsd: 0 }) }
  ];

  function stress(params) {
    const base = run(params);
    return STRESS.map(t => {
      const r = run(Object.assign({}, params, t.f(params)));
      return { id: t.id, group: t.group, label: t.label, cumOperatingProfit: r.cumOperatingProfit, delta: r.cumOperatingProfit - base.cumOperatingProfit,
        minCapital: r.minCapital, capitalDelta: r.minCapital - base.minCapital, m6Op: r.m6.operatingProfit, breakEvenMonth: r.breakEvenMonth,
        cashAfterHostLiability: r.m6.cashAfterHostLiability, critical: r.risks.filter(x => x.level === 'critical').map(x => x.title) };
    });
  }

  // Profitability levers. Each is a change a founder can make, with effort labels.
  const LEVERS = [
    { id: 'conv', label: 'Fix the first call: free-call conversion +50%', effort: 'Medium', time: '1–2 months', risk: 'Low',
      how: 'Route free calls to the best-rated, verified hosts; prompt a Starter pack at the end of the minute; in-call top-up (D-10).', cost: 'Engineering ~3–4 weeks; no running cost.',
      f: p => ({ convFreeCall: p.convFreeCall * 1.5 }) },
    { id: 'retain', label: 'Retention programme: payer churn −10 points', effort: 'Medium', time: '2–3 months', risk: 'Medium',
      how: 'Favourite hosts, "your host is online" pushes (needs firebase_messaging), weekly pack offers; 5% loyalty bonus Diamonds.', cost: '5% promotional Diamonds (pay hosts Beans, no revenue).',
      f: p => ({ promoBonusPct: 0.05, promoChurnEffect: 0.10 }) },
    { id: 'sms', label: 'Cheap OTP: Indian DLT gateway via Supabase SMS hook', effort: 'Low', time: '2–3 weeks', risk: 'Low',
      how: 'Use a Send-SMS auth hook to an Indian DLT-registered provider instead of Twilio; keep OTP rate limits.', cost: 'DLT registration; ~₹0.2–0.3 per SMS (get quotes).',
      f: () => ({ smsPrice: 0.3 }) },
    { id: 'organic', label: 'Stop paid ads until conversion is proven', effort: 'Low', time: 'Immediate', risk: 'Medium (slower growth)',
      how: 'Spend ₹0 on ads; recruit through host communities and referrals; restart ads when LTV:CAC > 3.', cost: 'None.',
      f: () => ({ marketingBudget: 0 }) },
    { id: 'bulk', label: 'Remove the bulk discount on Large/Premium', effort: 'Low', time: '1 week (Play Console + seed)', risk: 'Low–medium',
      how: 'Give Large and Premium the same Diamonds per ₹ as Popular; use a badge instead of extra Diamonds.', cost: 'None.',
      f: () => ({ bulkBonusCut: 1 }) },
    { id: 'price10', label: 'Package prices +10%', effort: 'Low', time: '1 week', risk: 'Medium (demand response)',
      how: 'Raise prices; Diamonds unchanged. Purchase demand falls by the price elasticity.', cost: 'None.',
      f: p => ({ priceMultiplier: p.priceMultiplier * 1.1 }) },
    { id: 'rate', label: 'Higher host rates: +33% average D/min', effort: 'Low', time: 'Level ladder decision', risk: 'Medium',
      how: 'Decide the level ladder so experienced hosts can charge more; minutes demanded fall by the rate elasticity.', cost: 'None.',
      f: p => ({ avgRate: p.avgRate * 1.33 }) },
    { id: 'supply', label: 'Match hosts to demand: half the new host intake', effort: 'Low', time: 'Immediate', risk: 'Low if demand is watched',
      how: 'Approve hosts only when utilisation is above ~15%; fewer idle hosts earn more each and stay.', cost: 'Lower KYC review cost.',
      f: p => ({ hostApplications: p.hostApplications * 0.5 }) },
    { id: 'hostpay', label: 'Pay hosts 50% more per Diamond (supply health)', effort: 'Low (rule-set version)', time: '1 week', risk: 'Lower margin; better host retention',
      how: 'New rule set: 16,670 D → 15,000 Beans. Cuts host churn (assumed −8 points).', cost: 'Higher host cost per minute.',
      f: p => ({ hostShareMultiplier: p.hostShareMultiplier * 1.5, hostChurn: Math.max(0, p.hostChurn - 0.08) }) },
    { id: 'ops', label: 'Founder covers safety on-call for the first six months', effort: 'Low', time: 'Immediate', risk: 'High founder load; legal duty remains',
      how: 'Founder acts as grievance officer and takedown contact until revenue covers a hire.', cost: 'Founder time.',
      f: () => ({ safetyOpsMonthly: 0 }) },
    { id: 'referral', label: 'Referral: 4,000 promo Diamonds for each referred sign-up', effort: 'Medium', time: '1–2 months', risk: 'Fraud (fake referrals)',
      how: 'Payers invite friends; the new user gets 4,000 promo Diamonds (30-day expiry). Needs device/phone checks like the free call.', cost: 'Host Beans on promo minutes (~₹12 per referral if fully used).',
      f: () => ({ referralRate: 0.3, referralPromoDiamonds: 4000 }) }
  ];

  function levers(params) {
    const base = run(params);
    return LEVERS.map(l => {
      const r = run(Object.assign({}, params, l.f(params)));
      return { id: l.id, label: l.label, effort: l.effort, time: l.time, risk: l.risk, how: l.how, cost: l.cost,
        delta: r.cumOperatingProfit - base.cumOperatingProfit, m6Delta: r.m6.operatingProfit - base.m6.operatingProfit,
        capitalDelta: r.minCapital - base.minCapital, cumOperatingProfit: r.cumOperatingProfit, m6Op: r.m6.operatingProfit,
        hostEarnDelta: r.m6.earningsPerHost - base.m6.earningsPerHost };
    }).sort((x, y) => y.m6Delta - x.m6Delta);
  }

  function leverOverrides(params, ids) {
    let o = {};
    for (const l of LEVERS) if (ids.includes(l.id)) o = Object.assign(o, l.f(Object.assign({}, params, o)));
    return o;
  }

  // Unit economics for one fully spent package at a rate (Phase 6 tables).
  function packageEconomics(params, rate) {
    const p = Object.assign(defaults('base'), params || {});
    const fx = p.usdInr;
    return packagesFor(p).map(pk => {
      const minutes = pk.diamonds / rate;
      const gst = pk.price * p.gstRate / (1 + p.gstRate);
      const exGst = pk.price - gst;
      const play = p.playFee * (p.playFeeOnGross ? pk.price : exGst);
      const host = pk.diamonds * HOST_RUPEES_PER_DIAMOND * p.hostShareMultiplier;
      const video = 2 * minutes * p.streamPer1000 / 1000 * fx;
      const calls = minutes / p.avgCallMinutes;
      const frames = 2 * exact.framesPerParticipant(Math.round(p.avgCallMinutes * 60)) * calls;
      const moderation = frames * 0.002 * p.sightengineMultiplier * fx;
      const reserve = pk.price * (p.refundRate + p.chargebackRate) / (1 + p.gstRate);
      const contribution = exGst - play - host - video - moderation - reserve;
      return { id: pk.id, label: pk.label, price: pk.price, diamonds: pk.diamonds, paisePerDiamond: pk.price / pk.diamonds * 100,
        minutes, perMinute: pk.price / minutes, gst, exGst, play, host, video, moderation, reserve, contribution,
        contributionPct: contribution / pk.price, hostShareOfPrice: host / pk.price, hostShareOfExGst: host / exGst };
    });
  }

  // Minimum viable rate: lowest D/min where a 1-minute connected call still covers
  // its direct cost (host Beans + Stream + moderation) — always true because host
  // Beans scale with Diamonds. Report the platform's net per minute instead.
  function perMinute(params, rate) {
    const p = Object.assign(defaults('base'), params || {});
    const r = run(p); const u = r.unit;
    const customer = rate * u.grossPerDiamond;
    const exGst = rate * u.exGstPerDiamond;
    const play = p.playFee * (p.playFeeOnGross ? customer : exGst);
    const host = rate * u.hostRupeesPerDiamond;
    const stream = 2 * p.streamPer1000 / 1000 * p.usdInr;
    const frames = 2 * exact.framesPerParticipant(Math.round(p.avgCallMinutes * 60)) / p.avgCallMinutes;
    const mod = frames * 0.002 * p.sightengineMultiplier * p.usdInr;
    return { rate, customer, exGst, play, host, stream, mod, net: exGst - play - host - stream - mod, hostPerHour: host * 60 };
  }

  // ------------------------------------------------------------- FORMATTING
  function inr(x, digits) {
    if (x == null || !isFinite(x)) return '—';
    const neg = x < 0; const v = Math.abs(x);
    let s;
    if (v >= 1e7) s = '₹' + (v / 1e7).toFixed(2) + ' Cr';
    else if (v >= 1e5) s = '₹' + (v / 1e5).toFixed(2) + ' L';
    else s = '₹' + v.toLocaleString('en-IN', { maximumFractionDigits: digits == null ? 0 : digits, minimumFractionDigits: digits == null ? 0 : digits });
    return (neg ? '−' : '') + s;
  }
  function inrFull(x) { if (x == null || !isFinite(x)) return '—'; return (x < 0 ? '−' : '') + '₹' + Math.round(Math.abs(x)).toLocaleString('en-IN'); }
  function pct(x, d) { if (x == null || !isFinite(x)) return '—'; return (x * 100).toFixed(d == null ? 1 : d) + '%'; }
  function num(x, d) { if (x == null || !isFinite(x)) return '—'; return x.toLocaleString('en-IN', { maximumFractionDigits: d || 0, minimumFractionDigits: d || 0 }); }

  // ------------------------------------------------------------------ EXPORT
  const CSV_COLUMNS = [
    ['month', 'Month'], ['totalRegistered', 'Total registered customers'], ['newRegistrations', 'New registrations'], ['mau', 'Monthly active customers'], ['dau', 'Daily active customers'],
    ['payingCustomers', 'Paying customers'], ['newPayers', 'New paying customers'], ['purchases', 'Diamond purchases'], ['grossPurchaseValue', 'Gross Diamond purchase value (₹, incl GST)'],
    ['refunds', 'Refunds (₹)'], ['gstOnSales', 'GST on sales (₹)'], ['playFee', 'Google Play fees deducted (₹, cash)'], ['playFeeExpense', 'Google Play fees expensed (₹, matched to use)'], ['topUpPurchases', 'Top-up purchases'], ['netPaymentProceeds', 'Net payment proceeds (₹)'], ['chargebacks', 'Chargebacks (₹)'],
    ['diamondsPurchased', 'Diamonds purchased'], ['diamondsConsumed', 'Diamonds consumed'], ['revenueRecognized', 'Revenue recognised (₹, ex GST)'],
    ['paidMinutes', 'Paid call minutes'], ['connectedCalls', 'Connected paid calls'], ['failedCalls', 'Failed / declined calls'], ['freeCallsStarted', 'Free calls started'], ['freeCallsCompleted', 'Free calls completed (host paid)'],
    ['activeHosts', 'Active hosts'], ['hostUtilization', 'Host utilisation'], ['callsPerHost', 'Calls per host'], ['earningsPerHost', 'Earnings per active host (₹)'],
    ['hostEarningsPaid', 'Host earnings, paid calls (₹)'], ['freeCallComp', 'Free-call host compensation (₹)'], ['hostEarnings', 'Host earnings expense (₹)'],
    ['streamCost', 'Stream video (₹)'], ['moderationApiCost', 'Sightengine moderation (₹)'], ['humanReviewCost', 'Human report review (₹)'], ['chargebackLoss', 'Chargeback loss (₹)'],
    ['smsCost', 'OTP SMS (₹)'], ['infraCloud', 'Cloud plans: Supabase, Cloud Run, GCP (₹)'], ['infraVariable', 'Variable infrastructure (₹)'], ['supportCost', 'Customer support (₹)'], ['hostOnboardingCost', 'Host KYC review (₹)'],
    ['fixedOps', 'Fixed operating costs (₹)'], ['marketing', 'Marketing (₹)'], ['oneTime', 'One-time setup (₹)'],
    ['variableInfra', 'Variable infrastructure total (₹)'], ['fixedCosts', 'Fixed costs incl. cloud plans (₹)'],
    ['grossProfit', 'Gross profit (₹)'], ['grossMargin', 'Gross margin'], ['contribution', 'Contribution (₹)'], ['contributionMargin', 'Contribution margin'],
    ['operatingProfit', 'Operating profit (₹)'], ['totalExpenses', 'Total expenses (₹)'], ['cashFromGoogle', 'Cash received from Google (₹)'], ['gstPaid', 'GST paid (₹)'], ['hostPayouts', 'Host payouts (₹)'],
    ['netCashFlow', 'Net cash flow (₹)'], ['closingCash', 'Closing cash (₹)'], ['googleReceivable', 'Owed by Google (₹)'], ['gstPayable', 'GST payable (₹)'],
    ['diamondLiability', 'Unspent Diamond liability (₹, ex GST)'], ['beanLiability', 'Unpaid host Bean liability (₹)'], ['cashAfterHostLiability', 'Cash after host liability (₹)'],
    ['arppu', 'ARPPU (₹ purchases per payer)'], ['arpmau', 'Revenue per MAU (₹)'], ['costPerMau', 'Cost per MAU (₹)']
  ];
  function toCSV(results) {
    const head = ['Scenario'].concat(CSV_COLUMNS.map(c => c[1]));
    const lines = [head.map(csvCell).join(',')];
    for (const [name, res] of results) for (const r of res.months) {
      lines.push([name].concat(CSV_COLUMNS.map(([k]) => { const v = r[k]; return typeof v === 'number' ? (Math.abs(v) < 10 && k.match(/Margin|Utilization/) ? v.toFixed(4) : (Math.round(v * 100) / 100).toString()) : (v == null ? '' : v); })).map(csvCell).join(','));
    }
    return lines.join('\n') + '\n';
  }
  function csvCell(v) { const s = String(v); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s; }

  function assumptionsDocument(paramsByScenario, startDate) {
    return {
      model: 'Dashuri six-month financial model', version: '1.0', generated: startDate || null,
      currency: 'INR', note: 'Every value is editable in DASHURI_FINANCIAL_SIMULATOR.html. status: code = read from the implementation; verified = official source on the date given; unverified = partial or third-party source; estimate = no data, reasoned; placeholder = get a quote; decision = founder setting.',
      implementedRules: RULES, diamondPackages: PACKAGES.map(p => ({ product_id: p.id, label: p.label, diamonds: p.diamonds, price_inr_incl_gst: p.pricePaise / 100, paise_per_diamond: +(p.pricePaise / p.diamonds).toFixed(4), provisional: true })),
      assumptions: ASSUMPTIONS.filter(x => !x.hidden).map(x => ({ key: x.key, group: x.group, label: x.label, unit: x.unit,
        conservative: paramsByScenario ? paramsByScenario.conservative[x.key] : x.values.conservative,
        base: paramsByScenario ? paramsByScenario.base[x.key] : x.values.base,
        optimistic: paramsByScenario ? paramsByScenario.optimistic[x.key] : x.values.optimistic,
        status: x.status, verified: x.status === 'code' || x.status === 'verified', confidence: x.confidence, source: x.source, rationale: x.why }))
    };
  }

  return { RULES, PACKAGES, exact, ASSUMPTIONS, SCENARIOS, SCENARIO_LABEL, MONTHS, BEANS_PER_DIAMOND, HOST_RUPEES_PER_DIAMOND,
    defaults, run, sensitivity, stress, levers, leverOverrides, LEVERS, STRESS, packageEconomics, perMinute, tiltedMix, packagesFor,
    inr, inrFull, pct, num, toCSV, CSV_COLUMNS, assumptionsDocument, sightengineUsd };
});
