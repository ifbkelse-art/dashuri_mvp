# Dashuri monetization math: decision pack (v4, 5:4 model)

**Date:** 24 Nov 2026 · **Owner:** BK Enterprises · **Status:** research and documentation only. No application code, migration, wallet behaviour, configuration or deployment was changed.

**Founder boundary:** 5 Diamonds → 4 Beans at ₹0.005/Bean is approved **for modelling only**. It is not approved for implementation or production.

**v4: engineering audit (24 Nov).** This document stays the economics reference. v4 adds four companions:
- [`dashuri_ledger_engineering_spec.md`](finance/dashuri_ledger_engineering_spec.md): chart of accounts, journal entries, PostgreSQL schema, locking, idempotency, migration.
- [`dashuri_monetization_audit_report.md`](finance/dashuri_monetization_audit_report.md): verdict, corrections, traceability, sensitivity.
- [`dashuri_implementation_readiness_checklist.md`](finance/dashuri_implementation_readiness_checklist.md): phases with acceptance criteria.
- [`dashuri_monetization_open_questions.md`](finance/dashuri_monetization_open_questions.md): decision register v4.

**Verdict: not implementation-ready.**

**v4 corrections to this document** (superseded statements are marked inline):
- **No host clawback today.** `ledger.BeanClawback` is never called, so the code today does **not** claw back host Beans on a chargeback.
- **Idempotency is key-only.** `PostEntry` treats a reused idempotency key as a replay **without comparing the payload**.
- **Purchase reversals are pooled.** They remove Diamonds from the pooled purchased balance, not from the reversed purchase's lot.
- **Purchase price is not stored.** `commerce.purchases` stores no price paid.
- **Play policy risk (new).** Google Play prohibits compensated arrangements where one participant provides money or gifts to another. Dashuri's pay-per-minute model needs a policy review before listing (register C-01).
- **Reserve gap.** The reserve needs a refund/chargeback component for recent sales (register B-12).
- **Severe-downside scenario added.** It loses money at every scale with Twilio SMS (audit report §6).

**What v3 corrected** (founder review, 24 Nov):
- **Reversals** are now call-specific, idempotent, cumulative, bounded and tested.
- **Settlement replays** with a different payload raise a conflict.
- **The persistent carry** is designed across every Bean state.
- **Host Level gates and the Level 10 threshold** are reconciled.
- **OTP figures** are reconciled.
- **Cloud Run region** is labelled correctly.
- **The Play fee** is labelled as needing Play Console evidence.
- **The caller ₹/min display** is reassessed.
- **The reserve** now includes promotional Diamonds and fractional carry.
- **Break-even** is solved by bisection: the model runs in about 0.1 s instead of 30 s.

**Reproduce every number:**
- Model: `python3 -I docs/finance/monetization_math_model.py`
- Tests (22, all passing): `python3 -I -m unittest discover -s docs/finance -p 'test_*.py' -v`

**Ledger rules as an executable specification** (reference code, not application code): [`docs/finance/monetization_ledger.py`](finance/monetization_ledger.py).

Tables marked *(model)* are output of the model script.

**Open questions register:** [`docs/finance/dashuri_monetization_open_questions.md`](finance/dashuri_monetization_open_questions.md).

Evidence labels:
- **[CODE]**: read from this repository.
- **[DEPLOYED]**: read from the live `dashuri-dev` GCP project or the Supabase organisation, read-only, 24 Nov 2026.
- **[FOUNDER]**: a founder decision.
- **[VERIFIED]**: an official source, accessed 24 Nov 2026.
- **[THIRD-PARTY]**: non-official source.
- **[ESTIMATE]**: no data; a range is modelled.
- **[PROPOSAL]**: needs founder approval.
- **[NEEDS INPUT]**: evidence only the founder can provide.

---

## 1. Executive summary

- **Approved for modelling [FOUNDER]:** 5 Diamonds spent = 4 Beans; 1 Bean = ₹0.005. So **each Diamond spent creates exactly ₹0.004 of host earnings**. That is the same as the earlier 1:1 @ ₹0.004 proposal, and **33.36% more** than the previous 16,670 → 10,000 rule (₹0.0029994 per Diamond).
- **Host share of what the caller pays** is 16.2% (Starter pack) to 19.3% (Premium). It rises with pack size because bigger packs sell Diamonds cheaper. As a share of the price excluding GST it is 19.1–22.8%.
- **Remainders are carried, not lost.** Each host carries a remainder of 0–4 fifths of a Bean. Credits are exact over any sequence of calls; the most a host is ever "waiting for" is 0.8 Bean (₹0.004). Flooring each call separately would cost hosts 0.4 Bean per call on average at rates not divisible by 5 per second (§8).
- **Reversals undo only the reversed call.**
  - Each reversal is call-specific, idempotent per reversal id, cumulative, and bounded by the original charge.
  - It removes only that call's share of the host's entitlement, so the Beans clawed back are between ⌊4D/5⌋ and ⌈4D/5⌉.
  - They are recovered from that call's own held Beans, then the host's available Beans, then an explicit receivable. Another call's held Beans are never touched.
  - 22 automated tests plus 25 randomised 400-step sequences show the ledger invariants hold (§8, §22).
- **The 15% Play fee is an assumption.** It requires enrolling in the 15% tier in Play Console; without enrolment the fee is 30%, which cuts the 5-minute base margin from 47.7% to 32.9% (§15).
- **The caller's ≈ ₹/min is not accurate today.** The code prices every caller at the Starter pack rate. That overstates the cost by up to 19.6% for Premium buyers, and shows a rupee price for promotional Diamonds the caller never paid for. A per-wallet "your price" is proposed (§21).
- **Every call has positive contribution** in every tested case:
  - **Base case** (Popular pack, 1,500 D/min): **45.9–49.8%** of gross.
  - **Conservative** (Premium, 1,000 D/min): **32.1–40.5%**.
  - **Worst floor case** (Premium, 500 D/min, conservative costs): **20.3% on a 1-minute call**.
  - Contribution is **not profit**: fixed and non-infrastructure costs come after it, and GST, unspent Diamonds and Beans are liabilities.
- **Pay-as-you-go changes break-even a lot.**
  - What is deployed today really is usage-based: Cloud Run has no minimum instances, Supabase is on the Free plan, there is no Redis, and a ₹100 budget alert exists.
  - In production, the only provider minimums that remain are **Supabase Pro (US$25 ≈ ₹2,225/month)** and, once moderation passes 2,000 operations a month, **Sightengine Starter (US$29)**.
  - **Base-case break-even falls to about 37 paying customers a month** with lean non-infrastructure costs (₹7,800/month), and **72** with the earlier staffed estimates. The previous pack estimated ~100.
- **The conservative scenario still loses money, and the cause is OTP, not infrastructure.** At Twilio's list price (₹7.40 per SMS), 1.4 SMS per sign-up and 20 sign-ups per paying customer, OTP costs ₹207.20 per payer against about ₹98 of contribution before OTP. The same assumptions with DLT SMS cost ₹7.00. With a DLT SMS gateway (~₹0.25, third-party quotes), conservative break-even is ~125 paying customers (lean).
- **Cash timing is the biggest balance-sheet risk.** Google pays about the 15th of the following month. With a 14-day hold, base-case host payouts can fall due up to 31 days before the matching cash arrives. At 1,000 paying customers that needs about **₹1.31 lakh of reserve before taxes**: ₹1.27 lakh worst-case cash gap, ₹3,690 for promotional Diamonds and ₹0.40 of fractional carry.
- **Not production-ready.** The following still need a CA/lawyer or evidence:
  - Play fee base for an India-located developer;
  - GST treatment of Diamonds;
  - TDS/GST-TCS on host payouts;
  - RBI framing of host cash-out;
  - consumer-law treatment of forfeited Diamonds;
  - payout provider;
  - SMS provider;
  - real demand data.

---

## 2. Founder-approved vs unresolved decisions

| Item | Status | Source |
|---|---|---|
| 5 D → 4 B, ₹0.005/Bean, same at every level, exact integer arithmetic | **Approved for modelling** (not for deployment) | Founder follow-up brief, 24 Nov 2026 |
| Caller pays; recipient earns; INR → D → spend → B → INR | Approved | [FOUNDER] [CODE] |
| Host price floor 500, ceiling level × 1,000, > 3,000 needs Verified Host | Approved and built 23 Nov | [FOUNDER] [CODE] |
| 7-day hold, ₹500 minimum withdrawal, 30-day promo expiry | Earlier founder decisions (S5, C19) | [CODE] |
| XP = 8D + B | Earlier founder decision (R3-3); **basis unresolved** | [CODE] |
| "No free matching" | Stated in the first brief; **conflicts with the Free Call Card in code** | [FOUNDER] vs [CODE] |
| Everything else (packs, promo, Free Call, XP basis, Host Level, gates, default rate, hold change, payouts, deletion, reserve, display) | **Unresolved**: see §20 | — |

The 5:4 approval is not treated as approval of any other item.

---

## 3. Repository audit

**Authority.** The Go API is the only authority for prices, balances, conversions, billable seconds, XP, levels and payouts. The Flutter client receives server values only (`approx_paise_per_diamond`, `max_rate_per_minute`). ✅

