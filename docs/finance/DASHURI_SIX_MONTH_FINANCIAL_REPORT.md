# Dashuri: six-month financial simulation and profitability analysis

- **Prepared:** 22 Nov 2026, from the code in `dashuri_mvp` (branch `feat/calls-720p-and-app-icon`).
- **Simulation window:** Month 1–6. The default start is January 2027; it can be changed in the simulator.
- **Currency:** INR (₹). L = lakh (₹1,00,000).
- **Model:** `docs/finance/engine/dashuri-model.js`. The dashboard, CSV and JSON all come from this one deterministic engine.
- **Interactive version:** `docs/finance/DASHURI_FINANCIAL_SIMULATOR.html`.

> **Read this first.** The business rules in this model are read from the code: packages, Bean conversion, billing, free-call compensation, refunds and moderation frames. **Every figure about customer and host behaviour is an estimate with no market data behind it.** These are conditional what-if scenarios, not forecasts.

---

## 1. Bottom line

| | Conservative | **Base case** | Optimistic |
|---|---:|---:|---:|
| Gross Diamond purchases (incl. GST) | ₹74,414 | **₹8,10,159** | ₹55,13,174 |
| Revenue recognised (ex GST, Diamonds actually spent) | ₹26,151 | **₹4,79,356** | ₹45,75,202 |
| Total expenses | ₹5,57,778 | **₹6,49,391** | ₹21,14,894 |
| **Six-month operating profit / loss** | **−₹5,31,627** | **−₹1,70,035** | **+₹24,60,308** |
| Gross margin / contribution margin | −47% / −381% | **59.3% / 32.8%** | 65.3% / 60.0% |
| Month 6 operating result | −₹68,938 | **+₹5,602** | +₹7,96,567 |
| First profitable month | none | **Month 6** | Month 1 |
| Minimum starting capital (deepest cash point) | ₹4,94,775 | **₹1,57,477** | ₹1,23,069 |
| Recommended capital (+ reserve + host earnings owed) | ₹7,20,258 | **₹4,06,193** | ₹11,36,675 |
| Paying customers, Month 6 | 25 | **215** | 1,174 |
| Monthly active customers, Month 6 | 908 | **3,379** | 11,039 |
| Owed to hosts, Month 6 (unpaid Beans) | ₹18,669 | **₹1,29,797** | ₹9,06,840 |
| Unspent customer Diamonds, Month 6 (ex GST) | ₹35,019 | **₹1,96,921** | ₹50,258 |

**Is Dashuri viable?** Not yet proven, but not structurally broken.

**Per minute, the economics are very strong.** At 1,500 Diamonds/min the customer pays ₹33.23. After GST, the Play fee, the host's Beans, video and moderation, the platform keeps about **₹18.53 (56%)**. Hosts receive **13.5% of what the customer pays**.

**Fixed costs are small.** They are about ₹25,000 a month before marketing, so break-even arrives early once there are enough paying customers. In the base case that is **~189 active payers a month (~2,960 monthly active users)**.

**What decides the result is demand.** Three things the founder does not yet know:
- how many free-call users pay;
- how many minutes payers actually use;
- how long payers keep buying.

**Three findings are uncomfortable:**
1. **Paid acquisition loses money in the base case.** A paid sign-up at ₹70 brings in only **₹23.8 of lifetime gross profit**. Until conversion and retention are measured, every rupee spent on ads loses about 66 paise.
2. **Hosts earn very little.** In the base case a host earns **₹692 a month (₹15 per online hour)** and cannot withdraw it, because payouts are off. That is not a sustainable supply side.
3. **The conservative case loses money on every user.** Sightengine's minimum plan, OTP SMS at Twilio's India price and free-call compensation cost more than the little revenue it makes.

---

## 2. What the implementation actually does (Phase 1)

### 2.1 Money flow in the code

```
Customer ──₹ (Google Play)──► Diamonds (wallet, liability) ──spent on calls──► revenue
                                                    │                 └─► host Beans (expense, liability until paid)
                                                    └─ refund: only unspent purchased Diamonds are reversed
Free Call Card ──60 s connected──► ₹10 = 2,000 Beans to the host (no revenue)
```

