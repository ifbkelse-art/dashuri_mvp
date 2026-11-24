# Dashuri monetization audit report

**Date:** 24 Nov 2026 · **Scope:** monetization maths, ledger design, reversals, concurrency, financial model, compliance dependencies · **Method:** repository inspection, test execution, independent recomputation, a PostgreSQL prototype in a throwaway cluster, official sources · **Boundary:** research and documentation only. No application code, migration, configuration, deployment, commit or push.

## 1. Verdict

**Not implementation-ready: NO.**

The arithmetic of the 5:4 model is correct, and a ledger design that keeps it exact under concurrency, reversals and payouts is now specified and prototyped on PostgreSQL. Four things are still missing:
1. **Founder approval.** Only the 5:4 ratio is approved, and only for modelling.
2. **Store-policy clearance.** Google Play prohibits apps that facilitate compensated arrangements where one participant pays another. Dashuri's pay-per-minute 1:1 video model needs a policy review.
3. **CA/legal answers** on GST, TDS/TCS, RBI framing and consumer law.
4. **Evidence** from Play Console, the SMS provider and the payout provider.

The economics are positive per call in every tested case. They are **not** proven at the business level, because demand is unmeasured and the severe-downside case loses money at every scale.

## 2. What is verified

| Item | How |
|---|---|
| Existing ledger is double-entry, append-only, balanced per currency, with non-negative user buckets | Read `…_economy_and_ledger.sql`, `postgres/ledger.go`; 223 integration tests pass on real PostgreSQL |
| Existing settlement is exactly-once under concurrency | `TestParallelEndAndStaleSweepSettleOnce`, `TestPostEntryExactlyOnceUnderConcurrency` (PASS) |
| Purchases credited once under concurrency; voided purchases remove only unspent Diamonds | `TestPlayPurchaseCreditedOnceUnderConcurrency`, `TestVoidedPurchaseReversesOnlyUnspent` (PASS) |
| 5:4 at ₹0.005 = ₹0.004 per Diamond; +33.36% vs 16,670 → 10,000 (exact 417/1250) | Exact fractions, asserted in the model |
| Model arithmetic | Independent hand re-derivation of the 1-minute base call equals the model exactly (₹15.2748) |
| Carry design: exact, order-independent, idempotent, concurrency-safe | 22 Python tests; **29 PostgreSQL prototype checks × 25 runs, no deadlocks** |
| Provider facts | Official sources: Stream, Sightengine, Supabase, Cloud Run (Mumbai = Tier 1), Cashfree, Play fee schedule and 15%-tier enrolment rule, 194-O, GST slabs, RBI PPI definition |
| Deployed infrastructure | Read-only: Cloud Run min 0/max 1; Supabase Free; no Redis; ₹100 budget alert |

## 3. Corrections to earlier documents