| Area | Fact | Where |
|---|---|---|
| Rule set | Append-only, versioned `economy.rule_sets`; each entry records `rule_set_version` | `economy/rules.go`, `…_economy_and_ledger.sql` |
| Conversion today | `BeansNumerator 10000 / DiamondsDenominator 16670`; `PaisePerBean 1/2`; Beans = ⌊D × 10000 ÷ 16670⌋ **floored per call; residue credited to no one** | `rules.go:94–106` |
| Can the struct express 5:4? | Yes: `BeansNumerator 4`, `DiamondsDenominator 5`, `PaisePerBean 1/2` (a data change). **The remainder carry is not supported** and needs code + schema | `rules.go` |
| Integer units | Diamonds, Beans, paise are `int64`; overflow guard; no floats in money paths | `rules.go` |
| Packs | Six provisional packs ₹99 → 4,000 D … ₹5,999 → 290,000 D, GST-inclusive | `…20261121000100_mvp_foundation.sql:87–94` |
| Rails | Play Billing (default) and Cashfree (`CASHFREE_ENABLED=false`) | `purchases/`, `.env.example` |
| Metering | Per-second; D = ⌊R × s ÷ 60⌋ once per call; interruptions ≥ 10 s unbilled; 120 s reservations | `calls/timeline.go`, `settle.go` |
| Promo | `diamond_promotional` account; 30-day TTL; spent first; **Beans earned on promo spend**; no promo grants exist yet | `rules.go`, `timeline.go:114–126` |
| XP | Granted **on purchase** (8 × D purchased), on call settlement (1 × Beans) and **on free-call compensation (2,000)** | `purchases/service.go:225,618`, `calls/settle.go:111,173` |
| Level | One shared level from lifetime XP, P12 thresholds; drives the host price ceiling | `rules.go`, `hosts/`, `calls/service.go:106` |
| Free Call Card | **On** (`FREE_CALL_ENABLED=true` in dev); 60 s; host ₹10 (2,000 Beans) if ≥ 60 s; 20 per host per day; one per phone/device | `freecall/`, `settle.go:160` [DEPLOYED] |
| Refunds | Unspent reversed from the **pooled** purchased balance; spent shortfall recorded; XP reversed. **Superseded (v4):** held Beans are **not** clawed back: the `BeanClawback` template has no caller | `purchases_repo.go:184–240`, ledger templates |
| Payouts | Withdrawal ≥ 100,000 Beans works; payout cycle disabled (`PAYOUTS_ENABLED=false`); no provider adapter | `payouts/` |
| Deletion | Unspent purchased Diamonds forfeited after confirmation (D-21) | `accounts` |
| Moderation | 1 frame per participant every 20 s for the first 180 s; server limit 1 per 8 s; Sightengine `nudity-2.1` = 1 op per frame | `moderation/service.go:100–128`, `adapters/sightengine` |
| Video | Stream, 1280×720 target | `adapters/stream/stream.go:202` |
| Rate limiting | In-memory per instance; Redis/Postgres is a future option (ADR-007). **No Redis anywhere** | `platform/ratelimit` |
| Location | Haversine in Postgres/Go; **no maps or geocoding API** | `location/haversine.go` |
| Reels | Mux adapter behind `REELS_ENABLED=false` | `config.go:72–132` |

---

## 4. Provider and infrastructure cost audit

**What was inspected** (read-only, 24 Nov 2026): the repo configuration, `infrastructure/cloudrun/api.service.yaml`, the live `dashuri-dev` Cloud Run service, enabled APIs, Artifact Registry, Secret Manager names, the billing budget, and the Supabase organisation plan.

**What was not inspected:**
- No billing export, invoice or provider usage dashboard was available. **Actual spend and usage: not provided, needs founder input** (GCP Billing reports, Stream dashboard usage).
- No Cloud Run request metrics were read.

**Deployed today [DEPLOYED]:**
- Cloud Run `dashuri-api` (asia-south1): **no min instances** (scales to zero), max 1, 1 vCPU, 256 MiB, request-based CPU billing (default), concurrency 40.
- Secrets: `database-url`, `stream-api-secret`, `supabase-secret-key`. There are **no Sightengine, Play or Cashfree credentials**, so those cost nothing today.
- Artifact Registry: 56.9 MB.
- Billing budget alert: ₹100.
- Supabase organisation "BK Enterprises": **Free plan**, with two active projects (`dashuri`, `youarenotalone-staging`). Free allows two active projects.

**Production template [CODE]:** `api.service.yaml` sets **`minScale: "1"`** (one always-on instance) and 512 MiB. That is a **fixed monthly cost**, unlike the deployed dev service. The README recommends Cloud Armor + an external HTTPS load balancer before launch, which would also be a fixed monthly cost. Both are founder decisions.

**Per-call costs below** are for the base case (2 participants, 0.4 unbilled media minutes per call, ₹89/US$).