| Rule | Value | Source |
|---|---|---|
| Diamond packages (GST-inclusive, **provisional**) | Starter 4,000 D ₹99 · Small 12,500 D ₹299 · Medium 26,000 D ₹599 · Popular 54,000 D ₹1,199 · Large 1,40,000 D ₹2,999 · Premium 2,90,000 D ₹5,999 | `supabase/migrations/20261121000100_mvp_foundation.sql` |
| Price per Diamond | 2.475 paise (Starter) → 2.069 paise (Premium) | derived |
| Call charge | `⌊rate × billable seconds ÷ 60⌋`, capped by reservation and balance; billing follows the **host's** video; interruptions ≥ 10 s unbilled; 60 s balance needed to start | `calls/timeline.go`, `settle.go`, `economy/rules.go` |
| Host rate | 500–10,000 D/min, default 500; **level ladder unresolved**, so any host can set any rate in range | `rules.go` (`LevelRateCaps: nil`), `hosting.host_profiles` |
| Host earnings | `⌊Diamonds × 10,000 ÷ 16,670⌋` Beans; 1 Bean = ½ paisa → **₹0.0029994 per Diamond** | `rules.go`, rule-set seed |
| Free Call Card | one per phone and device; ₹10 (2,000 Beans) to the host **only for a full 60 s**; 20 per host per day | `settle.go`, `freecall` |
| Refund / void | reverses only unspent purchased Diamonds; spent value is an audited shortfall | `purchases/service.go` (`ReversalAmount`) |
| Beans | 7-day hold, ₹500 minimum withdrawal; clawback possible from held Beans | `rules.go`, `ledger/templates.go` |
| Promo Diamonds | 30-day expiry, spent first. **No promo grants are issued in the MVP** (only the expiry job exists) | `jobs/money.go` |
| Moderation | each participant sends a frame of their own camera every 20 s for the first 180 s → up to 18 Sightengine checks per call | `MVP_DECISIONS_AND_CONTRACT.md` §2.5 |

The exact integer rules are copied into `exact.*` in the engine. They reproduce the backend integration test: **65 s at 4,000 D/min → 4,333 Diamonds → 2,599 Beans (₹12.99).**

### 2.2 Implemented vs operational

| Component | Status | Treatment in the model |
|---|---|---|
| Google Play Billing | Implemented (verify, server consume, RTDN, voided purchases). Not configured: needs Play products, service account and RTDN | The **only** revenue rail |
| Cashfree | Implemented; `CASHFREE_ENABLED=false`; needs Cashfree's written category approval and a Play billing-policy decision | **Excluded** |
| Packages | Seeded, marked `provisional` (D-14) | Exact values; changeable only as optimisation levers |
| Call billing and settlement | Implemented and integration-tested | Exact formula |
| Host payouts | `PAYOUTS_ENABLED=false`; no payout provider; withdrawals return 503 | Beans accrue as a liability; payouts can be switched on only as a stress test |
| Host KYC | Manual moderator review | Review cost per application |
| Nudity moderation | Implemented; needs Sightengine credentials; client-side capture (ADR-013) | Sightengine published plan prices |
| SMS OTP | Supabase phone auth; **provider not chosen** (Twilio fields are dummies) | Editable ₹/SMS |
| Push | Server FCM ready; app lacks `firebase_messaging` | Free |
| Stream video | Implemented; 1280×720 set explicitly | Stream published HD price |
| Infrastructure | Supabase project and GCP project `dashuri-dev` exist for personal testing only | Production plans: Supabase Pro, Cloud Run, etc. |

### 2.3 Provider prices used

| Item | Value | Status |
|---|---|---|
| Stream video | US$1.50 per 1,000 participant-min (HD 720p); first US$100/month free | Verified on Stream's pricing guide, 22 Nov 2026. Free-tier wording varies, so the conservative case assumes no free tier and Full HD ($3.00) |
| Sightengine | Free 2,000 ops; Starter $29 for 10k ops; Pro $99 for 40k ops; +$0.002/op | Official pricing page, 22 Nov 2026. Assumes 1 nudity check = 1 op |
| Google Play fee | 15% (base) / 20% (conservative) | **Unverified for India 2026–27.** Google is restructuring fees and an India schedule was not confirmed |
| OTP SMS | ₹7.4 (Twilio India $0.0832, official) / ₹2.5 base / ₹0.3 optimistic | Base and optimistic are **unquoted estimates** |
| Supabase Pro | US$25/month | Verified |
| GST | 18% inside the price | Statute. **Who remits GST on Play sales needs a CA** |
| Chargeback fee | ₹1,300–1,500 per case | Unverified (third-party reports) |

---

## 3. Scenarios (Phase 3)

