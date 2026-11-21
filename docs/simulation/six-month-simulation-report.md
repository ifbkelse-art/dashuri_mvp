# Dashuri — Six-month financial simulation report

- **Generated:** 2026-11-17 by `simulation/scripts/generate-reports.mjs` from the simulation engine (same code as the dashboard).
- **Status:** conditional what-if scenarios, **not forecasts**. Demand inputs have no market data behind them.
- **Runs:** five seeds per scenario (Worst 1101, 1102, 1103, 1104, 1105; Base 2201, 2202, 2203, 2204, 2205; Best 3301, 3302, 3303, 3304, 3305). Figures are means of the five runs unless stated.

## 1. Bottom line

|  | Worst case | Base case | Best case |
|---|---:|---:|---:|
| Six-month top-ups (cash in wallets, incl. GST) | ₹59,985 | ₹6,97,489 | ₹61,76,977 |
| Recognised revenue (ex GST) | ₹36,775 | ₹4,73,927 | ₹43,39,496 |
| Contribution, paid calls | ₹15,645 | ₹2,80,944 | ₹28,26,008 |
| **Six-month operating profit (before acquisition)** | **−₹3,16,456** | **−₹1,19,958** | **₹19,77,447** |
| Range across 5 runs | −₹3,28,997 to −₹3,04,726 | −₹1,52,088 to −₹77,041 | ₹17,64,823 to ₹22,44,554 |
| Month 6 operating profit | −₹38,714 | ₹18,045 | ₹7,70,988 |
| First month with operating profit | Not within six months (0/5 runs) | Month 3 to 6 (5/5 runs) | Month 2 (5/5 runs) |
| Peak cash requirement (mean / worst run) | ₹3,01,766 / ₹3,18,675 | ₹1,96,707 / ₹2,08,162 | ₹2,48,410 / ₹2,66,479 |
| Break-even CAC per install | −₹16.90 | −₹2.41 | ₹15.06 |
| Month 6 paying customers | 48 | 371 | 2,643 |
| Month 6 active hosts / utilisation | 18 / 6.6% | 42 / 11.2% | 90 / 21.1% |
| Month 6 median host earnings | ₹567 | ₹1,593 | ₹4,512 |

**Which scenario is viable?** Only the **Best case** produces a six-month operating profit (₹19,77,447) with room to pay for acquisition (up to ₹15.06 per install). The **Base case** turns monthly-profitable during the period (first profitable month: Month 3 to 6 (5/5 runs)) but ends six months at −₹1,19,958, mostly the ₹1,00,000 pre-launch placeholder, and its Month 6 profit (₹18,045) cannot fund paid acquisition. The **Worst case** never breaks even and loses ₹3,16,456.

**Peak capital requirement:** ₹3,18,675 in the worst single run of any scenario (plus 10% buffer: ₹3,50,542). This excludes any marketing budget, which the founder manages separately, and includes the ₹1,00,000 pre-launch placeholder.

## 2. What drives the result

1. **Demand is the business.** In every scenario hosts are idle most of the time (Month 6 utilisation Worst case 6.6%, Base case 11.2%, Best case 21.1%). Supply is not the constraint; paying customers are. Apart from any paid acquisition cost (the largest swing of all), the top Base-case drivers are package mix (average top-up), moderation cost, free-to-paid conversion, top-ups per payer and repeat purchases.
2. **Unit margin is high.** At the confirmed 16,670 D = 10,000 Beans = ₹50, hosts receive about 13.5% of what customers pay. A fully spent ₹1,199 pack at 4,000 D/min contributes ₹633.09 (52.8%). Contribution per paid minute in Month 6: Worst case ₹7.17, Base case ₹18.45, Best case ₹37.25.
3. **The Free Call Card is the largest host cost in the Base case.** Six-month free-call host compensation ₹1,35,208 vs paid-call host Beans ₹75,718. Each converted payer costs ₹199 in free calls at a 6% conversion rate. Each completed free call costs about ₹11.98; against six-month contribution of ₹268 per payer, the card only pays back if free-to-paid conversion is above about 4.5% (before operating costs).
4. **Host earnings are low.** Median Month 6 earnings per active host: Worst case ₹567, Base case ₹1,593, Best case ₹4,512. New hosts start at ladder maximums of 500–2,000 D/min, which pay ₹1.50–₹6 per talking minute. Third-party reports put competitor hosts at about 10,000 Beans per US$1 (~₹88); Dashuri's ₹50 per 10,000 Beans pays roughly 43% less per Bean. This is a supply-retention risk the model does not capture (host churn here does not react to earnings).
5. **Moderation is a material cost.** The founder's 3-minute nudity bot (6 frames/min on both streams) costs about ₹4.75 per Base-case call at an UNVERIFIED $0.0015 per frame, plus ₹15,000/month on-call safety cover (hypothesis). Moderation cost is the third-largest sensitivity driver in the Base case.
6. **Video is negligible at this scale.** Stream's $100 monthly free usage covers the Worst and Base cases entirely.
7. **Cash lags profit.** Google pays 45–55 days after purchase; GST and hosts are paid sooner. Month 6 sales (₹1,62,269 in Base) are still owed by Google at day 180.

