# Dashuri — Sensitivity and break-even analysis

- **Generated:** 2026-11-17 by `simulation/scripts/generate-reports.mjs` from the simulation engine (same code as the dashboard).
- **Status:** conditional what-if scenarios, **not forecasts**. Demand inputs have no market data behind them.
- **Runs:** five seeds per scenario (Worst 1101, 1102, 1103, 1104, 1105; Base 2201, 2202, 2203, 2204, 2205; Best 3301, 3302, 3303, 3304, 3305). Figures are means of the five runs unless stated.

One input changes at a time; everything else stays at the scenario setting. Metric: six-month profit after acquisition (equal to operating profit before acquisition when CAC is ₹0, the default). Ranked by swing.

## Worst case (scenario result −₹3,16,456)

| Variable | Who controls it | Low setting | Profit | High setting | Profit | Swing |
|---|---:|---:|---:|---:|---:|---:|
| Acquisition cost per install | Founder / market | ₹0 | −₹3,16,456 | ₹15 (what-if) | −₹5,98,336 | ₹2,81,880 |
| Moderation cost | Founder (vendor) | High | −₹3,60,581 | Low | −₹2,12,331 | ₹1,48,250 |
| Fixed infrastructure | Founder | High | −₹3,59,776 | Low | −₹3,01,396 | ₹58,380 |
| Installs (paying-customer volume) | Founder | −50% | −₹3,01,765 | +50% | −₹3,34,284 | ₹32,519 |
| Average top-up (package mix) | Pricing | Small-pack heavy | −₹3,21,479 | Large-pack heavy | −₹2,96,190 | ₹25,289 |
| Refund & fraud rate | Partly founder | ×2 | −₹3,25,650 | ×0.5 | −₹3,14,977 | ₹10,673 |
| Monthly repeat purchase rate | Product | −10 pts | −₹3,21,992 | +10 pts | −₹3,15,961 | ₹6,031 |
| Diamonds consumed (wallet burn) | Product | −50% | −₹3,20,872 | +50% | −₹3,15,128 | ₹5,744 |
| Google Play fee | External | 15% | −₹3,16,456 | 30% | −₹3,21,789 | ₹5,333 |
| Host rate ladder | Founder | C narrow | −₹3,19,191 | B fast | −₹3,14,017 | ₹5,174 |
| Top-ups per payer per month | Product | −0.3 | −₹3,19,942 | +0.3 | −₹3,15,008 | ₹4,934 |
| Host availability (utilisation) | Hosts | −40% | −₹3,16,665 | +30% | −₹3,21,233 | ₹4,568 |
| Host payout conversion (Bean value) | Founder | ₹0.006 | −₹3,18,211 | ₹0.004 | −₹3,14,818 | ₹3,393 |
| Average paid call length | Product | −40% | −₹3,16,612 | +40% | −₹3,15,061 | ₹1,551 |
| GST treatment | External (CA) | Principal | −₹3,16,456 | Agent (hyp.) | −₹3,15,598 | ₹857 |
| Free-to-paid conversion | Product | −50% | −₹3,19,507 | +50% | −₹3,19,055 | ₹452 |
| Video price | External | SD $0.75 | −₹3,16,456 | Full HD $3.00 | −₹3,16,456 | ₹0 |

## Base case (scenario result −₹1,19,958)

| Variable | Who controls it | Low setting | Profit | High setting | Profit | Swing |
|---|---:|---:|---:|---:|---:|---:|
| Acquisition cost per install | Founder / market | ₹0 | −₹1,19,958 | ₹15 (what-if) | −₹8,64,273 | ₹7,44,315 |
| Average top-up (package mix) | Pricing | Small-pack heavy | −₹2,65,552 | Large-pack heavy | ₹61,009 | ₹3,26,561 |
| Moderation cost | Founder (vendor) | High | −₹2,84,951 | Low | −₹44,962 | ₹2,39,989 |
| Free-to-paid conversion | Product | −50% | −₹1,97,783 | +50% | −₹16,420 | ₹1,81,363 |
| Top-ups per payer per month | Product | −0.3 | −₹1,83,885 | +0.3 | −₹38,406 | ₹1,45,480 |
| Installs (paying-customer volume) | Founder | −50% | −₹1,90,428 | +50% | −₹66,031 | ₹1,24,397 |
| Monthly repeat purchase rate | Product | −10 pts | −₹1,63,882 | +10 pts | −₹48,428 | ₹1,15,454 |
| Diamonds consumed (wallet burn) | Product | −50% | −₹1,69,537 | +50% | −₹89,071 | ₹80,466 |
| Google Play fee | External | 15% | −₹1,19,958 | 30% | −₹1,89,869 | ₹69,911 |
| Fixed infrastructure | Founder | High | −₹1,63,278 | Low | −₹1,04,898 | ₹58,380 |
| Host rate ladder | Founder | C narrow | −₹1,41,069 | B fast | −₹1,07,458 | ₹33,611 |
| Refund & fraud rate | Partly founder | ×2 | −₹1,49,282 | ×0.5 | −₹1,24,449 | ₹24,833 |
| Average paid call length | Product | −40% | −₹1,29,456 | +40% | −₹1,14,585 | ₹14,870 |
| GST treatment | External (CA) | Principal | −₹1,19,958 | Agent (hyp.) | −₹1,08,599 | ₹11,359 |
| Host payout conversion (Bean value) | Founder | ₹0.006 | −₹1,24,366 | ₹0.004 | −₹1,14,821 | ₹9,546 |
| Host availability (utilisation) | Hosts | −40% | −₹1,19,692 | +30% | −₹1,27,126 | ₹7,434 |
| Video price | External | SD $0.75 | −₹1,19,958 | Full HD $3.00 | −₹1,19,958 | ₹0 |