All three use the same rules; only the assumptions differ. The full list, with sources, is in `DASHURI_FINANCIAL_ASSUMPTIONS.json`.

| Assumption | Conservative | Base | Optimistic |
|---|---:|---:|---:|
| Organic sign-ups in Month 1 / growth per month | 500 / 6% | 1,200 / 15% | 2,500 / 25% |
| Marketing / CAC per verified sign-up | ₹15,000 / ₹120 | ₹15,000 / ₹70 | ₹15,000 / ₹45 |
| Free-call users who pay | 3% | 6% | 9% |
| Payer monthly churn | 60% | 45% | 35% |
| Purchases per payer per month | 1.2 | 1.4 | 1.7 |
| Package mix (Starter → Premium) | 40/30/15/10/4/1 | 30/30/20/12/6/2 | 25/28/22/14/8/3 |
| Paid calls per payer per month × minutes | 4 × 4 | 5 × 5 | 6 × 6 |
| Average host rate | 1,000 D/min | 1,500 D/min | 2,000 D/min |
| Hosts at launch / new applications per month / host churn | 10 / 15 / 30% | 15 / 20 / 20% | 25 / 30 / 12% |
| Play fee | 20% on inclusive price | 15% on ex-GST | 15% on ex-GST |
| SMS price | ₹7.4 | ₹2.5 | ₹0.3 |
| Safety on-call cover | ₹15,000/mo | ₹10,000/mo | ₹8,000/mo |
| One-time setup | ₹1,25,000 | ₹90,000 | ₹75,000 |

The marketing budget is the same in every scenario, so the differences come from how the market responds.

---

## 4. Six-month P&L and cash: base case (Phase 4)

| ₹ | M1 | M2 | M3 | M4 | M5 | M6 | 6 months |
|---|---:|---:|---:|---:|---:|---:|---:|
| Registered customers (total) | 1,414 | 3,009 | 4,810 | 6,849 | 9,162 | 11,790 | |
| Monthly active customers | 1,344 | 1,906 | 2,271 | 2,609 | 2,971 | 3,379 | |
| Paying customers | 56 | 98 | 131 | 159 | 187 | 215 | |
| Gross Diamond purchases | 53,958 | 93,949 | 1,25,235 | 1,52,416 | 1,78,636 | 2,05,965 | 8,10,159 |
| Google Play fee deducted | 6,756 | 11,764 | 15,681 | 19,084 | 22,367 | 25,789 | 1,01,442 |
| Refunds | 809 | 1,409 | 1,879 | 2,286 | 2,680 | 3,089 | 12,152 |
| Net payment proceeds | 46,393 | 80,776 | 1,07,676 | 1,31,045 | 1,53,589 | 1,77,086 | 6,96,565 |
| **Revenue recognised** | 31,926 | 55,588 | 74,099 | 90,181 | 1,05,696 | 1,21,866 | **4,79,356** |
| Host earnings (paid + free calls) | 11,513 | 16,087 | 19,967 | 23,604 | 27,313 | 31,313 | 1,29,797 |
| Variable infrastructure (Stream, Sightengine, SMS, infra) | 7,916 | 9,292 | 10,722 | 12,199 | 13,815 | 15,629 | 69,573 |
| Fixed costs (cloud plans + operations) | 24,459 | 24,509 | 24,541 | 24,571 | 24,603 | 24,640 | 1,47,323 |
| Marketing | 15,000 | 15,000 | 15,000 | 15,000 | 15,000 | 15,000 | 90,000 |
| **Gross profit** | 17,852 | 32,589 | 43,933 | 53,749 | 63,186 | 73,003 | 2,84,312 |
| Gross margin | 55.9% | 58.6% | 59.3% | 59.6% | 59.8% | 59.9% | 59.3% |
| Contribution | 2,224 | 15,184 | 24,345 | 31,778 | 38,516 | 45,242 | 1,57,289 |
| Contribution margin | 7.0% | 27.3% | 32.9% | 35.2% | 36.4% | 37.1% | 32.8% |
| **Operating profit / loss** (M1 includes ₹90,000 setup) | −1,27,234 | −24,325 | −15,196 | −7,793 | −1,087 | **+5,602** | **−1,70,035** |
| Net cash flow | −1,41,374 | −16,102 | 9,307 | 28,762 | 45,250 | 60,830 | −13,328 |
| Closing cash (from ₹2,00,000) | 58,626 | 42,523 | 51,830 | 80,593 | 1,25,842 | 1,86,672 | |
| Unspent Diamonds (ex GST, liability) | 13,115 | 35,951 | 66,391 | 1,03,438 | 1,46,858 | 1,96,921 | |
| Owed to hosts (Beans, liability) | 11,513 | 27,600 | 47,567 | 71,171 | 98,484 | 1,29,797 | |