| Provider | Configured product / tier / region | Billing unit | Free allowance / minimum | Rate and source | Class | Per call 1 / 5 / 10 / 30 min (₹) | Missing evidence |
|---|---|---|---|---|---|---|---|
| **Stream Video** | Video calls, 720p target; region not set in repo | participant-minute, by aggregate received resolution | **US$100 usage free per month** | HD $1.50, Full HD $3.00 per 1,000 participant-min [VERIFIED] | Tiered usage with allowance | 0.37 / 1.44 / 2.78 / 8.12 (before the free credit) | Plan on the Stream dashboard; measured minutes; whether aggregate resolution ever hits the 1080p tier |
| **Cloud Run** (API, workers) | **asia-south1 (Mumbai)**. Dev: min 0, max 1, 1 vCPU, 256 MiB. Prod template: **min 1**, max 10, 512 MiB | vCPU-s, GiB-s, requests | 180k vCPU-s, 360k GiB-s, 2M requests per month per billing account (request-based) | asia-south1 is a **Tier 1** price region [VERIFIED, [locations page](https://docs.cloud.google.com/run/docs/locations)]. Tier-1 unit prices $0.000024/vCPU-s, $0.0000025/GiB-s, $0.40/M requests come from an older pricing-page snapshot: **not confirmed live for asia-south1** | Pure usage (dev); **minimum commitment if minScale 1** | ≈ 0.005 per call (2.5 vCPU-s estimate); ₹0 inside the free tier | Live asia-south1 SKU prices (Cloud Billing); request metrics; idle min-instance price |
| **Supabase** | Free plan, ap-south-1, Postgres 17 | plan + usage (compute, egress, storage, MAU) | Free: 0.5 GB DB, 5 GB egress, 50k MAU; **pauses after 1 week idle; no overage, service is restricted instead** | Pro **US$25/month** incl. $10 compute credit (Micro); egress overage $0.09/GB [VERIFIED] | Free today; **subscription minimum** in production | ≈ 0 per call inside plan quotas | Realtime message and egress usage per call (not measured) |
| **Redis** | Not used | — | — | — | Not applicable | 0 | — |
| **Sightengine** | Not configured in dev; model `nudity-2.1` | operation (1 per frame) | Free 2,000 ops/month (500/day) | Starter $29/10k ops; Pro $99/40k ops; $0.002 extra op [VERIFIED] | Subscription + usage | 1.33 / 4.00 / 4.00 / 4.00 (6 frames for 1 min, 18 for ≥ 3 min) | Chosen plan |
| **OTP / SMS** | Supabase phone auth; Twilio **disabled**; dev test numbers only | SMS | none | Twilio India $0.0832/SMS ≈ ₹7.4 (repo, 22 Nov, official page); DLT gateways ₹0.15–0.25 [THIRD-PARTY] | Per transaction (per sign-up) | per sign-up, not per call | Provider choice and quote; DLT registration fees; SMS per sign-up |
| **Google Play Billing** | Default rail; not configured in dev | % of each purchase | — | Published schedule: 15% on first US$1M/yr, 30% above, "all remaining markets" [VERIFIED page]. **15% applies only after enrolling in the 15% tier** (payments profile, account group listing all associated accounts) [VERIFIED, [2021 fee article](https://support.google.com/googleplay/android-developer/answer/10632485?hl=en)]; otherwise 30%. India expected on the old model until ~30 Sep 2027 [THIRD-PARTY] | Per transaction | % of purchase (§13); 15% is the **base assumption**, not evidence | **Play Console: enrolment status, the fee on a test purchase, the fee base** |
| **Cashfree PG** | `CASHFREE_ENABLED=false`; production application rejected (project notes) | % of transaction | — | 1.95% + GST; 0% offer to ₹20 L GMV until 31 Mar 2027 for new merchants [VERIFIED] | Per transaction | n/a | Only usable through Play's alternative-billing programme |
| **Payout provider** | None | per transfer | — | Cashfree Payouts IMPS/UPI ₹6 (≤ ₹1,000), ₹8 (₹1,000–25,000), ₹15 (> ₹25,000) + GST; quote-based [VERIFIED page] | Per transaction | per withdrawal | Provider choice and written quote |
| **Supabase Storage** | profile-photos, host-verification-evidence | GB stored / egress | Inside the plan quota (Free 1 GB; Pro larger) | in plan [VERIFIED plan page] | Tiered usage | ≈ 0 | Volume |
| **Secret Manager** | 3 secrets | active versions, accesses | 6 versions, 10k accesses/month free | [VERIFIED] | Tiered usage | 0 | — |
| **Artifact Registry** | 56.9 MB | GB-month | 0.5 GB free per billing account | [VERIFIED] | Tiered usage | 0 | Delete old images |
| **Cloud Logging / Monitoring** | Enabled | GiB ingested | 50 GiB per project per month free | [VERIFIED] | Tiered usage | 0 | — |
| **Pub/Sub** (Play RTDN, planned) | API enabled, not used | GiB | 10 GiB/month free | [VERIFIED] | Tiered usage | 0 | — |
| **Cloud Scheduler** (worker jobs, planned) | API not enabled | jobs | Free allowance **unverified** | — | Unknown | 0 | Price check before enabling |
| **Cloud Armor + HTTPS LB** (recommended in README) | Not provisioned | forwarding rule + policy | none | **Unverified** | Fixed if adopted | — | Decide if needed at launch |
| **FCM push** | Configured in code | message | Free | (Google, not re-verified) | Free | 0 | — |
| **Play Integrity** | Configured in code | request | Free standard quota (not re-verified) | — | Tiered | 0 | Quota check |
| **Mux** (Reels) | Off | minutes | — | not modelled | Off | 0 | Only if Reels launches |
| **Maps/geocoding, email, analytics** | None found | — | — | — | Not applicable | 0 | — |

**Pay-as-you-go does not mean zero fixed cost.** These remain even at zero usage:
- Supabase Pro in production (₹2,225/month). The Free plan's 7-day pause and hard restriction are not acceptable for a paid product.
- Cloud Run min-instances if `minScale: 1` is kept.
- Sightengine Starter once above 2,000 ops (~111 calls of ≥ 3 minutes a month).
- Domain/email.
- The one-time Play developer fee (US$25).

**Shrinks to near zero at MVP volume:**
- Cloud Run with min 0;
- other GCP services (inside free tiers);
- Stream (inside the US$100 credit up to about 1,000 base-case paying customers);
- Redis (none);
- the earlier "₹300 per 1,000 active users" infrastructure estimate.

---

## 5. Definitions and units

| Unit | Smallest unit | Meaning |
|---|---|---|
| ₹ (INR) | paisa (int64) | Real money |
| Diamond (D) | 1 (int64) | Caller's prepaid in-app credit for paid calls. Non-transferable, not cashable. *Purchased* (no expiry) or *promotional* (30-day expiry) |
| Bean (B) | 1 (int64), plus a per-host carry of 0–4 fifths | Host's earnings record, redeemable at ₹0.005. States: held → available → payout pending → paid |
| Host rate (R) | D per minute (int64) | **The caller-facing price** set by the host. Not an earning rate |
| XP | int64 | Progression score; never money |
| Level | 1–10 | Step function of XP (Account) or Host XP (§12) |

**Formulas (all integer):**
- Diamonds charged per call: `D = ⌊R × s ÷ 60⌋` (s = billable seconds, once per call).
- Host fifths added: `f = 4 × D`. Then `carry_new = (carry_old + f) mod 5` and `Beans credited = (carry_old + f) div 5`.
- Paise for Beans at withdrawal: `paise = ⌊B ÷ 2⌋` (₹0.005 = ½ paisa).
- Price per Diamond for analysis only: `pack paise ÷ pack Diamonds`.
- Net cash per ₹1 of price: `1/(1+g) − f_store × (1, or 1/(1+g) if the fee is on the GST-exclusive price)`.

---

## 6. Comparison of the three conversion models *(model)*

| Model | Beans per Diamond | ₹ per Bean | Host ₹ per Diamond |
|---|---:|---:|---:|
| M1 previous: 16,670 D → 10,000 B | 1000/1667 | 0.005 | 0.0029994 |
| M2 earlier proposal: 1 D → 1 B | 1/1 | 0.004 | **0.0040000** |
| **M3 approved: 5 D → 4 B** | **4/5** | **0.005** | **0.0040000** |

M2 and M3 are equal per Diamond (asserted in the script). **M1 → M3 raises host earnings by 33.36%** (exactly 417/1250).

| Diamonds spent | M1 Beans | M1 ₹ | M2 Beans | M2 ₹ | M3 Beans | M3 ₹ | M3 − M1 ₹ |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 500 | 299 | 1.50 | 500 | 2.00 | 400 | 2.00 | 0.51 |
| 1,000 | 599 | 3.00 | 1,000 | 4.00 | 800 | 4.00 | 1.00 |
| 2,000 | 1,199 | 6.00 | 2,000 | 8.00 | 1,600 | 8.00 | 2.00 |
| 4,000 | 2,399 | 11.99 | 4,000 | 16.00 | 3,200 | 16.00 | 4.00 |
| 10,000 | 5,998 | 29.99 | 10,000 | 40.00 | 8,000 | 40.00 | 10.01 |
| 20,000 | 11,997 | 59.98 | 20,000 | 80.00 | 16,000 | 80.00 | 20.02 |
| 100,000 | 59,988 | 299.94 | 100,000 | 400.00 | 80,000 | 400.00 | 100.06 |

(M1 is floored per call as the code does today. M3 values here are exact because each amount is a multiple of 5.)

---

## 7. Approved 5:4 worked examples *(model)*

**Host earnings per call:**

| Rate D/min | 1 min | 5 min | 10 min | 30 min |
|---:|---|---|---|---|
| 500 | 400 B = ₹2.00 | 2,000 B = ₹10.00 | 4,000 B = ₹20.00 | 12,000 B = ₹60.00 |
| 1,000 | 800 B = ₹4.00 | 4,000 B = ₹20.00 | 8,000 B = ₹40.00 | 24,000 B = ₹120.00 |
| 1,500 | 1,200 B = ₹6.00 | 6,000 B = ₹30.00 | 12,000 B = ₹60.00 | 36,000 B = ₹180.00 |
| 2,000 | 1,600 B = ₹8.00 | 8,000 B = ₹40.00 | 16,000 B = ₹80.00 | 48,000 B = ₹240.00 |
| 4,000 | 3,200 B = ₹16.00 | 16,000 B = ₹80.00 | 32,000 B = ₹160.00 | 96,000 B = ₹480.00 |
| 10,000 | 8,000 B = ₹40.00 | 40,000 B = ₹200.00 | 80,000 B = ₹400.00 | 240,000 B = ₹1,200.00 |

Under M1 the same calls pay about 25% less: for example 1,500 D/min for 10 min = ₹44.99 instead of ₹60.00.

**Calculator check:** a 10-minute call at 1,500 D/min.
1. Diamonds = 1,500 × 600 ÷ 60 = 15,000.
2. Beans = 15,000 × 4 ÷ 5 = 12,000.
3. ₹ = 12,000 × 0.005 = **₹60.00**.
4. Cross-check: ₹0.004 × 15,000 = ₹60.00.

---

## 8. Ledger rules: carry, settlement, reversal, refunds (reference design, tested)

These rules are written as executable code in [`docs/finance/monetization_ledger.py`](finance/monetization_ledger.py) and tested in [`test_monetization_ledger.py`](finance/test_monetization_ledger.py). That code is a specification for a later Go/SQL change. It is **not** application code, and nothing in `backend/` or `supabase/` was changed.

### 8.1 Units and the core identity

- **Diamonds and Beans** are integers.
- **A fifth** (1/5 Bean) is the internal unit of host entitlement. A call that charges D Diamonds creates **4 × D fifths**.
- **Per host**, the ledger stores whole Beans in each state (held per call, available, payout pending, paid), plus a **receivable** (Beans owed back) and a **carry** `c ∈ {0,1,2,3,4}`.

**Identity (checked after every operation in every test):**

```text
5 × (held + available + pending + paid − receivable) + carry
      = 4 × Σ over the host's calls (charged_D − reversed_D)
0 ≤ carry ≤ 4,   every state ≥ 0,   0 ≤ reversed_D ≤ charged_D for every call
```

**System-wide identities:**
- Diamond conservation: issued = balances + consumed − returned + expired + charged-back unspent.
- Host entitlement = consumed − returned − charged-back spent.

### 8.2 Settlement (idempotent, exact)

```text
key = call_settlement:<call id>,  payload = (caller, host, D)
if key exists:  same payload → return the stored result (no new posting)
                different payload → IdempotencyConflict (nothing changes)
T_before = host fifths;  T_after = T_before + 4D
credit   = ⌊T_after/5⌋ − ⌊T_before/5⌋   → held Beans of THIS call
carry    = T_after mod 5
```

**Worked example** *(model)*:

| Call | Diamonds | Carry in | Fifths added | Beans credited | Carry out | Per-call floor would give |
|---|---:|---:|---:|---:|---:|---:|
| c1 (65 s @ 4,000) | 4,333 | 0/5 | 17,332 | 3,466 | 2/5 | 3,466 |
| c2 (65 s @ 2,000) | 2,166 | 2/5 | 8,664 | 1,733 | 1/5 | 1,732 |
| c3 | 1,001 | 1/5 | 4,004 | 801 | 0/5 | 800 |
| c4 | 7 | 0/5 | 28 | 5 | 3/5 | 5 |

The exact entitlement is 6,005.6 Beans: 6,005 credited plus 3/5 carried. A per-call floor would credit 6,003. Across 1,800 calls of every length from 1 s to 30 min at 500 or 1,000 D/min, a per-call floor loses 720 Beans (0.4 Bean per call); **the carry loses nothing**.

### 8.3 The carry across Bean states

| State | Contains the carry? | Rule |
|---|---|---|
| Held (per call) | No: whole Beans only | Released after the hold (14 days proposed) |
| Carry (per host) | **Yes: 0–4 fifths** | Never released, withdrawn or paid. It is part of the host's entitlement and becomes a whole Bean when later calls complete it |
| Available | No | Withdrawable (≥ 100,000 Beans) unless a receivable is open |
| Payout pending | No | Untouched by reversals; a failed payout returns to available |
| Paid | No | Final; a later reversal creates a receivable |
| Receivable | No | Beans owed back. Offset against future releases first; withdrawals are blocked while it is > 0 |

**Persistence (proposal for the later schema):**
- One row per host: `bean_carry (host_id, fifths smallint check 0..4, total_fifths bigint, rule_set_version)`.
- It is updated **in the same transaction** as the settlement or reversal entry, under the host's Bean row lock (existing ascending-account-id lock order).
- Each settlement and reversal row stores `carry_before`, `fifths_delta`, `beans_delta` and `carry_after`, so every carry value can be audited from the journal alone.

**Value and closure:**
- The carry is worth at most ₹0.004 per host and is counted in the reserve (§16).
- At account closure, or at a rule change with a different denominator, a non-zero carry is rounded **up** to one Bean (host-favourable; at most ₹0.005 per host).

### 8.4 Reversal (call-specific, idempotent, cumulative, bounded)

```text
key = reversal:<reversal id>, payload = (call id, D_r, mode)
replay: same payload → stored result;  different payload → IdempotencyConflict
require 0 < D_r and call.reversed_D + D_r ≤ call.charged_D   (else ReversalExceedsCharge)
T_after = T_before − 4·D_r
claw    = ⌊T_before/5⌋ − ⌊T_after/5⌋ ,  carry = T_after mod 5
recover claw from: (1) this call's held Beans → (2) host available → (3) receivable
```

- **Only this call's entitlement is removed.** The Beans left equal ⌊(entitlement of all other calls)/5⌋, exactly what the host would hold had the reversed Diamonds never been charged.
- **Bound.** Over all partial reversals of a call, total claw is ⌊4D/5⌋ or ⌈4D/5⌉. It can be one Bean more than the call's own credit when that call's fraction had completed a later call's whole Bean.
  - Tested example: c1 (3,466 credited, worth 3,466.4) reversed after c2 → claw 3,467.
  - The extra Bean is taken from available Beans or booked as a **receivable**, never from c2's held Beans.
- **Diamonds on a dispute** go back to the caller, last-spent lot first (purchased before promotional, since promo is spent first). A charged-back purchase is never refilled.
- **Diamonds on a chargeback** are not returned. The reversal is limited to Diamonds funded by that purchase.

### 8.5 Refunds and chargebacks (per purchase)

```text
chargeback(cb id, purchase P):  idempotent on cb id
  unspent Diamonds of P → removed
  for each call funded by P: reverse(net D funded by P)  [no Diamonds back to the caller]
  platform loss (₹) = P price × spent ÷ P Diamonds
```

**Tested example:**
- Two purchases: P1 (54,000 D) and P2 (12,500 D).
- c1 took 30,000 D from P1; c2 took 24,000 D from P1 and 6,000 D from P2.
- A chargeback on P1 reverses c1 fully and 24,000 D of c2.
- Host B keeps 4,800 Beans, earned on P2's 6,000 D.
- The caller keeps P2's remaining 6,500 D.
- Platform loss: ₹1,199.

### 8.6 Concurrency and retries

**Database guarantees (proposal):**
- unique idempotency keys (settlement, reversal, chargeback, withdrawal);
- one live call per person;
- `FOR UPDATE` on the host Bean rows and the carry row, in ascending account-id order;
- serialisation retries are safe because every operation is idempotent.

**In tests:**
- 32 threads settling the same call credit it once.
- 200 calls settled in parallel, with 50 duplicate settlements and 100 duplicated reversals racing, keep every invariant.

### 8.7 Rule changes

- Every call stores `rule_set_version` and settles under it.
- A new conversion applies only to calls settled after its effective time.
- Beans already earned keep their ₹0.005 value. The value may be raised, never lowered for existing Beans [PROPOSAL].
- If the new ratio's denominator is not 5, each host's carry is rounded up to one Bean at the switch.

---

## 9. Diamond pack analysis *(model)*

| Pack | Price ₹ (incl. GST) | Diamonds | Volume bonus vs Starter rate | paise/D | Host % M1 | Host % M3 | M3 host % of ex-GST price |
|---|---:|---:|---:|---:|---:|---:|---:|
| Starter | 99 | 4,000 | 0 | 2.4750 | 12.1% | **16.2%** | 19.1% |
| Small | 299 | 12,500 | 420 | 2.3920 | 12.5% | **16.7%** | 19.7% |
| Medium | 599 | 26,000 | 1,798 | 2.3038 | 13.0% | **17.4%** | 20.5% |
| Popular | 1,199 | 54,000 | 5,556 | 2.2204 | 13.5% | **18.0%** | 21.3% |
| Large | 2,999 | 140,000 | 18,829 | 2.1421 | 14.0% | **18.7%** | 22.0% |
| Premium | 5,999 | 290,000 | 47,617 | 2.0686 | 14.5% | **19.3%** | 22.8% |
| *(₹1,130 example)* | *1,130* | *48,000* | *2,344* | *2.3542* | *12.7%* | *17.0%* | *20.0%* |

**Recommendation [PROPOSAL]:**
- Keep the six seeded packs and remove `provisional` only after the Play fee base is confirmed.
- Treat the volume bonus as **purchased** Diamonds: paid for, no expiry, counts for XP.
- Only free grants are promotional.
- No arbitrage: the cheapest Diamond (2.0686 p) returns 0.4 p to a colluding host. That loses **80.7%**, so self-dealing for cash never pays.

---

## 10. Caller pricing and host earnings *(model; Popular pack, base, per minute)*

| Rate D/min | Lowest level | Verified? | Caller ₹/min | Beans/min | Host ₹/min | Net cash after GST & store fee ₹/min | Left after host ₹/min (before other costs) |
|---:|---:|---|---:|---:|---:|---:|---:|
| 500 | 1 | no | 11.10 | 400 | 2.00 | 7.74 | 5.74 |
| 1,000 | 1 | no | 22.20 | 800 | 4.00 | 15.49 | 11.49 |
| 1,500 | 2 | no | 33.31 | 1,200 | 6.00 | 23.23 | 17.23 |
| 2,000 | 2 | no | 44.41 | 1,600 | 8.00 | 30.97 | 22.97 |
| 4,000 | 4 | yes | 88.81 | 3,200 | 16.00 | 61.94 | 45.94 |
| 10,000 | 10 | yes | 222.04 | 8,000 | 40.00 | 154.86 | 114.86 |

**Lowest rate with positive 1-minute contribution:** 160 D/min (base), 250–270 D/min (conservative). Both are below the 500 floor, so the floor is safe.

---

## 11. Bean redemption and liability model

| Rule | Recommended [PROPOSAL] | Today [CODE] |
|---|---|---|
| Value | ₹0.005/Bean (approved) | same |
| Minimum withdrawal | ₹500 = **100,000 Beans** (unchanged, because the Bean value is unchanged) | same |
| Hold | **14 days**; 7 days for Verified Hosts at Host Level ≥ 5 with no open case | 7 days |
| Schedule | Weekly cycle; finance approval; only while `PAYOUTS_ENABLED` | built, off |
| Payout fee | Platform absorbs (₹6–15 + GST per transfer, 0.4–1.9% of a payout) | unpriced |
| Tax deductions | Per CA (§18): possibly TDS u/s 194-O and/or GST TCS u/s 52 | none |
| Eligibility | Approved host; bank/UPI in the host's own name; PAN (or Aadhaar); no open fraud case | partly built |

**Balances shown to the host:** Held · Available · In payout · Paid (lifetime), plus "pending fraction < 1 Bean" when a carry exists.

**Liabilities, kept separate:**
1. **Customer stored value**: unspent purchased Diamonds, valued at purchase price. Revenue is recognised on consumption; breakage only per CA advice.
2. **Promotional Diamonds**: no cash behind them. If spent, each creates ₹0.004 of host liability, so outstanding promo Diamonds × ₹0.004 is reserved in full (expiry ignored, conservative).
3. **Host payout liability**: (held + available + payout pending) Beans × ₹0.005, **plus the fractional carry**: Σ carry ÷ 5 × ₹0.005, at most ₹0.004 per host.
4. **Host receivables** (Beans owed back after a post-payout reversal): an asset of doubtful recovery. It is **not** netted against the reserve.
5. **Taxes collected**: GST output tax and any TDS/TCS withheld. Never used to fund payouts.

---

## 12. XP and Host Level analysis

**Problems with today's XP** (one level from 8 × D purchased + Beans earned):
- **Pay-to-win:** a host buys Level 10 (the 10,000 D/min ceiling) with 5,000,000 D = **₹1,03,431** (Premium). Earning it needs callers to spend **₹11.1 lakh** on that host *(model)*.
- **Buy-and-hold:** XP is granted at purchase.
- **Free-call XP:** each free call grants 2,000 XP with no revenue behind it.
- **Collusion:** self-dealing levels both sides.
- **5:4 changes "B":** 0.8 Beans per Diamond instead of 0.6.

**Recommendation [PROPOSAL]:** split the level in two.

**Account XP** (display, caller status):
- Formula: `8 × D_consumed + B_released`.
- D_consumed = **purchased** Diamonds consumed in settled paid calls (not promo, not unspent).
- B_released = Beans from **paid** calls after the hold (not free-call compensation, not adjustments).
- Lifetime; reduced only by reversals.

**Host Level** (controls the price ceiling):
- `HostXP = B_released from paid calls`.
- **Reuse the P12 thresholds unchanged**; they are already in the rule set.
- Under 5:4, P12's 40,000,000 = ₹2,00,000 of host earnings, the same ₹ value the baseline implied.
- Plus a per-caller cap (one caller counts for at most 20% of HostXP) and distinct-paying-caller gates.

**Distinct-caller gates** *(model)*. The script and this table both use the **proposed** gates 0/2/5/10/20/35/60/100/150/250. The v2 draft gates (0/3/10/20/40/75/120/200/300/500) are shown only for comparison. "Implied ₹ per caller" = caller spend needed for the level ÷ gate.

| Level | HostXP (Beans) | Host ₹ earned | Caller ₹ spent (Popular) | v2 draft gate | Implied ₹/caller | **Proposed gate** | **Implied ₹/caller** |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0 | 0 | 0 | 0 | — | **0** | — |
| 2 | 32,000 | 160 | 888 | 3 | 296 | **2** | 444 |
| 3 | 100,000 | 500 | 2,775 | 10 | 278 | **5** | 555 |
| 4 | 250,000 | 1,250 | 6,939 | 20 | 347 | **10** | 694 |
| 5 | 600,000 | 3,000 | 16,653 | 40 | 416 | **20** | 833 |
| 6 | 1,500,000 | 7,500 | 41,632 | 75 | 555 | **35** | 1,189 |
| 7 | 3,500,000 | 17,500 | 97,141 | 120 | 810 | **60** | 1,619 |
| 8 | 8,000,000 | 40,000 | 2,22,037 | 200 | 1,110 | **100** | 2,220 |
| 9 | 18,000,000 | 90,000 | 4,99,583 | 300 | 1,665 | **150** | 3,331 |
| 10 | 40,000,000 | 2,00,000 | 11,10,185 | 500 | 2,220 | **250** | 4,441 |

**Level 10 reconciliation** *(model)*. Every version means the same thing for a host who only earns: **₹2,00,000 of lifetime host earnings**.

| Source | Measure | Level 10 threshold | ₹ for a pure host | ₹ for a pure buyer |
|---|---|---:|---:|---:|
| Code today (`economy.Founder()`, P12; rule set `2026-11-23-verified-pricing`) | Account XP = 8 × D purchased + Beans earned (M1) | 40,000,000 XP | 40M Beans × ₹0.005 = ₹2,00,000 | 5,000,000 D = **₹1,03,431** (Premium) |
| Decision pack v1 (1:1 @ ₹0.004) | HostXP = Beans released | 50,000,000 Beans | 50M × ₹0.004 = ₹2,00,000 | cannot buy |
| **v2/v3 (5:4 @ ₹0.005)** | HostXP = Beans released | **40,000,000 Beans** (P12 numbers reused) | 40M × ₹0.005 = **₹2,00,000** | cannot buy |

**What the split changes:**
- **Buying stops counting** toward the price ceiling.
- **Hosts reach a level with less caller spend.** Under 5:4 a host earns 0.8 Beans per Diamond instead of 0.6, so callers need to spend ₹11.1 lakh for Level 10 (was ₹14.8 lakh under M1).
- **Earned XP counts later.** It is counted only after the hold.

**Is 500 distinct callers realistic for Level 10?** Not in year one. At 1,000 paying customers platform-wide, 500 would mean half of all payers have paid that one host. 250 still blocks collusion: with the 20% cap, at least 5 large callers are needed anyway. Revisit with data.

**Level benefits, all with bounded cost:**
- higher price ceiling (proportional earnings, no liability);
- Verified discovery boost (exists);
- shorter hold for trusted hosts (cash timing only);
- badges.

**Never offered:** Bean multipliers, free Diamonds on level-up, guaranteed earnings.

---

## 13. Unit economics per call *(model; approved M3)*

**Cost lines:**
- GST = 18/118 of gross.
- Store fee = 15% of gross (base; conservative 20%; optimistic 15% of the ex-GST price).
- Video = (minutes + overhead) × 2 × Stream rate × FX.
- Moderation = ops × $/op × FX.
- API = Cloud Run active CPU and memory.
- Loss = loss rate × (net cash − clawed-back host pay).
- Payout fee = % of host pay.
- **Contribution** = net cash − host − video − moderation − API − loss − payout fee.

**Base: Popular, 1,500 D/min, base costs**

| Min | D | Gross ₹ | GST ₹ | Store fee ₹ | Net cash ₹ | Beans | Host ₹ | Video ₹ | Moderation ₹ | API ₹ | Loss + payout ₹ | **Contribution ₹** | **Margin** |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1,500 | 33.31 | 5.08 | 5.00 | 23.23 | 1,200 | 6.00 | 0.37 | 1.33 | 0.005 | 0.24 | **15.27** | 45.9% |
| 5 | 7,500 | 166.53 | 25.40 | 24.98 | 116.15 | 6,000 | 30.00 | 1.44 | 4.00 | 0.005 | 1.20 | **79.49** | 47.7% |
| 10 | 15,000 | 333.06 | 50.81 | 49.96 | 232.29 | 12,000 | 60.00 | 2.78 | 4.00 | 0.005 | 2.40 | **163.10** | 49.0% |
| 30 | 45,000 | 999.17 | 152.42 | 149.88 | 696.88 | 36,000 | 180.00 | 8.12 | 4.00 | 0.005 | 7.20 | **497.55** | 49.8% |

**Contribution by scenario and call length:**

| Scenario | 1 min | 5 min | 10 min | 30 min |
|---|---|---|---|---|
| Conservative: Premium, 1,000 D/min | ₹6.64 (32.1%) | ₹37.67 (36.4%) | ₹80.38 (38.9%) | ₹251.21 (40.5%) |
| Worst floor: Premium, 500 D/min, conservative | ₹2.10 (20.3%) | ₹14.97 (28.9%) | ₹34.97 (33.8%) | ₹114.99 (37.1%) |
| Optimistic: Medium, 2,000 D/min | ₹23.61 (51.3%) | ₹120.51 (52.3%) | ₹244.28 (53.0%) | ₹739.34 (53.5%) |
| High rate: Popular, 4,000 D/min, base | ₹43.59 (49.1%) | ₹221.07 (49.8%) | ₹446.26 (50.2%) | ₹1,347.00 (50.6%) |

**Full flow, one purchase and one call (base):**

| Step | Amount | Nature |
|---|---|---|
| Customer pays for Popular | ₹1,199.00 | Gross sale (cash via Google, ~15–45 days later) |
| Diamonds credited | 54,000 D | Stored-value liability ₹1,199 |
| 10-min call at 1,500 D/min consumes | 15,000 D = ₹333.06 | Consumption → revenue (subject to CA) |
| GST inside the ₹333.06 | ₹50.81 | Tax liability, not revenue |
| Store fee | ₹49.96 | Cost |
| Net cash for the consumed part | ₹232.29 | — |
| Beans credited to host (held) | 12,000 B | Payout liability ₹60.00 |
| Video + moderation + API | ₹6.79 | Variable cost |
| Loss reserve + payout fee | ₹2.40 | Variable cost |
| **Contribution** | **₹163.10 (49.0%)** | Before fixed costs. **Not profit** |
| Diamonds left | 39,000 D = ₹865.94 | Still a stored-value liability |

---

## 14. Monthly scenarios at 100 / 1,000 / 10,000 paying customers *(model)*

**Assumptions** (all [ESTIMATE] unless noted):

| Assumption | Conservative | Base | Optimistic |
|---|---:|---:|---:|
| Paid minutes per payer per month | 12 | 20.5 | 31.7 |
| Average rate D/min | 1,000 | 1,500 | 2,000 |
| Average call length (min) | 4 | 5 | 6 |
| Pack (sets ₹/D) | Premium | Popular | Medium |
| Sign-ups per paying customer | 20 | 10 | 5 |
| ₹ per SMS × SMS per sign-up | 7.40 (Twilio) × 1.4 | 0.25 (DLT) × 1.3 | 0.15 × 1.2 |

**Variable costs and contribution (₹/month)** — infrastructure is usage-based: Stream after its US$100 credit, Sightengine free → Starter → overage, Cloud Run after its free tier:

| Payers | Scen. | Gross | Net cash | Host | Video | Moderation | Cloud Run | OTP | Loss + payout | **Contribution** | Supabase Pro | **After provider minimum** |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 100 | c | 24,823 | 16,072 | 4,800 | 0 | 2,610 | 0 | 20,720 | 374 | −12,432 | 2,250 | **−14,682** |
| 100 | b | 68,276 | 47,620 | 12,300 | 0 | 2,581 | 0 | 325 | 492 | 31,922 | 2,225 | **29,697** |
| 100 | o | 1,46,064 | 1,05,215 | 25,360 | 0 | 2,552 | 0 | 90 | 551 | 76,662 | 2,200 | **74,462** |
| 1,000 | c | 2,48,234 | 1,60,721 | 48,000 | 0 | 10,530 | 0 | 2,07,200 | 3,742 | −1,08,751 | 2,250 | **−1,11,001** |
| 1,000 | b | 6,82,764 | 4,76,199 | 1,23,000 | 0 | 13,937 | 0 | 3,250 | 4,922 | 3,31,090 | 2,225 | **3,28,865** |
| 1,000 | o | 14,60,638 | 10,52,155 | 2,53,600 | 0 | 17,530 | 0 | 900 | 5,514 | 7,74,611 | 2,200 | **7,72,411** |
| 10,000 | c | 24,82,345 | 16,07,213 | 4,80,000 | 65,520 | 98,010 | 0 | 20,72,000 | 37,424 | −11,45,741 | 2,250 | **−11,47,991** |
| 10,000 | b | 68,27,639 | 47,61,989 | 12,30,000 | 50,214 | 1,32,165 | 0 | 32,500 | 49,219 | 32,67,891 | 2,225 | **32,65,666** |
| 10,000 | o | 1,46,06,385 | 1,05,21,548 | 25,36,000 | 79,072 | 1,68,168 | 0 | 9,000 | 55,144 | 76,74,164 | 2,200 | **76,71,964** |

The Cloud Run free tier covers even 10,000 payers at ~2.5 vCPU-seconds per call (an estimate; it must be measured).

**Non-infrastructure operating expenses** [NEEDS INPUT; earlier repo estimates]:
- **Lean (founder runs support and safety): ₹7,800/month** (CA ₹4,000, legal ₹2,500, domain/email/tools ₹1,300).
- **Staffed: ₹19,800/month** (adds safety on-call ₹10,000, other ₹2,000).
- Marketing and salaries are 0 and are founder decisions.

| Payers | Scen. | Operating result, lean ₹/month | Operating result, staffed ₹/month |
|---:|---|---:|---:|
| 100 | c / b / o | −22,482 / 21,897 / 66,662 | −34,482 / 9,897 / 54,662 |
| 1,000 | c / b / o | −1,18,801 / 3,21,065 / 7,64,611 | −1,30,801 / 3,09,065 / 7,52,611 |
| 10,000 | c / b / o | −11,55,791 / 32,57,866 / 76,64,164 | −11,67,791 / 32,45,866 / 76,52,164 |

Operating result is still not cash flow; see §16.

---

## 15. Break-even and sensitivity *(model)*

**Break-even paying customers per month:**

| Scenario | Provider minimum only (₹2.2k) | Lean (₹10k) | Staffed (₹22k) |
|---|---:|---:|---:|
| Base | 7 | **37** | **72** |
| Optimistic | 3 | 13 | 31 |
| Conservative (Twilio SMS) | never (negative per payer) | never | never |
| Conservative with DLT SMS ₹0.25 | 23 | **125** | **248** |

Conservative contribution per payer with DLT SMS is ₹91.45/month.

**By average rate and pack** (base costs, 20.5 paid min/payer, lean):

| Rate D/min | 500 | 1,000 | 1,500 | 2,000 | 4,000 |
|---|---:|---:|---:|---:|---:|
| Popular pack | 112 | 56 | 37 | 22 | 11 |
| Premium pack | 124 | 61 | 41 | 24 | 12 |

**Break-even paid minutes per payer per month** (lean fixed costs):

| Payers | Conservative (Twilio ₹7.40) | Conservative + DLT ₹0.25 | Base | Optimistic |
|---:|---:|---:|---:|---:|
| 100 | 38.5 | 15.0 | 8.0 | 4.5 |
| 300 | 29.5 | 5.5 | 3.0 | 1.5 |
| 1,000 | 27.5 | 2.5 | 1.0 | 0.5 |

**OTP cost per paying customer** = sign-ups per payer × SMS per sign-up × ₹ per SMS. This is the swing factor.

| Sign-ups per payer | 1.3 × ₹0.15 | 1.3 × ₹0.25 | 1.4 × ₹0.25 | 1.3 × ₹7.40 | 1.4 × ₹7.40 |
|---:|---:|---:|---:|---:|---:|
| 5 | 0.97 | 1.62 | 1.75 | 48.10 | 51.80 |
| 10 | 1.95 | 3.25 | 3.50 | 96.20 | 103.60 |
| 20 | 3.90 | 6.50 | **7.00** | 192.40 | **207.20** |
| 50 | 9.75 | 16.25 | 17.50 | 481.00 | 518.00 |

**Reconciliation.** The conservative scenario uses 20 sign-ups × **1.4** SMS. At Twilio's price that is **₹207.20**; with DLT it is **₹7.00**. The v2 register's "₹6.5" used 1.3 SMS per sign-up and is corrected there.

**Play fee** *(model; 5-min base call)*. The 15% rate is the base assumption **only if** the account is enrolled in the 15% tier. **Evidence needed: Play Console.**

| Play fee on gross | Contribution | Margin |
|---|---:|---:|
| 15% (enrolled) | ₹79.49 | 47.7% |
| 20% (stress) | ₹71.25 | 42.8% |
| 30% (not enrolled, or above US$1M/yr) | ₹54.76 | 32.9% |

**Single-input sensitivity** (5-min base call; unchanged by 5:4 because the host ₹/D is the same):
- store fee 20% −₹8.24; 30% −₹24.73;
- video at $6/1,000 −₹4.33;
- loss rate 10% −₹9.10;
- moderation $0.005/op −₹4.00;
- Bean value ₹0.006 (i.e. ₹0.0048/D) ≈ −₹6.0.

**Severe downside (v4, all adverse at once).** Assumptions:
- Play fee 30% on gross;
- Twilio SMS at 1.5 SMS × 30 sign-ups per payer;
- 8 paid minutes per payer, 3-minute calls at 1,000 D/min, Premium pack;
- 5% loss rate with 20% clawback;
- Stream at $3 per 1,000 minutes, 0.8 unbilled minutes per call;
- 10 vCPU-s per call; ₹91/US$.

| Measure | Result |
|---|---|
| Per call | Still positive: 1 min ₹4.13 (20.0%); 3 min ₹13.32 (21.5%); 10 min ₹56.56 (27.3%) |
| Per month after Supabase + staffed costs | −₹52,636 (100 payers); −₹3,10,849 (1,000); −₹29,48,865 (10,000) |
| Why | OTP alone is ₹333 per payer against ₹44 of contribution before OTP |
| Same case with DLT SMS at ₹0.25 | +₹32,976 contribution at 1,000 payers |

**One-at-a-time sensitivity** (1,000 payers, base, lean; base ₹3,21,065/month):

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
| 1080p video | −2,923 |

These are **model outputs, not audited facts**. Demand inputs are estimates (register C-13).

**Risks in order:** demand (paid minutes), OTP cost × sign-up ratio, Play fee tier/base, loss rate. Infrastructure is minor per call.

**What pay-as-you-go removed from the earlier loss case:**
- Cloud Run $15–30 → ₹0 (min 0, free tier);
- other GCP $5–10 → ₹0;
- "₹250–500 per 1,000 active users" → ~₹0 inside quotas;
- Redis → none.

**What remains:**
- Supabase Pro;
- Sightengine plan;
- Stream above US$100/month;
- Play fee;
- OTP;
- payout fees;
- all non-infrastructure costs;
- the cash-timing gap.

---

## 16. Cash-flow and reserve analysis *(model; base behaviour)*

- **Google** pays developer proceeds around the 15th of the following month [repo, verified 17 Nov]: a 15–45 day lag, 30 on average.
- **GST** for the month is due by the 20th of the following month (GSTR-3B, repo note). It is due about when Play cash lands, so plan on paying GST from that receipt.
- **Hosts** can withdraw after the hold, in the weekly cycle.

**Reserve components** *(model; base behaviour)*:
- **Promo liability:** promo grants are capped at 3% of Diamonds consumed in the previous month and expire after 30 days, so at most one month of grants is outstanding. It is valued at ₹0.004 per Diamond.
- **Fractional carry:** worst case 4/5 Bean per active host (hosts ≈ payers ÷ 10, minimum 10).

| Payers | Hold | Host earnings ₹/month | Cash gap avg ₹ | Cash gap worst ₹ | Promo Diamond liability ₹ | Carry ₹ (max) | **Reserve before taxes ₹** |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 100 | 7 d | 12,300 | 9,430 | 15,580 | 369 | 0.04 | **15,949** |
| 100 | 14 d | 12,300 | 6,560 | 12,710 | 369 | 0.04 | **13,079** |
| 1,000 | 7 d | 1,23,000 | 94,300 | 1,55,800 | 3,690 | 0.40 | **1,59,490** |
| 1,000 | 14 d | 1,23,000 | 65,600 | 1,27,100 | 3,690 | 0.40 | **1,30,790** |
| 10,000 | 7 d | 12,30,000 | 9,43,000 | 15,58,000 | 36,900 | 4.00 | **15,94,904** |
| 10,000 | 14 d | 12,30,000 | 6,56,000 | 12,71,000 | 36,900 | 4.00 | **13,07,904** |

**Reserve rule [PROPOSAL]** (implemented in the reference ledger as `reserve()`). Before each payout cycle, cash on hand must be at least:

```text
₹0.005 × (held + available + payout-pending Beans)
+ ₹0.005 × Σ carry ÷ 5                      (fractional entitlements)
+ ₹0.004 × outstanding promotional Diamonds   (no cash behind them)
+ GST / TDS / TCS payable
+ refund/chargeback reserve: loss rate × sales of the last 120 days   (v4; horizon per CA/Play, register B-12)
```

**v4 sufficiency check.** The formula covers the reversal model only if three conditions hold:
1. receivables are not netted;
2. payouts are held when a receivable or fraud case appears before provider submission (register B-05);
3. the refund/chargeback reserve above is included.

Google debits refunds and chargebacks from future proceeds, so without (3) the cash for Bean payouts can be consumed by those debits.

- Host receivables are **not** subtracted.
- If cash is short, the cycle pays pro rata or waits.

The cash gap is a **one-time working-capital need that grows with volume**. A 14-day hold cuts it by 18% (worst case) to 30% (average). Payouts stay off (`PAYOUTS_ENABLED=false`) until this cash exists.

---

## 17. Refund, fraud and ledger controls

Most exist [CODE]; additions are [PROPOSAL].

- **Ledger invariants:**
  - balanced entries per currency;
  - no negative user balances;
  - Diamonds and Beans never balance each other;
  - the §8.1 carry identity per host and the Diamond-conservation identity [PROPOSAL; tested, §22];
  - daily `reconcile-ledger`.
- **Idempotency:** purchase token hash, `call_settlement:<id>`, `bean_release:<entry>`, withdrawal and payout ids, RTDN and webhook replays.
- **Concurrency:** one live call per person; one reservation per caller; ascending account-id locks; rate snapshot per call.
- **Duration:** billable seconds come from Stream media events (host video on), never from the client.
- **Refunds and chargebacks:** reverse unspent Diamonds, reverse call entitlements through the carry formula, claw back held Beans, record shortfalls, reverse XP, block payout on open cases.
- **Collusion [PROPOSAL]:**
  - 20% per-caller cap and distinct-caller gates on Host Level;
  - flag any caller–host pair above 50% of either side's monthly spend or earnings;
  - match devices, payment instruments and payout accounts between caller and host;
  - flag calls with no camera frames (existing missing-frames review).
- **Free Call Card abuse** (if kept): ₹10 per free call is direct cash to the host. 20 burner phones = ₹200 per host per day. Keep it only with a monthly ₹ budget, compensation after the hold, and **no XP**.
- **Admin adjustments:** two-person rule, reason code, audit event (exists).

---

## 18. Consumer, app-store, tax and regulatory review flags

**Requires a qualified Indian CA or lawyer.** Nothing below is a legal conclusion.

| Topic | What the evidence says | Question for the adviser |
|---|---|---|
| Play billing requirement | Digital goods sold in-app must use Play Billing unless enrolled in an alternative-billing programme [VERIFIED](https://support.google.com/googleplay/android-developer/answer/10281818?hl=en) | Confirm Diamonds for calls are "digital goods" and Play Billing is mandatory |
| Alternative billing in India | Fee reduced by 4 points when the user pays through an alternative system [VERIFIED](https://support.google.com/googleplay/android-developer/answer/13306652?hl=en). A newer page mentions updated fees from 30 Jun 2026 [VERIFIED](https://support.google.com/googleplay/android-developer/answer/17161464) | Is it available to this app? Worth it? Cashfree production was rejected, so it is not usable now |
| Play fee for India | Old model 15%/30% for "all remaining markets" [VERIFIED](https://support.google.com/googleplay/android-developer/answer/112622?hl=en); restructure 4 Mar 2026, staggered [VERIFIED](https://support.google.com/googleplay/android-developer/answer/16954621?hl=en); India ~30 Sep 2027 [THIRD-PARTY] | Fee tier shown in Play Console; enrol in the 15% tier; fee base (GST-inclusive?) |
| GST on Play sales (India developer) | Developer determines and pays GST itself; pays GST on Google's fee under reverse charge; Google withholds 0.1% TDS (with PAN) and GST TCS [VERIFIED](https://support.google.com/paymentscenter/answer/7421525?hl=en) | GST at Diamond sale or at consumption (voucher rules)? Rate 18%? ITC on the reverse-charge GST |
| GST rates 2025 | Two main slabs 5%/18%, 40% for specified items incl. online money gaming [VERIFIED](https://www.pib.gov.in/PressReleasePage.aspx?PRID=2163555&reg=48&lang=2) | Confirm paid video calls are 18% and not "online money gaming" (no stakes or winnings) |
| TDS on host payouts | 194-O: 0.1% on e-commerce participants; nil for individuals/HUF with PAN/Aadhaar up to ₹5 lakh a year; 5% without PAN [VERIFIED](https://wm.incometaxindia.gov.in/w/section-194-o) | Is Dashuri an "e-commerce operator" and the host a "participant"? Or does 194J/194C apply? |
| GST TCS on host supplies | Sec. 52: operators collecting consideration for others' supplies collect TCS (historically 1%) [VERIFIED](https://gstcouncil.gov.in/sites/default/files/2024-02/faq-e-commerc.pdf); rate change proposed in the 53rd Council, outcome **unverified** | Do hosts supply *through* Dashuri, or *to* Dashuri? Registration thresholds for hosts |
| RBI / PPI | Closed-system PPIs are for the issuer's own goods/services, no cash withdrawal, no third-party settlement [VERIFIED](https://www.rbi.org.in/commonman/english/scripts/FAQs.aspx?Id=2812) | Do Diamonds remain outside PPI rules when caller money funds host cash-outs? Required framing: Dashuri sells the call service; hosts are service providers paid by Dashuri; Beans are non-transferable earnings records |
| Consumer protection | Forfeiture of unspent purchased Diamonds on deletion (D-21); promo expiry disclosure; price display before a call | Is forfeiture lawful? Refund duty on deletion? Required disclosures |
| Play content policy | Paid one-to-one video with strangers, random matching. Play prohibits apps facilitating compensated arrangements where one participant is expected to provide money or gifts to another [VERIFIED](https://support.google.com/googleplay/android-developer/answer/17190352?hl=en); UGC apps need moderation, reporting and blocking [VERIFIED](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en); social apps must meet Child Safety Standards [VERIFIED](https://support.google.com/googleplay/android-developer/answer/9878809) | **P0 blocker (v4):** written policy review before production listing; may require product changes |
| Consumer protection | E-Commerce Rules 2020 and 2026 amendment (annual dark-pattern self-audit); Dark Patterns Guidelines 2023 (drip pricing, false urgency, etc.) [VERIFIED](https://ccpa.doca.gov.in/files/The%20Guidelines%20for%20Prevention%20and%20Regulation%20of%20Dark%20Patterns,%202023_1732707717.pdf) | Lawyer review of price display, promo expiry, refunds, deletion |
| Data protection (DPDP) | KYC/PAN/bank data for payouts | Retention and consent |

---

## 19. Migration and rollout proposal (documentation only)

1. Founder approves §20. (5:4 is approved for modelling only; implementation needs a separate yes.)
2. CA/legal answers on §18 (blocking before real money).
3. **Code change on the feature branch, not now:**
   - rule set `…-5to4` with `BeansNumerator 4 / DiamondsDenominator 5`;
   - host carry table + settlement/reversal formulas;
   - Account XP basis change;
   - Host Level view (Beans released, gates, 20% cap) driving `EligibleMaxRate`;
   - hold by trust;
   - Free Call Card per decision;
   - reconciliation invariant;
   - Go/Postgres tests mirroring `docs/finance/test_monetization_ledger.py` (same 12 cases, real transactions).
4. **Existing balances:** pre-launch test data. If real Beans exist, they keep their value (Bean value unchanged at ₹0.005), so no conversion is needed. Only calls settled after the effective time use 5:4.
5. Recompute XP/Host Level from ledger history; cap stored prices above new eligibility (existing `CapRate`).
6. **Provider set-up**, each with explicit cost approval:
   - Supabase Pro for production;
   - Sightengine plan;
   - SMS provider (DLT);
   - Play Billing service account;
   - payout provider quote;
   - keep Cloud Run min 0 unless cold starts hurt incoming calls.
7. Launch with payouts off and the 14-day hold. Measure paid minutes per payer, rate mix, call length, sign-ups per payer, refund rate and actual provider bills for 4–8 weeks, then re-run the model.

---

## 20. Founder decision table

**Approved:** only #1, and only for modelling. **v4:** the authoritative, more detailed list is the decision register v4 (categories A/B/C). This table is kept for history.

| # | Item | Recommended | Why | Financial consequence (base unless stated) | Approval needed |
|---|---|---|---|---|---|
| 1 | Conversion | 5 D → 4 B, ₹0.005/B | — | Host ₹0.004/D (+33.36% vs M1); 5-min base margin 47.7% | ✅ modelling only. **Implementation: yes** |
| 2 | Remainder carry | Per-host carry in fifths, persisted with the settlement (§8.3) | Exact; no systematic underpayment | Hosts gain ~0.4 Bean/call vs flooring at 500/1,000 D/min (≈ ₹0.002/call); ≤ ₹0.004 pending per host | **Yes** |
| 3 | Reversal policy | Call-specific; bounded; recover own held → available → receivable; receivable offsets future releases and blocks withdrawals | Never touches unrelated calls' Beans | Post-payout reversals become receivables (credit risk); reserve not reduced by them | **Yes** |
| 4 | Packs | Keep the six seeded packs; volume bonus = purchased | ≥ 45% margin per Diamond (conservative) | Host share 16.2–19.3% by pack | **Yes** |
| 5 | Promo Diamonds | 30-day expiry; spent first; ≤ 3% of last month's Diamonds consumed; hosts earn on promo spend | Host fairness; bounded | Reserve +₹3,690 at 1,000 payers; cost ≤ 3% × ₹0.004/D consumed | **Yes** |
| 6 | Free Call Card | **Off at launch** (matches "no free matching"); or budgeted, no XP | Fraud vector | Saves ₹11.71 per free call | **Yes** |
| 7 | Account XP vs Host Level | Split; Host Level = paid Beans released; P12 thresholds; Level 10 = 40M Beans = ₹2 L | Stops buying a price ceiling (₹1.03 L today) | None direct | **Yes** |
| 8 | XP basis | 8 × purchased D consumed + paid Beans released | Removes buy-and-hold and free-call XP | None | **Yes** |
| 9 | Host gates | 0/2/5/10/20/35/60/100/150/250 + 20% per-caller cap | 500 at L10 is unrealistic in year one | None | **Yes** |
| 10 | Rate floor/ceiling/Verified | Unchanged | Built; margin-safe | — | No |
| 11 | Default host rate | 1,000 D/min | Break-even 56 payers vs 112 at 500 | Demand-dependent | **Yes** |
| 12 | Hold | 14 days; 7 for Verified + Host Level ≥ 5 | Clawback window | Cash gap −18% (worst) to −30% (avg); slower host cash | **Yes** |
| 13 | Withdrawals | ₹500 = 100,000 B; weekly; platform pays the transfer fee | Host trust | ~0.6% of host pay | **Yes** |
| 14 | Payout provider/KYC/TDS | Written quote; PAN + own-name account; TDS/TCS per CA | Legal duty | ₹6–15 per transfer + compliance | **Yes** + CA |
| 15 | Deletion with unspent Diamonds | Block with explicit consent until legal advice | Consumer-law risk | — | **Yes** + legal |
| 16 | Reserve | §16 formula incl. promo and carry; receivables not netted | Solvency | ₹1.31 L (14-day) / ₹1.59 L (7-day) at 1,000 base payers, before taxes | **Yes** |
| 17 | Caller ₹ display | "Your price" from the caller's own lots (§21) + pack range before purchase | Today's figure overstates by up to 19.6% and prices promo | No revenue effect; trust and legal | **Yes** |
| 18 | Host display and terms | Full earning rule and deductions in host terms and wallet | Host must understand own pay | — | **Yes** |
| 19 | Play fee tier | Enrol in the 15% tier before launch; send a Play Console screenshot | Without it: 30% | 5-min base margin 47.7% vs 32.9% | **Yes** (action) |
| 20 | Supabase production plan | Pro US$25/month | Free pauses after 7 idle days | ₹2,225/month fixed | **Yes** (paid) |
| 21 | Cloud Run min instances (production) | 0 until cold-start data | Pay-as-you-go | 0 vs one always-on instance (price unverified) | **Yes** |
| 22 | SMS provider | DLT gateway via Supabase Send-SMS hook | OTP is the swing cost | Conservative OTP/payer ₹207.20 → ₹7.00 | **Yes** (paid) |
| 23 | Non-infrastructure budget | Lean (₹7,800/month), ads off | Break-even 37 vs 72 payers | — | **Yes** |
| 24 | CA/lawyer | Engage before any real money | §18 | Adviser fees | **Yes** |

---

## 21. Role-specific presentation (no dark patterns)

### Caller ₹/minute display: today vs proposed *(model)*

**Today [CODE]:** `ApproxPaisePerDiamondMilli` picks the pack with the **lowest total price** (Starter, 2.475 paise/D) and shows `rate × 2.475 paise` to **every** caller.

| Caller's Diamonds came from | Effective ₹/min at 1,500 D/min | Shown today | Overstatement |
|---|---:|---:|---:|
| Starter | 37.12 | 37.12 | 0.0% |
| Small | 35.88 | 37.12 | 3.5% |
| Medium | 34.56 | 37.12 | 7.4% |
| Popular | 33.31 | 37.12 | 11.5% |
| Large | 32.13 | 37.12 | 15.5% |
| Premium | 31.03 | 37.12 | 19.6% |
| Promotional Diamonds | 0.00 (free) | 37.12 | prices Diamonds the caller never paid for |

It never understates, but it does not represent the caller's own effective purchase price. It also tells the caller a ₹ figure for free Diamonds.

**Proposed [PROPOSAL]:**
1. **The authoritative price is D/min.** It is what the caller is charged, shown on the host card, before the call and on the running counter.
2. **"Your price ≈ ₹x/min".** The server values the next minutes from the **caller's own wallet in spend order** (promotional first at ₹0, then purchased lots FIFO at each lot's price per Diamond).
   - Example: a wallet with 2,000 promo + Starter + Popular. A 5-minute call at 1,500 D/min (7,500 D) is valued at **₹132.31 (₹26.46/min)**. The current rule shows ₹185.62.
   - Free Diamonds are labelled: "includes 2,000 free Diamonds".
3. **Before any purchase**, or on the store page, show the range for this host: "₹31.03–₹37.12/min depending on pack".
4. **The end-of-call summary** shows Diamonds charged and the ₹ value of the purchased Diamonds used (from the settlement's funding lots), with free Diamonds shown separately.
5. All ₹ figures are server-computed, floored to paise, and labelled "approximate" where they are a projection.

### Caller sees
- Diamond balance (purchased, plus promotional with expiry dates);
- packs with price, Diamonds, and ₹ per 1,000 D;
- host price in D/min and "your price ≈ ₹/min";
- running Diamonds used;
- end-of-call summary;
- own transaction history.

**Never shown to callers:** host Beans, host earnings, the conversion or payout dashboards.

### Host sees
- Bean balance: held (per call, with release date), available, in payout, paid, **pending fraction (n/5 of a Bean)**, and any **receivable** with its reason;
- Beans per minute at their own rate ("at 1,500 D/min you earn 1,200 Beans = ₹6.00 per minute");
- Bean value ₹0.005, minimum withdrawal, hold, schedule, fees, TDS/TCS and other deductions;
- withdrawal history with deductions;
- reversal notices (which call, how many Diamonds reversed, Beans clawed back, from which balance).

The host terms state the earning rule in plain words: "you earn 4 Beans for every 5 Diamonds charged on your calls; 1 Bean = ₹0.005; fractions carry to your next call". It is not left only in an internal document.

### Finance/admin (role-based, audited)
- rule set and version;
- revenue, GST, store fees, host liabilities by state, carry total, receivables, promo liability, the reserve formula result;
- reconciliation status of both identities in §8.1.

**Confidentiality vs concealment.** Dashuri's commission and cost structure are internal commercial information, subject to law, platform rules and required disclosures. Callers are not shown what hosts earn. What may not be hidden or made confusing is what each user needs to understand their **own** transaction: the caller's price and the host's pay and deductions.

---

## 22. Test evidence

```bash
python3 -I -m unittest discover -s docs/finance -p 'test_*.py' -v     # 22 tests, OK (~0.7 s)
python3 -I docs/finance/monetization_math_model.py                     # full model, ~0.1 s
```

| Required case | Test |
|---|---|
| Repeated settlement, same call id and payload → same result, no new posting | `test_replay_same_payload_returns_original_result` |
| Repeated settlement, same id, different payload → `IdempotencyConflict` | `test_replay_different_payload_raises_conflict` |
| Full reversal | `test_full_reversal` |
| Partial reversals (cumulative, bounded) | `test_partial_reversals_are_cumulative_and_bounded` |
| Duplicate reversal (no-op; conflicting payload raises) | `test_duplicate_reversal_is_noop_and_conflict_detected` |
| Over-reversal refused | `test_over_reversal_refused` |
| Reversal after subsequent settlements (other calls untouched) | `test_reversal_after_subsequent_settlements_touches_only_that_call`, `test_reverse_then_resettle_restores_state` |
| Reversal after Bean release | `test_reversal_after_release_claws_available` |
| Reversal after payout (receivable, offset, withdrawal block) | `test_reversal_after_payout_creates_receivable_offset_by_future_earnings` |
| Fractional carry across many calls | `test_fractional_carry_across_calls_is_exact`, `test_many_small_calls_lose_nothing` |
| Refund and chargeback reconciliation | `test_chargeback_reconciles_unspent_spent_and_beans`, `test_refund_before_use_removes_unspent_only`, `test_dispute_then_chargeback_never_resurrects_diamonds` |
| Concurrent settlement attempts | `test_concurrent_duplicate_settlements_credit_once`, `test_concurrent_distinct_settlements_and_reversals` |
| Invariants under random operations | `test_random_operation_sequences_keep_invariants` (25 seeds × 400 steps; `check_invariants()` after every step) |
| Also covered | insufficient balance, promo spent first, promo expiry, failed payout |

**Limits of this evidence:**
- The tests prove the **rules**. They do not prove the future Go/SQL implementation.
- Concurrency is modelled with a process lock standing in for database transactions and row locks. The real guarantees must come from unique keys and `FOR UPDATE`, and the same cases must be re-tested against Postgres when the code is written.
