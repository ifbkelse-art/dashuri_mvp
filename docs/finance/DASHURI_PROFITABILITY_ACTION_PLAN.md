# Dashuri: profitability action plan

**Basis:** the base-case model (`DASHURI_FINANCIAL_SIMULATOR.html`, Actions and Improve views).

**How each number was produced:** each change is applied on its own to the base case, and the impact is the change in operating profit. The effects do not add up exactly, so combine changes in the simulator's Improve view to see them together.

**Baseline:** six-month operating loss **−₹1,70,035**, Month 6 **+₹5,602**, minimum capital **₹1,57,477**.

## The short version

1. **Stop paid acquisition before it starts.** At ₹70 per verified sign-up, a user is worth ₹23.8 of lifetime gross profit.
2. **Spend the next three months making the first call convert,** and measure it.
3. **Keep fixed and per-user costs near zero** while volume is small.
4. **Keep the host pool small and busy.**
5. **Put a payout path in place** before host earnings outgrow cash.

## Top five actions (ranked by Month 6 operating profit gained)

| # | Action | Month 6 | 6 months | Capital | Effort | Time to benefit | Risk |
|---|---|---:|---:|---:|---|---|---|
| 1 | **Make the free call convert: +50% free-call → paid** | +₹30,083 | +₹1,20,092 | −₹15,049 | Medium | 1–2 months | Low |
| 2 | **Decide the level rate ladder: +33% average D/min** | +₹10,630 | +₹41,696 | −₹218 | Low (config) | Weeks | Medium (demand response) |
| 3 | **₹0 paid ads until measured LTV:CAC ≥ 3** | +₹10,264 | +₹69,183 | −₹26,944 | Low | Immediate | Medium (slower growth) |
| 4 | **Founder covers safety on-call for six months** | +₹10,000 | +₹60,000 | −₹20,000 | Low | Immediate | High founder load; the legal duty stays |
| 5 | **Cheap OTP: Indian DLT gateway via a Supabase Send-SMS hook** | +₹8,259 | +₹36,905 | −₹9,319 | Low | 2–3 weeks | Low |

Ranked 6–8:
- **Package prices +10%:** +₹5,414 / +₹21,256. Wait for purchase data.
- **Retention programme** (5% loyalty bonus, churn −10 pts): +₹4,642 / +₹5,297.
- **Remove the Large/Premium bulk bonus:** +₹1,321 / +₹5,185.

Tested and **not recommended now**:
- **Referral with 4,000 promo Diamonds:** −₹9,829. Promo minutes pay hosts with no revenue, and referrals invite fraud.
- **Paying hosts 50% more per Diamond:** −₹38,017, and only +₹51 per host per month while utilisation is 4.6%.

The conservative-case ranking is different. In order:
1. stop ads (+₹1,05,025 over six months);
2. founder covers safety on-call (+₹90,000);
3. cheap OTP (+₹47,096);
4. match hosts to demand (+₹5,625);
5. first-call conversion (+₹3,315).

When demand is weak, **cost discipline matters more than conversion work.**

---

## 1. Make the first call convert

- **What:** this is the acquisition engine. Every free call costs ₹10 to the host plus SMS and moderation. Changes to make:
  - Route free calls only to verified, highly rated hosts who are opted in (`free_call_opt_in`).
  - At the end of the free minute, show a one-tap Starter (₹99) offer with the host still on screen.
  - Build the in-call top-up deferred in D-10.
  - Show the "≈ ₹x/min" price clearly before the first paid call (D-07 is already implemented).
- **Impact:** +₹1.20 L over six months, +₹30,083 in Month 6, and capital need −₹15,049.
- **Cost:** about 3–4 weeks of engineering (Play purchase flow already exists); no running cost.
- **Dependencies:** host quality signal (post-call rating is out of the MVP, D-11), so start with moderator-curated free-call hosts.
- **Risk:** low. Avoid dark patterns; Play's billing and UGC policies apply.
- **Measure:** free-call starts, completions over 60 s, first purchase within 7 days, by host.

## 2. Decide the level rate ladder

- **What:** `LevelRateCaps` is `nil`, so every host may charge 500–10,000 D/min today. Both other outcomes are bad: new hosts underprice at the 500 default (₹11/min to the customer, ₹1.50 to the host), or overprice and get no calls. Define caps per level (D-16) and a sensible default for new hosts, such as 1,000–1,500 D/min.
- **Impact:** +₹41,696 over six months at +33% average rate, assuming a 0.6 rate elasticity. Hosts also earn more per minute.
- **Cost:** a new rule-set version plus copy; days.
- **Risk:** customers are more price-sensitive than assumed. Test with one cohort first.