**Accounting profit, cash and liabilities are four different numbers.**
- The six-month **operating loss is ₹1.70 L**.
- **Cash only falls ₹13,328**, because hosts are not being paid and Google's Month 6 remittance (₹1,71,107) is still owed.
- Month 6 cash of ₹1.87 L carries **₹1.30 L owed to hosts** and ₹30,633 of GST payable.
- Customers hold **₹2.32 L of unspent Diamonds at their purchase price**.
- **Cash after paying every host is ₹56,875.** None of the deferred amounts is profit.

**Other base-case metrics (Month 6 unless stated):**

| Metric | Value |
|---|---|
| Purchases per paying customer (ARPPU) | ₹956 |
| Revenue per paying customer | ₹566 |
| Revenue per MAU | ₹36.1 |
| Cost per MAU | ₹34.4 |
| Lifetime gross profit per payer (LTV) | ₹753 (≈ 2.2-month life at 45% churn) |
| LTV per registration (4.24% become payers) | **₹23.8** |
| LTV : CAC at ₹70 | **0.34** |
| Burn rate (six-month average) | ₹2,221/month in cash; ₹28,339/month in operating loss |

**Conservative.** Loses ₹5.32 L, never reaches break-even, and runs out of the ₹2 L starting cash in Month 2. It needs **₹4.95 L** at minimum.

**Optimistic.** Profitable from Month 1 and makes ₹24.6 L. It depends on 9% free-call conversion, ₹1,408 of purchases per payer per month and 35% churn, all unproven. By Month 6 it owes hosts **₹9.07 L**, so a payout provider becomes urgent.

---

## 5. Risk and stress testing (Phase 5)

### 5.1 What moves the base-case result most

Each line shows the change in six-month operating profit at the low and high test values.

| Input | Test range | Worse | Better |
|---|---|---:|---:|
| Paid calls per payer | ×0.6 / ×1.4 | −₹1,28,019 | +₹1,27,866 |
| Free-call → paying conversion | ×0.5 / ×1.5 | −₹1,20,282 | +₹1,20,092 |
| Call duration | ×0.7 / ×1.5 | −₹99,261 | +₹1,53,065 |
| SMS price | ×3 / ×0.12 | −₹83,876 | +₹36,905 |
| Organic sign-ups | ×0.5 / ×1.5 | −₹77,823 | +₹76,632 |
| Google Play fee | ×2 / ×0.73 | −₹71,903 | +₹19,414 |
| One-time setup | ×1.5 / ×0.6 | −₹45,000 | +₹36,000 |
| Chargebacks | ×3 / ×0.5 | −₹43,475 | +₹10,869 |
| Payer churn | ×1.25 / ×0.75 | −₹35,237 | +₹43,559 |
| Safety operations | ×1.5 / ×0.5 | −₹30,000 | +₹30,000 |
| Stream price | ×2 / ×0.5 | ₹0 | ₹0 (inside the US$100 free tier) |

**Usage is the top driver, ahead of growth.** Revenue is recognised only when Diamonds are spent. Bigger purchases without more calls only grow the liability: a higher average purchase value slightly lowers profit, through chargebacks on the larger amounts.

### 5.2 Stress tests (base case), ranked by damage

