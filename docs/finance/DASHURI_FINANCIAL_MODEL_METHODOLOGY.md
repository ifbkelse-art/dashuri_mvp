# Dashuri financial model: methodology

## Files

| File | Role |
|---|---|
| `engine/dashuri-model.js` | Calculation engine: pure, deterministic, no DOM or I/O. It holds the implemented rules, every assumption (with source, status and confidence), the monthly model, sensitivity, stress tests, levers and exports |
| `engine/simulator.template.html` | Presentation only. It calls the engine; no number is hard-coded in the page |
| `engine/build.mjs` | Inlines the engine into `DASHURI_FINANCIAL_SIMULATOR.html` and writes the CSV and JSON |
| `engine/validate.mjs` | Reconciles the engine with the migrations and the Go code, then checks the accounting identities (52 checks) |

Rebuild and re-check, from the repo root (Node 18+, no dependencies):

```
node docs/finance/engine/validate.mjs
node docs/finance/engine/build.mjs
```

Open `docs/finance/DASHURI_FINANCIAL_SIMULATOR.html` in a browser. It works offline; the only network request is optional Google Fonts.

## 1. Implemented rules (not assumptions)

Rule set `2026-11-17-founder` (`backend/internal/modules/economy/rules.go`, `economy.rule_sets`). Packages come from `economy.diamond_packages` (migration `20261121000100`; GST-inclusive, `provisional = true`).

| Formula | Code |
|---|---|
| Diamonds charged = ⌊rate × billable s ÷ 60⌋, ≤ reservation, ≤ balance | `DiamondsForSeconds`, `ComputeCharge` |
| Beans = ⌊Diamonds × 10,000 ÷ 16,670⌋ | `BeansForDiamonds` |
| ₹ = Beans × ½ paisa | `PaiseForBeans` |
| Free call: billable ≥ 60 s → 2,000 Beans (₹10) to the host | `settle.go` (`compensate`) |
| Refund reverses min(purchase, purchased balance − committed) | `ReversalAmount` |
| Moderation frames per participant = ⌊min(call s, 180) ÷ 20⌋ | contract §2.5 |
| Start requires 60 s of balance; interruptions ≥ 10 s unbilled; billing follows host video | `rules.go`, `timeline.go` |

The monthly model uses the continuous equivalents. Per-call flooring is under one Diamond and one Bean per call, which is immaterial at this volume.

## 2. Customer model (per month m)

```
new_organic(m)  = organic_M1 × (1 + growth)^(m−1) × spike(m)
new_paid(m)     = marketing_budget ÷ CAC                 (CAC per OTP-verified registration)
new_referred(m) = active_payers(m−1) × referral_rate
eligible_new    = new_registrations × eligible_share    (18+ and account checks)

free_calls_started   = min(eligible_new × free_call_use,
                           hosts × opt_in × online_day_share × 30 × 20)
free_calls_completed = started × completion_share       (host paid ₹10)

new_payers = started × conv_free + (eligible_new − started) × conv_other
           + retained_non_payers × conv_later
active_payers(m)     = active_payers(m−1) × (1 − payer_churn) + new_payers
active_non_payers(m) = active_non_payers(m−1) × retention − later converters + new non-paying eligible users
MAU = active_payers + active_non_payers;  DAU = MAU × DAU/MAU
```

## 3. Purchases, wallets and calls

```
mix'            = package mix tilted so that average price = base average × purchase_value_multiplier
planned         = active_payers × purchases_per_payer × (₹/D ÷ base ₹/D)^(−price_elasticity)
demand_minutes  = active_payers × calls_per_payer × connect_rate × duration × (1 − interruption)
                  × (rate ÷ ref_rate)^(−rate_elasticity)
capacity        = hosts × online_day_share × 30 × hours × 60 × max_busy − free-call minutes
top_ups         = max(0, min(demand, capacity) × rate − wallet_after_planned) × top_up_share ÷ D per purchase
purchases       = planned + top_ups; split by mix'
paid_minutes    = min(demand, wallet ÷ rate, capacity)
Diamonds used   = paid_minutes × rate                    (promotional Diamonds first, then purchased)
```

Wallets of payers who churn move to a dormant pool. **Purchased Diamonds never expire**, so dormant balances stay a liability. Promotional Diamonds expire after 30 days.

## 4. Accounting treatment

| Item | Treatment |
|---|---|
| Gross purchase value (bookings) | Σ packages × GST-inclusive price. **Not revenue** |
| Refunds (before use) | Removed from bookings and from the wallet; never revenue; Play fee refunded (assumed) |
| GST | Net sales × 18/118. A liability paid the following month (GSTR-3B). Who remits GST on Play sales needs CA confirmation |
| **Revenue recognised** | Purchased Diamonds spent × ex-GST ₹ per Diamond (mix average). Unspent Diamonds are **deferred revenue**. No breakage is recognised within six months (conservative; needs a CA policy) |
| Google Play fee | Deducted from cash at sale (15% on ex-GST in the base). **Expensed in proportion to Diamonds spent**; the rest is a deferred contract cost |
| Host Beans | **Expense when earned, liability until paid.** Never platform profit. Promotional Diamonds spent still earn Beans |
| Free-call compensation | ₹10 per completed free call: an acquisition expense and a Bean liability |
| Chargebacks (after use) | Loss = chargeback ÷ 1.18 (GST reclaimed by credit note, CA to confirm) + fee per case; Beans clawed back from held balances at the clawback share |
| Payouts | ₹0 while `PAYOUTS_ENABLED=false`. If switched on: opening Bean liability × withdraw share, plus a transfer fee |

