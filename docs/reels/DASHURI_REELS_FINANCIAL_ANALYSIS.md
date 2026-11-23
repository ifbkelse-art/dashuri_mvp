# Dashuri Reels — six-month financial comparison (EXPERIMENT)

**Interactive version:** open `docs/reels/DASHURI_REELS_FINANCIAL_SIMULATOR.html` in any browser. It works offline, needs no credentials, and every input is editable.

**Model files:**
- `docs/reels/sim/reels-model.js`
- `docs/reels/sim/validate.mjs`: 32 of 32 checks pass.

## 1. Method: no double counting

- **Scenario A, Dashuri without Reels:** the existing six-month model (`docs/finance/engine/dashuri-model.js`), unchanged. It uses the implemented rules (packages, the Diamond → Bean rule, the Play fee, GST and host liabilities) and the finance assumptions.
- **Scenario B, Dashuri with Reels:** the **same engine**, with only five inputs changed by explicit, editable Reels levers. All Reels operating costs are charged to B.

| Lever | How it changes the engine | Conservative | Base | Optimistic |
|---|---|---:|---:|---:|
| Payer churn reduction (relative) | `payerChurn × (1 − x)` | 0% | 6% | 15% |
| Non-payer retention uplift | `nonPayerRetention + x` | 0 | +3 pts | +8 pts |
| Later conversion uplift | `convLater × (1 + x)` | 0% | +10% | +30% |
| Organic sign-up uplift (shared links) | `organicNewM1 × (1 + x)` | 0% | +3% | +10% |
| Calls lost to time on Reels | `callsPerPayer × (1 − x)` | 3% | 0% | 0% |

**Incremental = B − A.** Calls existing customers would make anyway are identical in A and B, so they are never credited to Reels. This is tested: with zero impact, incremental revenue is exactly 0 and the incremental operating result is exactly minus the Reels costs.

The CTA funnel (clicks per 1,000 host-reel views, calls per click) is a **diagnostic only**. It shows what the attribution analytics should measure; it does not add revenue.

## 2. Verified facts versus assumptions

| Verified (official prices, 22 Nov 2026) or implemented | Assumption (no data) |
|---|---|
| Mux:<br>• 100,000 free delivery min/month<br>• $20/month PAYG credit<br>• basic encoding $0<br>• storage from $0.0024/min/month (720p)<br>• delivery about $0.0008/min (720p) | Share of monthly active users who watch Reels: 45% |
| Sightengine: Starter $29 / 10k operations, then $0.002/op; 1 operation = 1 model × 1 frame | Views per viewer per month: 120 |
| Frames every 2 s × 3 models (implemented defaults) | Watch time per view: 12 s |
| Reel length 15–60 s (implemented) | Creators: 3% of non-host MAU × 3 reels; hosts: 70% × 8 reels |
| Every first reel gets a human review (implemented) | Human review ₹6; backend ₹1.5 per 1,000 views; support ₹2,000/month; legal review ₹15,000 one-time |
| Diamond/Bean rules, packages, Play fee, GST, host liability (finance engine) | All five business levers above |

## 3. Results (six months)

| | Conservative | **Base** | Optimistic |
|---|---:|---:|---:|
| Operating result A (no Reels) | −₹5,31,627 | **−₹1,70,035** | +₹24,60,308 |
| Operating result B (with Reels) | −₹5,87,353 | **−₹2,02,504** | +₹27,63,958 |
| **Incremental operating result** | **−₹55,727** | **−₹32,470** | **+₹3,03,651** |
| Incremental revenue (recognised) | −₹785 | ₹35,725 | ₹9,66,083 |
| Incremental contribution (after Reels variable costs) | −₹1,727 | −₹5,396 | ₹3,31,127 |
| Reels operating cost, all-in | ₹55,282 | ₹50,638 | ₹3,01,608 |
| of which variable (video, moderation, review, backend) | ₹1,282 | ₹23,638 | ₹2,74,608 |
| Views | 70,049 | 8,26,787 | 76,48,332 |
| Variable cost per 1,000 views | ₹18 | ₹29 | ₹36 |
| All-in cost per published reel | ₹212 | ₹23 | ₹17 |
| Extra cash needed for Reels | ₹55,251 | ₹27,959 | ₹42,866 |
| Extra host liability at Month 6 (Beans owed; payouts off) | −₹124 | ₹7,104 | ₹1,71,201 |
| Extra paying customers at Month 6 | 0 | +19.5 | +290 |

**Base case, Month 6:**
- about 1.94 L views and 38,900 watch-minutes (inside Mux's free 100k), so **video costs ₹0**;
- about 570 uploads, so about 25,800 Sightengine operations;
- **automated moderation ₹4,592/month** is the largest variable cost;
- total Reels cost ₹7,572/month;
- incremental revenue ₹11,024/month;
- incremental operating result −₹1,709/month and improving.

**Break-even view volume:**
- **Base:** not reached at the assumed impact. Incremental value per view (₹0.022) is below the variable cost per view (₹0.029), so more views do not close the gap.
- **Optimistic:** value per view is ₹0.079 against ₹0.036 variable, so Reels covers its fixed costs from about **1.04 L views a month**.
- **Break-even condition:** holding the other base inputs, Reels pays for itself over six months if it cuts paying-customer churn by about **24% (relative)**, against 6% assumed.
- **Zero impact:** Reels is a pure cost of **₹49,841** over six months.

## 4. Does Reels improve the six-month outlook?

**Not on base assumptions. It improves the outlook only if it moves retention a lot.**

1. **Running Reels is cheap; moderating it is not.** Video hosting is about free at Dashuri's scale (Mux free tier). The real costs are:
   - per-frame moderation, which grows with uploads, not views;
   - human review of first reels;
   - fixed support and legal costs.
2. **The upside is all in assumptions nobody has measured.** In the optimistic case Reels adds about ₹3 L, because churn and conversion improve across 290 extra payers. In the conservative case it loses about ₹56k, as a distraction with no lift.
3. **Moderation cost is the lever.** Halving the frame rate (one frame every 4 s) or allowing hosts only roughly halves operations. Try both in the simulator.
4. **Host liabilities grow** with any extra paid minutes, while payouts are off (see `docs/finance`).

## 5. What to do

1. Do not launch Reels widely. Run it as a **hosts-only pilot** (about 10–15 hosts) with a holdout group. Measure:
   - month-2 payer retention for viewers versus the holdout;
   - reel-attributed paid calls (`GET /v1/admin/reels/analytics`).
2. The bar to beat: **at least a 24% relative churn reduction**, or the equivalent in conversion. If the pilot shows less, keep Reels off.
3. Keep moderation cost proportional:
   - frames every 3–4 s for established creators;
   - the full rate for first reels.
4. Re-check provider prices on the official pages before committing money. No paid service was activated.