| # | Test | 6-month result | Change | Min. capital | Break-even | Cash after host liability (M6) |
|---|---|---:|---:|---:|---|---:|
| 1 | Customers buy Diamonds but barely use them (calls ×0.3) | −₹3,94,597 | −₹2,24,562 | ₹1,56,929 | none | ₹1,17,530 |
| 2 | Paying conversion −75% | −₹3,94,051 | −₹2,24,016 | ₹3,14,518 | none | −₹1,87,326 |
| 3 | High growth, low conversion | −₹3,39,674 | −₹1,69,640 | ₹1,96,332 | none | −₹1,31,334 |
| 4 | Paying conversion −50% | −₹3,18,945 | −₹1,48,910 | ₹2,15,202 | none | −₹1,05,493 |
| 5 | Customer growth −75% | −₹3,14,318 | −₹1,44,283 | ₹2,78,864 | none | −₹1,04,759 |
| 6 | Customer growth −50% | −₹2,69,530 | −₹99,495 | ₹1,97,485 | none | −₹51,921 |
| 7 | Play fee 30% on inclusive price | −₹2,67,823 | −₹97,789 | ₹1,73,356 | none | −₹46,012 |
| 8 | Moderation cost ×2 | −₹2,54,855 | −₹84,820 | ₹1,88,018 | none | −₹27,945 |
| 9 | Paying conversion −25% | −₹2,44,360 | −₹74,325 | ₹1,72,555 | none | −₹24,180 |
| 10 | Infrastructure ×3 | −₹2,35,768 | −₹65,733 | ₹1,79,699 | none | −₹8,858 |
| 11 | Customer growth −25% | −₹2,21,799 | −₹51,765 | ₹1,66,110 | none | ₹1,804 |
| 12 | Payer churn +15 points | −₹2,17,728 | −₹47,694 | ₹1,57,218 | none | ₹10,815 |
| 13 | Refunds and chargebacks ×3 | −₹2,13,510 | −₹43,475 | ₹1,61,611 | none | ₹11,674 |
| 14 | Host earnings +50% per Diamond | −₹2,08,052 | −₹38,017 | ₹1,57,477 | none | ₹18,858 |
| 15 | Stream bills 4× the assumed rate | −₹1,99,582 | −₹29,547 | ₹1,63,538 | none | ₹27,328 |
| 16 | Hosts online but few calls (3× hosts) | −₹1,95,035 | −₹25,000 | ₹1,66,477 | M6 | ₹31,875 |
| 17 | Host liabilities grow faster | −₹1,88,385 | −₹18,351 | ₹1,51,233 | M6 | ₹43,741 |
| 18 | Stream +100%, no free tier | −₹1,84,808 | −₹14,773 | ₹1,60,507 | M6 | ₹42,101 |
| 19 | Host utilisation halves | −₹1,82,535 | −₹12,500 | ₹1,61,977 | M6 | ₹44,375 |
| 20 | CAC doubles | −₹1,80,443 | −₹10,409 | ₹1,59,005 | M6 | ₹43,390 |
| 21 | Payouts switched on from Month 4 | −₹1,71,025 | −₹990 | ₹1,57,757 | M6 | ₹55,885 |
| 22 | Sudden 10× sign-ups in Month 4 | +₹53,000 | +₹2,23,035 | **₹2,18,563** | M4 | ₹3,63,647 |
| 23 | Customers use Diamonds twice as fast | +₹68,682 | +₹2,38,717 | ₹1,49,703 | M2 | ₹93,009 |

**Answers to the eight specific questions:**
1. **Buy but barely use.** Profit drops by ₹2.25 L because purchases never become revenue. Cash looks fine (₹1.18 L after host liability), but customers hold refundable value. This is the trap of reading bookings as revenue.
2. **Consume faster.** This is the best case for the P&L. Customers top up, and hosts earn more.
3. **Hosts online but few calls.** It costs only ₹25,000, because idle hosts cost almost nothing to the platform. The damage falls on host earnings per hour, which pushes hosts to leave.
4. **High growth, low conversion.** −₹1.70 L. Free calls, OTP SMS and moderation scale with sign-ups, not with payers.
5. **Liabilities faster than revenue.** Owed-to-hosts grows from ₹1.30 L to ₹2.14 L. It stays covered in the base case, but not in tests 2–10.
6. **10× usage.** Profitable, but the cash need jumps to ₹2.19 L. Google pays a month late while SMS, free calls, moderation and Sightengine overage are paid now. A viral month is a **cash crunch**. Hosts also hit the 20-free-calls-per-day cap.
7. **Cannot pay hosts.** In tests 2–10, cash after host liability goes negative. If payouts were switched on, the bank would empty. The conservative case is negative from Month 1.
8. **Stream above assumptions.** Even at 4× it is the 15th-ranked risk (−₹29,547). Video is not where the money goes at this scale.

### 5.3 Most dangerous conditions, ranked by impact

