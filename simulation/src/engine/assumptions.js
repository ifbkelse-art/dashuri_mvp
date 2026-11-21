// Dashuri six-month simulation: inputs, sources and scenario definitions.
// Every number here is either a founder decision, a verified external price,
// or a labelled hypothesis. Nothing here is a market forecast.

export const RETRIEVED = '2026-11-17';

// Evidence labels used throughout the model and dashboard.
export const STATUS = {
  FOUNDER: 'Founder decision',
  VERIFIED: 'Verified (official source)',
  VENDOR: 'Vendor-published, single source',
  UNVERIFIED: 'UNVERIFIED',
  HYPOTHESIS: 'Hypothesis (no data)',
  PLACEHOLDER: 'Placeholder (get quotes)',
  PRO: 'Requires CA / lawyer review',
};

export const SOURCES = [
  { id: 'play-fee', name: 'Google Play service fees', url: 'https://support.google.com/googleplay/android-developer/answer/112622?hl=en', unit: '% of eligible revenue', conditions: '"15% for the first $1M (USD) revenue earned by the developer each year" in "all remaining markets" (India not in AU/EEA/JP/UK/US new schedule). Enrolment required. 30% above $1M.', status: STATUS.VERIFIED },
  { id: 'play-ucb', name: 'Google Play alternative billing (India)', url: 'https://support.google.com/googleplay/android-developer/answer/13306652', unit: 'fee reduction', conditions: 'Fee "reduced by 4%"; ambiguous (points vs relative). Requires PCI DSS, 24 h reporting. NOT assumed available to Dashuri.', status: STATUS.VERIFIED },
  { id: 'play-payout', name: 'Google Payments payout schedule', url: 'https://support.google.com/paymentscenter/answer/7159355', unit: 'date', conditions: 'Payouts start the 15th of each month for the previous month\'s sales; EFT 2–3, wire 5–7 business days.', status: STATUS.VERIFIED },
  { id: 'play-billing', name: 'Google Play Payments policy', url: 'https://support.google.com/googleplay/android-developer/answer/9858738', unit: 'policy', conditions: 'Virtual currencies must use Play Billing.', status: STATUS.VERIFIED },
  { id: 'play-refund', name: 'Google Play refunds (developer help)', url: 'https://support.google.com/googleplay/android-developer/answer/2741495', unit: 'policy', conditions: 'Refunds subtracted from payouts; service fee returned on refunds. Developer-borne chargebacks for orders after 3 Aug 2026 and bank chargeback fees reported by third parties only.', status: STATUS.UNVERIFIED },
  { id: 'play-gst', name: 'Google Payments: GST on Indian sales', url: 'https://support.google.com/paymentscenter/answer/7421525', unit: 'policy', conditions: 'India-address developers "may be responsible" for GST; other Google pages say Google collects. Conflicting.', status: STATUS.PRO },
  { id: 'stream', name: 'Stream Video pricing guide', url: 'https://getstream.io/video/docs/api/pricing-guide/', unit: 'USD per 1,000 participant-minutes', conditions: 'HD 720p $1.50, SD $0.75, audio $0.30; $100/month free usage; tier set by aggregate received resolution.', status: STATUS.VERIFIED },
  { id: 'supabase', name: 'Supabase pricing', url: 'https://supabase.com/pricing', unit: 'USD per month', conditions: 'Pro from $25/mo; $10 compute credit; 8 GB disk; 250 GB egress; 100k MAU; 100 GB storage; spend cap on by default.', status: STATUS.VERIFIED },
  { id: 'cloudrun', name: 'Google Cloud Run pricing', url: 'https://cloud.google.com/run/pricing', unit: 'USD per vCPU-s / GiB-s / request', conditions: 'Official page did not render. Secondary: Tier 1 $0.000024/vCPU-s, $0.0000025/GiB-s, $0.40/M requests, free tier 180k vCPU-s. asia-south1 tier unknown.', status: STATUS.UNVERIFIED },
  { id: 'sightengine', name: 'Sightengine pricing', url: 'https://sightengine.com/pricing', unit: 'USD per operation', conditions: 'Starter $29/mo 10k ops; Pro $99/mo 40k ops; overage $0.002/op; 1 nudity check on 1 image = 1 op. Video frames counting not stated.', status: STATUS.VENDOR },
  { id: 'vision', name: 'Google Cloud Vision SafeSearch', url: 'https://cloud.google.com/vision/pricing', unit: 'USD per 1,000 images', conditions: 'About $1.50/1,000 after 1,000 free (secondary sources; official table not rendered).', status: STATUS.UNVERIFIED },
  { id: 'otp', name: 'OTP SMS India (third-party comparison)', url: 'https://www.messagecentral.com/en-in/blog/sms-otp-pricing-india', unit: 'INR per SMS', conditions: 'About ₹0.15–0.25 + 18% GST + DLT fees. Competitor-written.', status: STATUS.UNVERIFIED },
  { id: 'kyc', name: 'eKYCNow pricing', url: 'https://www.messagecentral.com/en-in/product/ekyc-now/pricing/india', unit: 'INR per verification', conditions: '₹10 offline Aadhaar; ₹18 with liveness. Single vendor; others unquoted.', status: STATUS.VENDOR },
  { id: 'cashfree-payouts', name: 'Cashfree Payouts', url: 'https://www.cashfree.com/en/payouts/', unit: 'INR per transfer', conditions: 'Table ₹6/₹8/₹15 per IMPS/UPI by band, labelled "Wallets/Connected BaaS"; help centre says custom pricing. Category acceptance NOT confirmed.', status: STATUS.UNVERIFIED },
  { id: 'cashfree-prohibited', name: 'Cashfree prohibited businesses', url: 'https://www.cashfree.com/docs/help/account/faq', unit: 'policy', conditions: 'Prohibits adult/sexually suggestive services; dating/chat not listed; deactivation at discretion.', status: STATUS.VERIFIED },
  { id: 'founder', name: 'Founder decisions (discovery log)', url: 'docs/discovery-log.md', unit: '—', conditions: 'Rounds 1–3, audit, and the 2026-11-17 simulation brief.', status: STATUS.FOUNDER },
];