## 3. No paid acquisition until the numbers say so

- **What:** set the marketing budget to ₹0. Grow through host communities, word of mouth, and app-store listing quality. Restart ads only when the measured **LTV per verified registration ≥ 3 × CAC**. In the base case that means CAC ≤ ₹7.9; the absolute ceiling is ₹23.8.
- **Impact:**
  - six-month loss falls from ₹1.70 L to ₹1.01 L;
  - break-even moves to **Month 4** at ~119 active payers;
  - capital need falls by ₹26,944.
- **Risk:** slower growth, and organic sign-ups are themselves an estimate (1,200 in Month 1).
- **Gate to restart ads:** see "Before spending on customer acquisition" below.

## 4. Keep safety cover in-house for now

- **What:** the IT Rules require a grievance officer and fast takedowns. The founder can be that contact while volume is small; hire once revenue covers it.
- **Impact:** +₹60,000 over six months.
- **Risk:** this does **not** remove the obligation, and response times are a legal duty. Keep a documented rota and escalation path. Do not cut moderation itself: the Sightengine frames and the missing-frames review stay.

## 5. Cheap OTP SMS

- **What:** Supabase phone auth offers Twilio, MessageBird, Vonage and Textlocal. Twilio India lists **$0.0832 (≈ ₹7.4) per SMS**. An Indian DLT-registered gateway behind Supabase's Send-SMS hook is typically far cheaper (get quotes; ₹0.2–0.3 assumed). Keep OTP rate limits; phone-only sign-in in production (`config.toml` still enables email).
- **Impact:** +₹36,905 over six months at ₹0.3 vs ₹2.5. Against Twilio pricing it saves about ₹80,000.
- **Cost:** DLT template registration; one auth hook.
- **Risk:** delivery reliability. Monitor OTP success rate.

---

## Host marketplace health (not ranked by profit; needed for survival)

| Action | Why | Effect in the model |
|---|---|---|
| **Match host intake to demand.** About 10–15 hosts until ~300 active payers; approve new hosts only when utilisation is above ~15% | Hosts earn ₹692/month (₹15 per online hour) at 4.6% utilisation and cannot withdraw. They will leave | Halving intake: **+₹556/host/month**, +₹5,000 platform |
| **Choose a payout provider and incorporate before Month 4** | Base: ₹1.30 L owed to hosts by Month 6; optimistic: ₹9.07 L. In 9 of the 26 stress tests, cash is less than what is owed | Recommended capital includes the full host liability |
| **Revisit the Bean rule once utilisation is above 15%** | Hosts get 13.5% of the customer price; the repo's earlier research (unverified) suggests competitors pay ~76% more per Bean | +10% host share costs ~1.6 points of gross margin |
| **Reward hosts for retained callers** (capped Bean bonus) | Pays for the behaviour that lowers payer churn | Not modelled separately |

## Before spending on customer acquisition

1. **Run a measured organic cohort.** Take the first ~1,000 verified sign-ups and measure:
   - free-call start rate;
   - completion past 60 s;
   - first-purchase rate within 7 days;
   - payer month-2 retention;
   - paid minutes per payer.

   These five numbers replace the five most uncertain assumptions in the model. Enter them in the simulator.
2. **Fix the per-user costs** that scale with sign-ups:
   - choose the SMS provider (≤ ₹0.5/SMS);
   - confirm the Sightengine plan;
   - confirm the Play fee in Play Console for India.
3. **Get a CA to confirm:**
   - who remits GST on Play sales;
   - the Play fee base;
   - Diamond revenue recognition and breakage;
   - TDS on host payouts.
4. **Get a policy review** of the app against Google Play's UGC and sexual-content policies (the Free Call Card is random matching). Consider a separate developer account and legal entity.
5. **Set the restart rule for ads:** spend only when measured LTV per verified registration ≥ 3 × the CAC quoted by the channel. Start with ≤ ₹10,000 a month and stop on a two-week payback miss.

## Dependencies and timeline

| Weeks | Work |
|---|---|
| 0–2 | SMS provider (DLT); Play fee/GST questions to the CA; rate ladder decision; ads off |
| 2–6 | First-call conversion work (curated free-call hosts, end-of-minute offer, in-call top-up); `firebase_messaging` for re-engagement |
| 4–10 | Organic cohort measurement; incorporation; payout-provider shortlist and written approval; legal review of terms and host agreement |
| 10+ | Revisit the Bean rule and packages with real data; restart ads only through the gate above |