| Rank | Condition | What happens |
|---|---|---|
| 1 | **Low free-call → paid conversion** | This is the acquisition engine. Every free call costs ₹10 to the host plus SMS and moderation. |
| 2 | **Low usage of purchased Diamonds** | Revenue stays deferred while fees and fixed costs are paid. |
| 3 | **Weak organic growth with paid CAC above ₹24** | Ads destroy cash. |
| 4 | **Host supply collapse** | Hosts earn ₹15 per online hour and cannot withdraw. Not in the P&L, but it ends the marketplace. |
| 5 | **Platform and fee risk** | A Play fee of 20–30%, or **Play policy enforcement against an 18+ video-call app**, which is not modelled and would stop all revenue. |
| 6 | **OTP provider choice** | Twilio India costs about ₹7.4/SMS, ~25× an Indian DLT route. |
| 7 | **Chargeback and fraud exposure** | Spent Diamonds cannot be reversed. |

---

## 6. Profitability optimisation (Phase 6)

### 6.1 Diamond pricing

**At 1,500 D/min, one package spent in full:**

| Package | Price | Paise/D | Minutes | GST | Play | Host | Video + mod. | Reserve | Contribution | % of price |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Starter | ₹99 | 2.475 | 2.7 | 15 | 13 | 12 | 2.4 | 2 | **₹55** | 55.4% |
| Small | ₹299 | 2.392 | 8.3 | 46 | 38 | 37 | 7.6 | 6 | **₹164** | 54.8% |
| Medium | ₹599 | 2.304 | 17.3 | 91 | 76 | 78 | 15.7 | 13 | **₹325** | 54.3% |
| Popular | ₹1,199 | 2.220 | 36.0 | 183 | 152 | 162 | 32.7 | 25 | **₹644** | 53.7% |
| Large | ₹2,999 | 2.142 | 93.3 | 457 | 381 | 420 | 84.7 | 64 | **₹1,592** | 53.1% |
| Premium | ₹5,999 | 2.069 | 193.3 | 915 | 763 | 870 | 175.5 | 127 | **₹3,149** | 52.5% |

- **Every package is solidly margin-positive.** Margin is 47–56% depending on rate, so small packages are not a problem.
- **Large packs are not too generous.** The bulk discount costs only ~3 points of margin. Removing it adds just ₹5,185 over six months, because Large and Premium are 8% of purchases.
- **A 10% price rise** adds ₹21,256 over six months, assuming a 0.6 price elasticity. That is small and risky before demand is known.
- **Best balance: Popular (₹1,199).** It gives ₹644 of contribution and 36 minutes at 1,500 D/min, which is enough for repeat calls with one host.
- **Pricing is not the bottleneck.** Do not change packages before you have purchase data.

### 6.2 Call pricing

| D/min | Customer ₹/min | Host ₹/min | Platform net ₹/min | Host ₹ per talk-hour |
|---:|---:|---:|---:|---:|
| 500 (default) | 11.08 | 1.50 | 5.57 | 90 |
| 1,000 | 22.15 | 3.00 | 12.05 | 180 |
| 1,500 | 33.23 | 4.50 | 18.53 | 270 |
| 2,000 | 44.31 | 6.00 | 25.01 | 360 |
| 4,000 | 88.61 | 12.00 | 50.93 | 720 |
| 10,000 | 221.54 | 29.99 | 128.68 | 1,800 |

- **There is no "minimum viable" call price problem.** Even 500 D/min clears every direct cost (₹5.57/min net), because host Beans scale with Diamonds. Video and moderation together cost ₹0.91/min.
- **Raising the average rate 33%** (by deciding the level ladder) adds ₹41,696 over six months at a 0.6 rate elasticity.
- **Peak pricing is not recommended** at this scale. There is no peak congestion: hosts are idle 95% of the time.
- **Longer calls are pure upside** (+₹1.53 L at 1.5× duration). Discovery should favour hosts with long average calls.

### 6.3 Host economics

- **The host take is very low: 13.5% of the customer price, about 16% of the ex-GST price.** The repository's earlier research (docs/simulation, unverified) puts competitors at about ₹88 per 10,000 Beans, against Dashuri's ₹50.
- **Low pay per minute is not the main problem. Idle time is.** At 4.6% utilisation, even paying hosts 50% more per Diamond only adds **₹51/month per host** and costs the platform ₹38,017.
- **Fixing utilisation helps hosts far more.** Halving new host intake raises earnings per host by **₹556/month** and costs nothing.