// Founder-confirmed constants (2026-11-17 simulation brief).
export const CONSTANTS = {
  gstRate: 0.18,
  beansPerDiamondNumerator: 10000, // 16,670 Diamonds spent = 10,000 Beans
  beansPerDiamondDenominator: 16670,
  inrPerBean: 0.005,
  minWithdrawInr: 500,
  holdDays: 7,
  payoutIntervalDays: 7,
  freeCallHostInr: 10,
  freeCallsPerHostPerDay: 20,
  freeCallSeconds: 60,
  minRate: 500,
  maxRate: 10000,
  daysPerMonth: 30, // modelling convention: 30-day months, 180 days
  months: 6,
};

// Proposed Diamond packages (evaluation set, not final prices).
export const DEFAULT_PACKAGES = [
  { name: 'Starter', price: 99, diamonds: 4000 },
  { name: 'Small', price: 299, diamonds: 12500 },
  { name: 'Medium', price: 599, diamonds: 26000 },
  { name: 'Popular', price: 1199, diamonds: 54000 },
  { name: 'Large', price: 2999, diamonds: 140000 },
  { name: 'Premium', price: 5999, diamonds: 290000 },
];

// Proposed XP thresholds (P12, NOT approved). Level n requires XP >= thresholds[n-1].
export const DEFAULT_XP_THRESHOLDS = [0, 32000, 100000, 250000, 600000, 1500000, 3500000, 8000000, 18000000, 40000000];

// Proposed host rate ladders (NOT approved). Max Diamonds/min allowed at levels 1..10.
// All respect the founder's 500–10,000 range.
export const RATE_LADDERS = {
  A: { name: 'A · Gradual', max: [1000, 1500, 2000, 3000, 4000, 5000, 6000, 7500, 9000, 10000] },
  B: { name: 'B · Fast start', max: [2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000, 10000] },
  C: { name: 'C · Narrow start', max: [500, 1000, 1500, 2000, 2500, 3000, 4000, 5000, 7500, 10000] },
};