## 3. Liabilities that are not Dashuri's money (Month 6, mean)

| Scenario | Unspent purchased Diamonds (customer liability, incl. GST) | Earned Beans not yet paid (host liability) |
|---|---:|---:|
| Worst case | ₹15,794 | ₹10,707 |
| Base case | ₹1,31,704 | ₹35,431 |
| Best case | ₹10,10,651 | ₹1,97,347 |

## 4. Largest risks

1. **No payout provider has accepted Dashuri.** Without one (or a lawyer-approved bank-transfer arrangement, modelled here only as a hypothetical ₹8/transfer), hosts cannot be paid.
2. **Publishing under the BK Enterprises Play account ties Route to Dashuri's policy risk.** Google can suspend a developer account for repeated or severe policy violations, which would affect every app on it, including Route. Chamet was removed from Play in 2023 under the UGC policy. Consider a separate developer account and legal entity for Dashuri (needs founder decision and review of Play's account rules).
3. **Moderation model compliance.** A bot only in the first three minutes, then reports, has not been shown to satisfy Google Play's Sexual Content/UGC policies or the IT Rules (2-hour takedown of intimate images on complaint after the 2026 amendment, reported). Explicit content after minute three is the exact risk that removed Chamet.
4. **Demand assumptions have no data.** Installs, conversion, retention and top-up mix drive the result and are all hypotheses.
5. **Host supply at these earnings.** Low earnings per online hour may not keep hosts online; the model holds host numbers as an input.
6. **GST and Play-fee treatment.** Switching to the Play fee on the GST-inclusive price or a 30% fee cuts contribution noticeably (see unit economics).
7. **Chargebacks after 3 Aug 2026 are reportedly borne by developers**, with bank fees per case (UNVERIFIED). Fraud through colluding accounts converts directly into cash losses.

## 5. Most important assumptions

| Assumption | Worst | Base | Best | Evidence |
|---|---:|---:|---:|---:|
| Installs in Month 1 / growth | 2,500 / 10% | 5,000 / 20% | 10,000 / 30% | Hypothesis |
| Free-to-paid conversion | 3.0% | 6.0% | 10.0% | Hypothesis |
| Repeat purchase rate per month | 25% | 35% | 45% | Hypothesis |
| Top-ups per active payer per month | 1.2 | 1.5 | 1.8 | Hypothesis |
| Package mix (Starter→Premium) | 40/30/15/10/4/1 | 30/30/20/12/6/2 | 25/28/22/14/8/3 | Hypothesis |
| Average paid call | 3 min | 4.5 min | 6 min | Hypothesis |
| Active hosts M1→M6 | 8→18 | 12→42 | 20→90 | Capacity input (founder recruits) |
| Chargebacks incl. fraud | 4.0% | 2.0% | 1.0% | Hypothesis |
| Rate ladder | A · Gradual | A · Gradual | A · Gradual | Proposal, not approved |
| Play fee / GST | 15% / principal | 15% / principal | 15% / principal | Verified rate / CA review |
| Pre-launch professional costs | ₹1,00,000 | ₹1,00,000 | ₹1,00,000 | Placeholder |

All inputs with evidence status: `data/assumptions.csv` and the dashboard's *Assumptions & method* page.

## 6. Requires professional review

- **CA:** GST principal vs agent; who remits GST on Play sales; Play fee base; GST timing on advances; TDS section for host payouts; accounting for Diamond and Bean liabilities.
- **Lawyer:** Bean payout structure (PPI / payment aggregator); IT Act s.67/67A and s.79; sufficiency of the 3-minute moderation model under the IT Rules 2026 amendment; DPDP; social-security levy applicability; host agreement.
- **Payments:** written acceptance from a payout provider.
- **Google Play:** whether Dashuri is in scope of the random-chat minor-blocking rules (Free Call Card), and the risk to the BK Enterprises account.

## 7. Files

- `monthly-projections.md`: month-by-month tables for all three scenarios
- `unit-economics.md`: package waterfalls, tax/fee alternatives, host earnings, Free Call Card
- `sensitivity-analysis.md`: tornado tables and break-even
- `cash-flow-working-capital.md`: settlement, payouts, peak funding
- `test-results.md`: automated test output
- `data/*.csv`: monthly projections, comparison, assumptions, sensitivity
- Interactive dashboard: `simulation/dist/dashuri-simulation.html`