**Recommendation:**
1. Keep the active host pool proportional to demand. At 25% utilisation one host serves about 30 active payers' minutes, and an opted-in host can take ~216 free calls a month. So 10–15 hosts are enough until there are ~300 active payers; the base case has 45 by Month 6.
2. Schedule hosts into the hours that payers are online.
3. Only after utilisation passes ~15%, consider a richer Bean rule. Every +10% in host share costs about 1.6 points of gross margin.
4. Reward retention rather than raw volume. For example, a Bean bonus for hosts whose callers come back, paid from the platform's margin and capped.

### 6.4 Customer retention

| Proposal | 6-month Δ | Month 6 Δ | Note |
|---|---:|---:|---|
| Better first call: free-call conversion +50% (route free calls to the best verified hosts, Starter offer at the end of the minute, in-call top-up D-10) | **+₹1,20,092** | +₹30,083 | Highest-impact change in the model |
| Loyalty: 5% bonus Diamonds, churn −10 points | +₹5,297 | +₹4,642 | Pays back slowly. Promo Diamonds cost host Beans with no revenue |
| Referral: 4,000 promo Diamonds per referred sign-up (0.3 per payer per month) | −₹9,829 | −₹2,722 | Not worth it at base conversion. Also a fraud vector |
| Re-engagement pushes ("favourite host online") | not modelled separately | | Needs `firebase_messaging` in the app first |

### 6.5 Infrastructure

| Item | Base 6-month cost | Saving available | How |
|---|---:|---:|---|
| OTP SMS | ₹41,937 | **₹36,905** | Indian DLT provider via a Supabase Send-SMS hook (~₹0.3/SMS); keep rate limits |
| Sightengine | ₹23,290 | none recommended | Do not reduce frame frequency: this is child-safety and nudity enforcement |
| Stream | ₹0 | none | Covered by the US$100 free tier at base volume. 720p is already the cheapest HD tier |
| Supabase + Cloud Run + GCP + variable infra | ₹32,867 | small | Stay on Pro with Micro compute; Cloud Run min instances = 1 only for the API |
| Safety on-call | ₹60,000 | ₹60,000 if the founder covers it | The legal duty (IT Rules takedown timelines, grievance officer) remains |

### 6.6 Marketing efficiency

| Metric (base) | Value |
|---|---|
| Lifetime gross profit per registration | ₹23.8 |
| **Maximum affordable CAC** (contribution after free call and SMS = 0) | **₹23.8** per verified sign-up |
| Target CAC (LTV ÷ 3) | **₹7.9** |
| CAC assumed | ₹70, never paid back |
| Recommended paid budget | **₹0 until measured LTV per registration > 3× CAC** |
| Organic requirement without ads | ≈ 119 active payers. With ₹0 marketing the base case reaches that in **Month 4**, and the six-month loss falls from ₹1.70 L to ₹1.01 L |
| Optimistic | LTV/reg ₹148, CAC ₹45: LTV:CAC 3.3, payback < 1 month. Ads work only if conversion and spend are optimistic-level |

### 6.7 Revenue opportunities that fit the marketplace

| Opportunity | Revenue impact | Cost | Complexity | Risk | Time |
|---|---|---|---|---|---|
| In-call top-up (D-10) | Converts the low-balance moment; lifts paid minutes | ~2 weeks | Low (Play flow exists) | Low | Short term |
| Level rate ladder (decide D-16 / rate caps) | +₹41,696 / 6 mo at +33% rate | Days (config) | Low | Demand response | Short term |
| Scheduled calls / host availability slots | Higher utilisation, longer calls | 3–4 weeks | Medium | Low | Short term |
| Gifts during calls (Diamonds → Beans) | Common in this category; unmodelled | 4–6 weeks | Medium | Policy review needed | Long term |
| Subscription ("VIP" rate discount) | Smooths revenue; Play fee 10% on recurring under new schedule (unverified) | 4+ weeks | Medium | Cannibalisation | Long term |
| Cashfree second rail | Lower fee than Play | Built | High: needs approval and Play policy | Play policy breach risk | Only after written approvals |

Each change's measured effect is in the simulator's **Improve** and **Actions** views.

---

## 7. Break-even and capital (Phase 7, base case)