// Parameter metadata: label, unit, group, evidence status, note.
export const PARAM_META = {
  installsM1: { label: 'Installs in Month 1', unit: 'installs', group: 'Acquisition', status: STATUS.HYPOTHESIS, note: 'Founder manages marketing; no install data exists.' },
  installGrowth: { label: 'Monthly install growth', unit: '×/month', group: 'Acquisition', status: STATUS.HYPOTHESIS, pct: true },
  cacPerInstall: { label: 'Acquisition cost per install (what-if)', unit: '₹', group: 'Acquisition', status: STATUS.HYPOTHESIS, note: 'Default 0: no CAC data and no marketing budget given. The model reports the break-even CAC instead.' },
  registrationRate: { label: 'Install → registered (OTP)', unit: '', group: 'Customer funnel', status: STATUS.HYPOTHESIS, pct: true },
  eligibilityRate: { label: 'Registered → eligible (18+, checks)', unit: '', group: 'Customer funnel', status: STATUS.HYPOTHESIS, pct: true },
  freeCardUseRate: { label: 'Eligible users who use Free Call Card', unit: '', group: 'Free Call Card', status: STATUS.HYPOTHESIS, pct: true },
  freeCallCompleteRate: { label: 'Free calls completed (eligible minute)', unit: '', group: 'Free Call Card', status: STATUS.HYPOTHESIS, pct: true },
  freeToPaidRate: { label: 'Free-call user → first purchase', unit: '', group: 'Free Call Card', status: STATUS.HYPOTHESIS, pct: true, note: 'Unknown. The key acquisition lever.' },
  nonCardPayRate: { label: 'Other eligible user → first purchase', unit: '', group: 'Customer funnel', status: STATUS.HYPOTHESIS, pct: true },
  lateConversionRate: { label: 'Non-payer converts in a later month', unit: '/month', group: 'Customer funnel', status: STATUS.HYPOTHESIS, pct: true },
  userRetention: { label: 'Non-paying user active next month', unit: '', group: 'Customer funnel', status: STATUS.HYPOTHESIS, pct: true },
  payerRetention: { label: 'Paying customer buys again next month', unit: '', group: 'Spending', status: STATUS.HYPOTHESIS, pct: true },
  purchasesPerPayer: { label: 'Top-ups per active payer per month', unit: 'top-ups', group: 'Spending', status: STATUS.HYPOTHESIS },
  walletBurnPerDay: { label: 'Active wallet spent per day (if hosts free)', unit: '/day', group: 'Spending', status: STATUS.HYPOTHESIS, pct: true },
  dormantBurnPerDay: { label: 'Lapsed-customer wallet spent per day', unit: '/day', group: 'Spending', status: STATUS.HYPOTHESIS, pct: true },
  avgPaidCallMin: { label: 'Average paid call length', unit: 'min', group: 'Calls', status: STATUS.HYPOTHESIS },
  acceptRate: { label: 'Host accepts incoming call', unit: '', group: 'Calls', status: STATUS.HYPOTHESIS, pct: true },
  connectRate: { label: 'Accepted call connects (both streams)', unit: '', group: 'Calls', status: STATUS.HYPOTHESIS, pct: true },
  interruptionShare: { label: 'Connected time paused & credited', unit: '', group: 'Calls', status: STATUS.HYPOTHESIS, pct: true, note: 'Exact interruption thresholds are a technical assumption, not a founder decision.' },
  hostsByMonth: { label: 'Active hosts by month (capacity input)', unit: 'hosts', group: 'Host supply', status: STATUS.HYPOTHESIS, note: 'Recruitment is founder-managed. This is a capacity assumption, not a plan.' },
  hostOnlineHours: { label: 'Hours online per host on days online', unit: 'h', group: 'Host supply', status: STATUS.HYPOTHESIS },
  hostDailyAvailability: { label: 'Chance a host comes online on a day', unit: '', group: 'Host supply', status: STATUS.HYPOTHESIS, pct: true },
  maxUtilisation: { label: 'Max share of online time in calls', unit: '', group: 'Host supply', status: STATUS.HYPOTHESIS, pct: true },
  hostChurn: { label: 'Hosts replaced per month (new KYC)', unit: '/month', group: 'Host supply', status: STATUS.HYPOTHESIS, pct: true },
  freePoolOptIn: { label: 'Hosts opted into Free Call pool', unit: '', group: 'Host supply', status: STATUS.HYPOTHESIS, pct: true },
  ratePositioning: { label: 'Host rate as share of level maximum', unit: '', group: 'Pricing', status: STATUS.HYPOTHESIS, pct: true },
  ladder: { label: 'Rate ladder (proposal)', unit: '', group: 'Pricing', status: 'Proposal, NOT approved' },
  inrPerBean: { label: 'Bean value', unit: '₹/Bean', group: 'Pricing', status: STATUS.FOUNDER },
  withdrawProb: { label: 'Eligible host withdraws at weekly payout', unit: '', group: 'Payouts', status: STATUS.HYPOTHESIS, pct: true },
  refundRate: { label: 'Top-ups refunded before use', unit: '', group: 'Risk', status: STATUS.HYPOTHESIS, pct: true },
  chargebackRate: { label: 'Top-ups charged back after use (incl. fraud)', unit: '', group: 'Risk', status: STATUS.HYPOTHESIS, pct: true },
  chargebackFeeInr: { label: 'Bank chargeback fee per case', unit: '₹', group: 'Risk', status: STATUS.UNVERIFIED, note: 'Third-party reports of $15–25 per case for orders after 3 Aug 2026.' },
  clawbackShare: { label: 'Host Beans recovered on chargeback', unit: '', group: 'Risk', status: STATUS.HYPOTHESIS, pct: true },
  promoDiamondsPerNewUser: { label: 'Promotional Diamonds per new user', unit: 'D', group: 'Risk', status: 'Not decided (default 0)' },
  playFeeRate: { label: 'Google Play service fee', unit: '', group: 'Fees & tax', status: STATUS.VERIFIED, pct: true },
  feeBase: { label: 'Play fee charged on', unit: '', group: 'Fees & tax', status: STATUS.UNVERIFIED },
  gstMode: { label: 'GST treatment', unit: '', group: 'Fees & tax', status: STATUS.PRO },
  socialLevyRate: { label: 'Social-security levy (if notified)', unit: '% turnover', group: 'Fees & tax', status: STATUS.PRO, pct: true },
  settlementDay: { label: 'Google payout day of next month', unit: 'day', group: 'Settlement', status: STATUS.VERIFIED },
  bankTransitDays: { label: 'Bank transit after payout', unit: 'days', group: 'Settlement', status: STATUS.VERIFIED },
  fxInrPerUsd: { label: 'Exchange rate', unit: '₹ per US$', group: 'Costs', status: STATUS.HYPOTHESIS },
  videoUsdPer1000: { label: 'Video price per 1,000 participant-min', unit: 'US$', group: 'Costs', status: STATUS.VERIFIED },
  streamFreeCreditUsd: { label: 'Stream monthly free usage', unit: 'US$', group: 'Costs', status: STATUS.VERIFIED },
  moderationUsdPerFrame: { label: 'Nudity check price per frame', unit: 'US$', group: 'Costs', status: STATUS.UNVERIFIED },
  moderationFramesPerMin: { label: 'Frames checked per minute per stream', unit: 'frames', group: 'Costs', status: STATUS.HYPOTHESIS },
  moderationStreams: { label: 'Streams checked per call', unit: 'streams', group: 'Costs', status: STATUS.HYPOTHESIS },
  moderationMinutes: { label: 'Bot-moderated minutes per call', unit: 'min', group: 'Costs', status: STATUS.FOUNDER },
  reportsPer1000Calls: { label: 'Reports per 1,000 calls', unit: 'reports', group: 'Costs', status: STATUS.HYPOTHESIS },
  reviewCostPerReport: { label: 'Human review cost per report', unit: '₹', group: 'Costs', status: STATUS.HYPOTHESIS },
  safetyOpsMonthlyInr: { label: 'Safety operations (on-call takedown cover)', unit: '₹/month', group: 'Costs', status: STATUS.HYPOTHESIS, note: 'IT Rules 2026 reportedly require 2-hour takedown of intimate imagery on complaint; someone must be reachable.' },
  otpInrPerSms: { label: 'OTP price per SMS (incl. GST)', unit: '₹', group: 'Costs', status: STATUS.UNVERIFIED },
  smsPerRegistration: { label: 'SMS per registration', unit: 'SMS', group: 'Costs', status: STATUS.HYPOTHESIS },
  kycInrPerHost: { label: 'KYC + liveness per new host (incl. retries)', unit: '₹', group: 'Costs', status: STATUS.VENDOR },
  payoutFeeInr: { label: 'Payout transfer fee', unit: '₹/payout', group: 'Costs', status: STATUS.UNVERIFIED, note: 'No payout provider has accepted Dashuri. Launch blocker.' },
  supabaseUsd: { label: 'Supabase Pro', unit: 'US$/month', group: 'Costs', status: STATUS.VERIFIED },
  cloudRunUsd: { label: 'Cloud Run (Go API)', unit: 'US$/month', group: 'Costs', status: STATUS.UNVERIFIED },
  otherFixedInr: { label: 'Domain, monitoring, misc. tools', unit: '₹/month', group: 'Costs', status: STATUS.HYPOTHESIS },
  preLaunchInr: { label: 'Pre-launch: incorporation, CA, lawyer', unit: '₹ once', group: 'Costs', status: STATUS.PLACEHOLDER },
};