| Earlier claim (v1–v3) | Finding | Severity |
|---|---|---|
| "Refunds: held Beans clawed back" [CODE] | **`ledger.BeanClawback` has no caller.** A chargeback today removes unspent Diamonds and reverses XP, but **never claws back host Beans** | High (before any real money) |
| "Idempotent on the key" | `PostEntry` treats a duplicate key as a replay **without comparing the payload**. A different payload under a reused key would be silently accepted | High |
| "Purchase reversal removes that purchase's unspent Diamonds" | It removes `min(purchase D, pooled purchased balance − committed)`. There are no lots, so it can remove Diamonds bought in another purchase | Medium |
| "Release per source entry" | Release posts `min(credit, current held)` per entry. After a clawback this could leave part of a later call's Beans held forever (latent; clawback is unused today) | Medium (latent) |
| "Price paid is known" | `commerce.purchases` has **no price column**; the price is read from the packages table, so a later price change would make history ambiguous | Medium |
| Caller ≈ ₹/min | Shows the Starter rate to everyone (up to 19.6% above a Premium buyer's price; prices free Diamonds) | Medium (consumer law) |

## 4. Mathematically correct

- 5:4 conversion, carry and reversal formulas (§4 and §8 of the spec), including the ⌈4D/5⌉ claw bound.
- Pack host shares 16.2–19.3%; per-call unit economics; break-even search (bisection per monotone segment, verified at k − 1 and k).
- Reserve formula: units check. Every term is in rupees:

| Term | Calculation | Unit |
|---|---|---|
| Whole Beans | Beans × ₹0.005 | ₹ |
| Carry | fifths ÷ 5 × ₹0.005 | ₹ |
| Promotional Diamonds | Diamonds × ₹0.004 | ₹ |
| Taxes | rupees | ₹ |

  **It is sufficient** under the proposed reversal model only if all three conditions hold:
  1. receivables are not netted;
  2. payouts are held when a receivable appears before submission;
  3. a refund/chargeback cash reserve is added for Google debits on recent sales.

  The third is missing from v3. **Add `loss_rate × last 120 days of sales`** (Play/card dispute horizon, CA/Play to confirm).

## 5. Not yet proven

- **Production code:** the Go/SQL design is specified and prototyped in PL/pgSQL, not implemented in the service.
- **Demand:** paid minutes per payer, average rate, call length, sign-ups per payer and refund rate are all estimates. Every contribution margin and break-even figure is a **model output, not an audited fact**.
- **Play fee:** 15% is an assumption until Play Console shows 15%-tier enrolment.
- **Fee base:** inclusive or exclusive of GST, unknown.
- **GST timing and treatment, TDS section, TCS applicability:** CA.
- **Cloud Run asia-south1 live unit prices:** only the Tier 1 classification is verified.
- **SMS price:** DLT quotes are third-party.
- **Payout provider fees:** a written quote is needed.

## 6. Financial viability (model, not fact)

| Scenario | 5-min call margin | 1,000 payers/month after Supabase + lean costs | Main driver |
|---|---:|---:|---|
| Optimistic | 52.3% | +₹7,64,611 | — |
| Base | 47.7% | +₹3,21,065 | — |
| Conservative (Twilio SMS) | 36.4% (Premium, 1,000 D/min) | −₹1,18,801 | OTP ₹207.20/payer |
| **Severe downside**: Play 30%, Twilio SMS, 30 sign-ups/payer, 8 paid min, 3-min calls, 5% loss, Stream $3, 10 vCPU-s/call | 21.5% (3-min call) | **−₹3,10,849** (staffed) | OTP ₹333/payer vs ₹44 contribution per payer before OTP |
| Severe downside but DLT SMS ₹0.25 | — | +₹32,976 contribution before fixed costs | — |

**One-at-a-time sensitivity** (1,000 payers, base, lean; base result ₹3,21,065):

| Change | Δ ₹/month |
|---|---:|
| Average rate 3,000 | +3,48,277 |
| 40 paid min | +3,16,158 |
| Average rate 500 | −2,32,185 |
| 10 paid min | −1,71,657 |
| Play fee 30% | −1,01,390 |
| Twilio SMS | −92,950 |
| Promo = 10% of consumption | −47,620 |
| Premium pack mix | −32,220 |
| 8% refund/chargeback | −29,029 |
| 2.5% conversion (40 sign-ups/payer) | −9,750 |
| 2-min calls | −8,758 |
| 1080p video tier | −2,923 |

**Ranked risks:** demand × price, then Play fee tier, then OTP provider, then promo volume.

## 7. Traceability matrix

| Rule | Research doc | Reference / prototype | Production code today | DB today | Tests | Status |
|---|---|---|---|---|---|---|
| 5 D → 4 B, ₹0.005 | math §6–7 | `monetization_ledger.py`; PG `p.settle` | **No**: `Founder()` uses 10000/16670, ½ paisa | `economy.rule_sets` (old) | Py 22; PG T1–T11 | Approved for modelling only |
| Per-host carry | math §8; spec §4 | Ledger `Host.carry`; PG `bean_carry` | No | No | Py; PG T10 | Proposed |
| Call-specific reversal + recovery order | spec §8 | `reverse()`; PG `p.reverse` | No (`BeanClawback` unused) | No | Py; PG T4–T6, T9, T11 | Proposed |
| Receivable + offset + withdrawal block | spec §8.3 | Yes | No | No | Py; PG T6 | Proposed |
| Fingerprinted idempotency | spec §6 | `_idem()`; PG `p.claim` | **Partial**: key only | `idempotency_key unique` | PG T2, T5, T8 | Proposed (fixes a gap) |
| Diamond lots / FIFO | spec §3 | Lots; PG `p.lots` | No (pooled buckets) | No | Py; PG T3, T9 | Proposed |
| Promo spent first, 30-day expiry | math §11 | Yes | Yes (`SpendOrder promotional_first`, TTL) | `promo_grant_expiries` | Go tests | Exists; spend order "UNRESOLVED" in code |
| Promo budget ≤ 3% | math §11 | No | No | No | — | Proposed |
| Free Call Card ₹10/2,000 B, 20/host/day | math §17 | No | **Yes, enabled in dev** (`FREE_CALL_ENABLED=true`) | `freecall.*` | Go tests | Exists; founder to decide (brief said "no free matching") |
| Account XP vs Host Level | math §12; spec §10 | No | Shared XP (8 × purchased + Beans earned + free-call) | `xp_events` | Go tests | Proposed |
| Price ceiling level × 1,000; > 3,000 Verified | VERIFIED_HOST_AND_PRICING | — | Yes | CHECK + API | Go tests | Exists (founder spec 23 Nov) |
| Hold 14 / 7 trusted | math §11 | `hold_days` | 7 days | rule set | — | Proposed (7 exists) |
| ₹500 minimum, weekly cycle | math §11 | Yes | ₹500 min exists; payouts off | rule set | `TestWithdrawalRefusedWhileDisabled…` | Min exists; rest proposed |
| Reserve formula | math §16 | `reserve()` | No | No | Py random test | Proposed (+ refund reserve) |
| Caller "your price" | math §21 | Model | No (Starter rate) | — | — | Proposed |
| INR finance journal | spec §2.4 | No | No | `INR_PAISE` allowed, unused | — | Proposed; CA-dependent |

## 8. Safe to implement later (after approval), low regret

- Fingerprinted idempotency in `PostEntry`.
- `price_paise` snapshot on purchases.
- Diamond lots and call funding.
- Per-call hold subledger.
- `CallReversal` with the recovery order.
- Receivable account and withdrawal block.
- Reconciliation checks.

Most of these fix gaps that matter whatever ratio is chosen.

## 9. Blocks a real-money launch (taking payments)

1. **Play policy review:** paid one-to-one video with strangers versus the compensated-arrangement prohibition. Also UGC moderation, Child Safety Standards self-certification, and the age gate.
2. **Play Console:** payments profile, 15%-tier enrolment, fee base.
3. **CA:** GST treatment and timing of Diamond sales; reverse charge on Google's fee; revenue recognition and breakage.
4. **Lawyer:**
   - consumer-protection review (E-Commerce Rules 2020 and the 2026 amendment; Dark Patterns Guidelines 2023), covering the ₹ display, promo expiry, the deletion forfeiture and refund terms;
   - RBI/PPI framing;
   - DPDP Act 2023 / Rules 2025 notices;
   - IT Rules 2021 grievance officer.
5. **Engineering:** fingerprinted idempotency; lot-based chargeback; host clawback (today none happens).
6. **Founder:** the conversion for implementation, the Free Call Card, the promo policy, and the "your price" display.

## 10. Blocks host payouts

Everything in §9, plus:
- incorporation;
- a payout provider with a written quote and KYC flow;
- the TDS section and GST TCS decision (CA);
- host terms (earning rule, deductions, receivables);
- the reserve policy, including the refund reserve;
- receivable handling and payout hold at submission;
- `PAYOUTS_ENABLED` switched on only by founder decision.

## 11. Requires founder approval

See the register (`dashuri_monetization_open_questions.md`, category B). In short:
- implementation of 5:4;
- the carry and reversal policy;
- recovering from available Beans;
- the receivable write-off period;
- Account XP / Host Level split and eligibility;
- the gates;
- promo policy and budget;
- Free Call Card;
- hold periods;
- withdrawals and fees;
- the reserve;
- the caller display;
- Supabase Pro;
- the SMS provider;
- Cloud Run minimum instances;
- the operating budget;
- engaging advisers.

## 12. Requires CA / lawyer confirmation

GST, Play fee base, TDS, TCS, PPI/RBI, revenue recognition and breakage, consumer protection, Play content policy, DPDP, IT Rules, host contract (principal vs agent).

## 13. Sources used in this audit (accessed 24 Nov 2026)

- [Cloud Run locations](https://docs.cloud.google.com/run/docs/locations) · [Cloud Run pricing](https://cloud.google.com/run/pricing)
- [Play service fees](https://support.google.com/googleplay/android-developer/answer/112622?hl=en) · [2021 fee change and 15%-tier enrolment](https://support.google.com/googleplay/android-developer/answer/10632485?hl=en) · [Lower service fees 2026](https://support.google.com/googleplay/android-developer/answer/16954621?hl=en)
- [Play Developer Program Policy](https://support.google.com/googleplay/android-developer/answer/17190352?hl=en) · [User Generated Content](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en) · [Inappropriate Content](https://support.google.com/googleplay/android-developer/answer/9878810?hl=en) · [Child Endangerment](https://support.google.com/googleplay/android-developer/answer/9878809)
- [Consumer Protection (E-Commerce) Rules 2020](https://consumeraffairs.gov.in/public/upload/files/E%20commerce%20rules_1732703966.pdf) · [E-Commerce Amendment Rules 2026](https://consumeraffairs.gov.in/public/upload/files/E%20Commerce%20Amendment%20Rules%202026_1789127949.pdf) · [Dark Patterns Guidelines 2023](https://ccpa.doca.gov.in/files/The%20Guidelines%20for%20Prevention%20and%20Regulation%20of%20Dark%20Patterns,%202023_1732707717.pdf)
- [DPDP Act 2023](https://www.meity.gov.in/static/uploads/2024/06/2bf1f0e9f04e6fb4f8fef35e82c42aa5.pdf) · [DPDP Rules 2025 note](https://www.meity.gov.in/static/uploads/2026/01/a49c50414777afc2af0b8d59dafacd60.pdf)
- [RBI PPI FAQ](https://www.rbi.org.in/commonman/english/scripts/FAQs.aspx?Id=2812) · [Income Tax 194-O](https://wm.incometaxindia.gov.in/w/section-194-o) · [GST e-commerce FAQ](https://gstcouncil.gov.in/sites/default/files/2024-02/faq-e-commerc.pdf) · [56th GST Council](https://www.pib.gov.in/PressReleasePage.aspx?PRID=2163555&reg=48&lang=2)
- Earlier verified provider sources are listed in `docs/dashuri_monetization_math.md` §4.
- IT Rules 2021 (grievance officer): the official text was **not retrieved** in this audit and must be cited from the MeitY gazette by the lawyer.