| Question | Answer | Calculation |
|---|---|---|
| 1. Starting capital | **₹1,57,477 minimum; ₹4,06,193 recommended** | Min = deepest cumulative cash point from ₹0. Recommended = min + 3 months of fixed cost and marketing (₹1,18,919) + host earnings owed at M6 (₹1,29,797) |
| 2. Six-month loss | **₹1.70 L base**, ₹5.32 L conservative, ₹3.95 L worst base stress test | Σ (revenue − expenses) |
| 3. Paying customers to break even | **~189 active payers/month** (117 with no marketing) | (fixed ₹24,640 + marketing ₹15,000) ÷ contribution per payer ₹210 |
| 4. Monthly active customers | **~2,960** | 189 ÷ 6.4% payer share |
| 5. Active hosts | **~6 at 25% utilisation** (3 at the 60% physical max); 45 are active in M6 | 3,792 min ÷ (online min per host × utilisation) |
| 6. Paid minutes per month | **~3,792** | 189 payers × 20.1 min |
| 7. Average purchase value | **₹631** at Month 6 payer and purchase counts (today ₹683) | (fixed + marketing + other variable) ÷ (gross profit per ₹ booked × purchases) |
| 8. Marketing allocation | **₹0 paid** until LTV:CAC ≥ 3; at most ₹24 per verified sign-up | §6.6 |
| 9. Minimum sustainable gross margin | **55.3%** at Month 6 revenue (model: 59.9%) | (other variable + fixed + marketing) ÷ revenue |
| 10. Operationally profitable | **Month 6** base; never (conservative); Month 1 (optimistic) | first month with operating profit ≥ 0 |
| 11. Cash reserve | **₹2,48,716** | 3 months of fixed cost and marketing + all unpaid host earnings |
| 12. Worst-case exposure | **≈ ₹5.5 L** | Conservative six-month loss (₹5.32 L) + host earnings owed (₹0.19 L). A Play account suspension is outside the model and would stop all revenue |

Founder salary is excluded throughout. Adding ₹30,000/month raises base break-even to ~332 active payers.

---

## 8. Validation (Phase 10)

`node docs/finance/engine/validate.mjs`: **52 checks, 52 passed.**

| # | Check | Result |
|---|---|---|
| 1 | Packages reconcile to the migration seed (parsed from SQL) | Pass |
| 2 | Bean rule, rate range, free-call rule, minimums reconcile to `rules.go` (parsed) | Pass |
| 3 | Settlement reproduces the integration test (65 s at 4,000 → 4,333 D → 2,599 B) | Pass |
| 4 | Refund reverses only unspent Diamonds (`ReversalAmount`) | Pass |
| 5 | Unspent Diamonds are never revenue (Diamond conservation; buy-but-never-use → ₹0 revenue) | Pass |
| 6 | Host Beans are expensed and held as a liability (earned − paid = liability) | Pass |
| 7 | Cashfree not in revenue | Pass |
| 8 | Payouts off: ₹0 paid in every scenario | Pass |
| 9 | Infrastructure, SMS and fixed costs non-zero every month | Pass |
| 10 | No double counting (expense identity, profit identity, cash identity, Play fee deducted = expensed + deferred, GST = 18/118) | Pass |
| 11 | 15 extreme input sets × 3 scenarios: all outputs finite | Pass |
| 12–14 | CSV (19 lines × 69 columns) and JSON (82 assumptions) exports | Pass |
| 17 | No keys or secrets in the engine | Pass |

**Dashboard test** (headless Chrome, `file://`, no network or credentials): **66 checks, 66 passed.** They cover:
- all 12 views render, with no `NaN` or `undefined`;
- all 3 scenario buttons;
- all 13 simulator sliders recalculate;
- reset;
- all 11 improvement levers and all 12 proposal sliders;
- 76 of 81 assumption inputs change outputs. The 5 that do not are inactive at base values, for example `topUpShare` when nobody runs out of Diamonds;
- package-mix edit, start date, rate selector;
- CSV, JSON and Markdown exports;
- extreme slider values;
- zero runtime errors.

At 500 px wide, no view scrolls sideways.

**Not verified:** demand behaviour, India Play fee schedule, SMS quote, chargeback fees, GST treatment of Play sales, payout fees.

---

## 9. Requires professional review

- **Chartered accountant:**
  - GST on Play sales (principal or agent; who remits) and the Play fee base;
  - revenue recognition of Diamonds (breakage policy) and deferral of the Play fee;
  - Bean liability presentation;
  - TDS on host payouts.
- **Lawyer:**
  - payout structure (payment aggregator or PPI rules);
  - IT Rules moderation and takedown duties for an 18+ video-call marketplace;
  - DPDP;
  - host agreement.
- **Google Play:**
  - the policy position of a paid 18+ video-calling marketplace, including the user-generated-content and sexual-content policies and the random-matching Free Call Card;
  - developer-account risk.