const common = {
  cacPerInstall: 0,
  ladder: 'A',
  inrPerBean: 0.005,
  promoDiamondsPerNewUser: 0,
  playFeeRate: 0.15,
  feeBase: 'net', // 'net' = on GST-exclusive price, 'gross' = on price paid
  gstMode: 'dashuri', // 'dashuri' | 'google' | 'agent'
  socialLevyRate: 0,
  settlementDay: 15,
  bankTransitDays: 5,
  fxInrPerUsd: 88,
  videoUsdPer1000: 1.5,
  streamFreeCreditUsd: 100,
  moderationUsdPerFrame: 0.0015,
  moderationFramesPerMin: 6,
  moderationStreams: 2,
  moderationMinutes: 3,
  otpInrPerSms: 0.25,
  smsPerRegistration: 1.3,
  kycInrPerHost: 25,
  payoutFeeInr: 8,
  supabaseUsd: 25,
  cloudRunUsd: 20,
  otherFixedInr: 1500,
  preLaunchInr: 100000,
  chargebackFeeInr: 1500,
  maxUtilisation: 0.6,
  withdrawProb: 0.9,
};

export const DEFAULT_SCENARIOS = {
  worst: {
    ...common,
    name: 'Worst case',
    installsM1: 2500, installGrowth: 0.10,
    registrationRate: 0.55, eligibilityRate: 0.93,
    freeCardUseRate: 0.5, freeCallCompleteRate: 0.75, freeToPaidRate: 0.03,
    nonCardPayRate: 0.01, lateConversionRate: 0.005, userRetention: 0.2,
    payerRetention: 0.25, purchasesPerPayer: 1.2,
    packageMix: [0.40, 0.30, 0.15, 0.10, 0.04, 0.01],
    walletBurnPerDay: 0.08, dormantBurnPerDay: 0.003,
    avgPaidCallMin: 3.0, acceptRate: 0.75, connectRate: 0.92, interruptionShare: 0.04,
    hostsByMonth: [8, 10, 12, 14, 16, 18], hostOnlineHours: 2, hostDailyAvailability: 0.55,
    hostChurn: 0.25, freePoolOptIn: 0.5, ratePositioning: 0.8,
    refundRate: 0.02, chargebackRate: 0.04, clawbackShare: 0.4,
    reportsPer1000Calls: 8, reviewCostPerReport: 40, safetyOpsMonthlyInr: 25000,
    moderationUsdPerFrame: 0.002, videoUsdPer1000: 1.5,
  },
  base: {
    ...common,
    name: 'Base case',
    installsM1: 5000, installGrowth: 0.20,
    registrationRate: 0.6, eligibilityRate: 0.95,
    freeCardUseRate: 0.6, freeCallCompleteRate: 0.8, freeToPaidRate: 0.06,
    nonCardPayRate: 0.015, lateConversionRate: 0.01, userRetention: 0.25,
    payerRetention: 0.35, purchasesPerPayer: 1.5,
    packageMix: [0.30, 0.30, 0.20, 0.12, 0.06, 0.02],
    walletBurnPerDay: 0.10, dormantBurnPerDay: 0.005,
    avgPaidCallMin: 4.5, acceptRate: 0.85, connectRate: 0.95, interruptionShare: 0.02,
    hostsByMonth: [12, 18, 24, 30, 36, 42], hostOnlineHours: 2.5, hostDailyAvailability: 0.65,
    hostChurn: 0.15, freePoolOptIn: 0.6, ratePositioning: 0.85,
    refundRate: 0.01, chargebackRate: 0.02, clawbackShare: 0.5,
    reportsPer1000Calls: 5, reviewCostPerReport: 30, safetyOpsMonthlyInr: 15000,
  },
  best: {
    ...common,
    name: 'Best case',
    installsM1: 10000, installGrowth: 0.30,
    registrationRate: 0.65, eligibilityRate: 0.96,
    freeCardUseRate: 0.7, freeCallCompleteRate: 0.85, freeToPaidRate: 0.10,
    nonCardPayRate: 0.02, lateConversionRate: 0.015, userRetention: 0.3,
    payerRetention: 0.45, purchasesPerPayer: 1.8,
    packageMix: [0.25, 0.28, 0.22, 0.14, 0.08, 0.03],
    walletBurnPerDay: 0.12, dormantBurnPerDay: 0.006,
    avgPaidCallMin: 6.0, acceptRate: 0.9, connectRate: 0.97, interruptionShare: 0.015,
    hostsByMonth: [20, 30, 45, 60, 75, 90], hostOnlineHours: 3, hostDailyAvailability: 0.7,
    hostChurn: 0.10, freePoolOptIn: 0.7, ratePositioning: 0.9,
    refundRate: 0.008, chargebackRate: 0.01, clawbackShare: 0.6,
    reportsPer1000Calls: 4, reviewCostPerReport: 30, safetyOpsMonthlyInr: 15000,
  },
};

export const SCENARIO_KEYS = ['worst', 'base', 'best'];
export const SEEDS = { worst: [1101, 1102, 1103, 1104, 1105], base: [2201, 2202, 2203, 2204, 2205], best: [3301, 3302, 3303, 3304, 3305] };

export function cloneScenario(s) {
  return JSON.parse(JSON.stringify(s));
}