**P&L definitions:**

```
gross profit       = revenue − (host Beans on paid calls − clawback) − Play fee expensed − Stream
                     − moderation (API + human review) − chargeback loss
contribution       = gross profit − free-call compensation − SMS − variable infra − support
                     − KYC review − payout fees
operating profit   = contribution − fixed costs (cloud plans, accounting, legal, safety on-call, tools,
                     other, salary) − marketing − one-time setup
```

**Cash:**

```
cash in(m)    = net proceeds(m − 1) − chargebacks − chargeback fees      (Google pays ~15th of next month)
cash out(m)   = GST(m − 1) + operating cash costs(m) + host payouts(m)
closing cash  = starting cash + Σ net cash flow
cash after host liability = closing cash − unpaid Beans
economic cash = closing cash + owed by Google − GST payable − unpaid Beans
```

## 5. Costs

| Cost | Formula | Status |
|---|---|---|
| Stream | max(0, 2 × (paid min ÷ (1 − interruption) + free-call min + unbilled min per attempt) ÷ 1,000 × $/1,000 − free usage) × ₹/$ | Price verified 22 Nov 2026 |
| Sightengine | ops = 2 × (paid calls × frames(duration) + free calls × 3); ≤ 2,000 free; else min($29 + $0.002 × (ops − 10k), $99 + $0.002 × (ops − 40k)) | Official page; op definition assumed |
| Human review | calls ÷ 1,000 × reports per 1,000 × ₹ per review | Estimate |
| SMS | (registrations × SMS per registration + MAU × re-login SMS) × ₹/SMS | Provider not chosen |
| Supabase | $25 Pro + compute upgrades at 15k / 40k / 100k MAU ($50 / $100 / $200) | Pro verified; upgrades estimated |
| Cloud Run | $/month × (1 + MAU ÷ 20,000) | Estimate (no load test) |
| Other | GCP extras, variable infra and support per 1,000 MAU, KYC review per application, accounting, legal, domain, tools, safety on-call, one-time setup | Estimates and placeholders |

Taxes not modelled:
- **income tax**: the base case makes a loss over six months;
- **TDS on host payouts**: payouts are off;
- **a possible social-security levy on platforms**: not notified as applying.

## 6. Derived metrics

| Metric | Formula |
|---|---|
| Minimum capital | −min over months of cumulative net cash flow from ₹0 |
| Recommended capital | minimum + reserve (months × (fixed + marketing + any negative contribution)) + Bean liability at Month 6 |
| Break-even payers | (Month 6 fixed costs + marketing) ÷ (Month 6 contribution ÷ active payers) |
| Break-even MAU | break-even payers ÷ payer share of MAU |
| Break-even minutes | break-even payers × paid minutes per payer |
| Break-even hosts | break-even minutes ÷ (online minutes per host × 25%) (or × max busy share) |
| Required average purchase | (fixed + marketing + other variable) ÷ (gross profit per ₹ booked × Month 6 purchases) |
| Minimum gross margin | (other variable + fixed + marketing) ÷ Month 6 revenue |
| LTV per payer | Month 6 gross profit per active payer ÷ monthly payer churn |
| LTV per registration | LTV per payer × (new payers ÷ new registrations) − (free-call comp + SMS) per registration |
| Max / target CAC | LTV per registration / LTV per registration ÷ 3 |
| Payback (months) | ln(1 − CAC × churn ÷ (conversion × GP per payer)) ÷ ln(1 − churn); none if the argument ≤ 0 |
| Sensitivity | Re-run with one input at its low or high multiplier; Δ six-month operating profit |

## 7. Limitations

- **Demand is unknown.** Every customer and host behaviour input is an estimate, so the scenarios are what-ifs.
- **Deterministic and monthly.** There is no variance, no intra-month timing, and no cohort-level spend distribution (whales).
- **Host churn is an input.** It does not react to earnings, except in the "pay hosts more" lever.
- **Unverified prices:** India Play fee 2026–27, SMS, chargeback fee, payout fee, Sightengine op counting, Supabase compute upgrades.
- **Accounting positions need a CA:** GST principal or agent, Play fee base, breakage, deferral of the Play fee.
- **Not modelled:**
  - Play policy enforcement or developer-account suspension, which would stop all revenue;
  - legal costs of incidents;
  - founder time;
  - fraud beyond the chargeback rate.
- **Cashfree is excluded by design.** Enabling it needs written approvals and a Play billing-policy decision, and it would change the fee line, not the rules.