## Best case (scenario result ₹19,77,447)

| Variable | Who controls it | Low setting | Profit | High setting | Profit | Swing |
|---|---:|---:|---:|---:|---:|---:|
| Average top-up (package mix) | Pricing | Small-pack heavy | ₹3,01,247 | Large-pack heavy | ₹29,42,746 | ₹26,41,499 |
| Installs (paying-customer volume) | Founder | −50% | ₹8,60,756 | +50% | ₹32,10,675 | ₹23,49,919 |
| Free-to-paid conversion | Product | −50% | ₹9,31,841 | +50% | ₹31,23,676 | ₹21,91,835 |
| Acquisition cost per install | Founder / market | ₹0 | ₹19,77,447 | ₹15 (what-if) | ₹9,261 | ₹19,68,186 |
| Monthly repeat purchase rate | Product | −10 pts | ₹14,07,280 | +10 pts | ₹26,48,037 | ₹12,40,757 |
| Top-ups per payer per month | Product | −0.3 | ₹13,97,910 | +0.3 | ₹25,50,880 | ₹11,52,969 |
| Diamonds consumed (wallet burn) | Product | −50% | ₹14,99,728 | +50% | ₹22,20,796 | ₹7,21,068 |
| Google Play fee | External | 15% | ₹19,77,447 | 30% | ₹13,31,312 | ₹6,46,135 |
| Moderation cost | Founder (vendor) | High | ₹16,18,697 | Low | ₹21,68,698 | ₹5,50,001 |
| Host payout conversion (Bean value) | Founder | ₹0.006 | ₹18,43,720 | ₹0.004 | ₹21,90,425 | ₹3,46,705 |
| Refund & fraud rate | Partly founder | ×2 | ₹18,48,167 | ×0.5 | ₹19,72,550 | ₹1,24,384 |
| GST treatment | External (CA) | Principal | ₹19,77,447 | Agent (hyp.) | ₹20,83,271 | ₹1,05,824 |
| Host availability (utilisation) | Hosts | −40% | ₹19,58,560 | +30% | ₹20,50,737 | ₹92,177 |
| Average paid call length | Product | −40% | ₹19,29,296 | +40% | ₹19,98,084 | ₹68,787 |
| Fixed infrastructure | Founder | High | ₹19,34,127 | Low | ₹19,92,507 | ₹58,380 |
| Host rate ladder | Founder | C narrow | ₹19,25,567 | B fast | ₹19,76,381 | ₹50,814 |
| Video price | External | SD $0.75 | ₹19,80,195 | Full HD $3.00 | ₹19,51,414 | ₹28,782 |

## Break-even (from Month 6 of each run)

Fixed monthly cost = Free Call Card cost + operating expenses in Month 6. Break-even paid minutes = fixed cost ÷ contribution per paid minute.

| Scenario | Contribution / paid min | Fixed monthly cost | Break-even paid minutes / month | Actual M6 paid minutes | Break-even paying customers | Break-even paid calls / day | Break-even monthly revenue | Runs reaching monthly break-even |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Worst case | ₹7.17 | ₹42,201 | 18,853 | 470 | 1,791 | 209.5 | ₹3,27,028 | 0/5 |
| Base case | ₹18.45 | ₹64,378 | 3,503 | 4,467 | 294 | 25.9 | ₹1,04,445 | 5/5 |
| Best case | ₹37.25 | ₹2,18,341 | 5,861 | 26,561 | 584 | 32.6 | ₹3,35,474 | 5/5 |

## Break-even acquisition cost

Maximum average cost per install at which six-month operating profit would be zero (operating profit before acquisition ÷ installs):

| Scenario | Break-even CAC per install | Range across runs |
|---|---:|---:|
| Worst case | −₹16.90 | −₹18.05 to −₹15.47 |
| Base case | −₹2.41 | −₹3.02 to −₹1.58 |
| Best case | ₹15.06 | ₹13.76 to ₹16.19 |

No CAC data exists for this category in India; these are thresholds to compare against real campaign costs, not estimates of CAC.
