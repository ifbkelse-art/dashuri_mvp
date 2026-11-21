# Dashuri — Cash flow and working capital

- **Generated:** 2026-11-17 by `simulation/scripts/generate-reports.mjs` from the simulation engine (same code as the dashboard).
- **Status:** conditional what-if scenarios, **not forecasts**. Demand inputs have no market data behind them.
- **Runs:** five seeds per scenario (Worst 1101, 1102, 1103, 1104, 1105; Base 2201, 2202, 2203, 2204, 2205; Best 3301, 3302, 3303, 3304, 3305). Figures are means of the five runs unless stated.

## Settlement assumptions

- Google Play pays a month's sales from **day 15 of the next month** ([official payout schedule](https://support.google.com/paymentscenter/answer/7159355), verified 2026-11-17), plus **5 days** bank transit (official: EFT 2–3, wire 5–7 business days). First settlement lands on day 50.
- Settlement = top-ups − refunds − Play fee − chargebacks (and − GST if Google remits).
- GST paid by Dashuri on the 20th of the next month on that month's top-ups (principal, Dashuri remits; switchable). **Who remits GST on Play sales is unresolved (CA).**
- Hosts: Beans held 7 days, weekly payouts, ₹500 minimum, ₹8 transfer fee (**UNVERIFIED**; no provider has accepted Dashuri).
- Chargebacks land 15–60 days after purchase and are deducted from the next settlement with a ₹1,500 bank fee each (**UNVERIFIED**, third-party reports of US$15–25 for orders after 3 Aug 2026).
- Starting cash ₹0, so the lowest balance is the founder funding required. Pre-launch placeholder ₹1,00,000 paid on day 1.

## Peak cash requirement and reserve

| Scenario | Peak requirement (mean) | Lowest run | Highest run | Reserve (worst run +10%) | Cash at day 180 | Google receivable at day 180 | Customer wallet liability M6 | Host liability M6 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Worst case | ₹3,01,766 | ₹2,89,022 | ₹3,18,675 | ₹3,50,542 | −₹3,01,766 | ₹9,214 | ₹15,794 | ₹10,707 |
| Base case | ₹1,96,707 | ₹1,87,154 | ₹2,08,162 | ₹2,28,978 | −₹1,22,833 | ₹1,62,269 | ₹1,31,704 | ₹35,431 |
| Best case | ₹2,48,410 | ₹2,30,530 | ₹2,66,479 | ₹2,93,127 | ₹14,28,255 | ₹17,92,716 | ₹10,10,651 | ₹1,97,347 |

## Worst case: monthly cash

| ₹ | M1 | M2 | M3 | M4 | M5 | M6 |
|---|---:|---:|---:|---:|---:|---:|
| Google settlements in | ₹0 | ₹4,358 | ₹6,587 | ₹3,541 | ₹7,229 | ₹15,281 |
| Host payouts + fees out | −₹2,090 | −₹3,543 | −₹4,188 | −₹7,648 | −₹5,328 | −₹6,232 |
| GST out | ₹0 | −₹762 | −₹1,151 | −₹776 | −₹1,525 | −₹2,775 |
| Operating out | −₹32,638 | −₹33,064 | −₹33,262 | −₹34,213 | −₹34,564 | −₹35,002 |
| Pre-launch out | −₹1,00,000 | ₹0 | ₹0 | ₹0 | ₹0 | ₹0 |
| Net movement | −₹1,34,728 | −₹33,011 | −₹32,015 | −₹39,096 | −₹34,188 | −₹28,727 |
| **Closing balance** | **−₹1,34,728** | **−₹1,67,739** | **−₹1,99,754** | **−₹2,38,850** | **−₹2,73,039** | **−₹3,01,766** |
| Lowest balance in month | −₹1,34,728 | −₹1,67,739 | −₹1,99,754 | −₹2,38,850 | −₹2,73,039 | −₹3,01,766 |
| *Operating profit (accrual)* | *−₹1,34,531* | *−₹34,520* | *−₹37,289* | *−₹37,678* | *−₹33,725* | *−₹38,714* |

## Base case: monthly cash

| ₹ | M1 | M2 | M3 | M4 | M5 | M6 |
|---|---:|---:|---:|---:|---:|---:|
| Google settlements in | ₹0 | ₹17,617 | ₹68,655 | ₹91,029 | ₹1,08,049 | ₹1,25,499 |
| Host payouts + fees out | −₹9,285 | −₹16,927 | −₹27,453 | −₹38,484 | −₹39,458 | −₹45,123 |
| GST out | ₹0 | −₹3,079 | −₹12,208 | −₹16,485 | −₹19,826 | −₹23,295 |
| Operating out | −₹25,581 | −₹27,996 | −₹29,564 | −₹30,663 | −₹33,012 | −₹35,246 |
| Pre-launch out | −₹1,00,000 | ₹0 | ₹0 | ₹0 | ₹0 | ₹0 |
| Net movement | −₹1,34,866 | −₹30,385 | −₹568 | ₹5,398 | ₹15,753 | ₹21,834 |
| **Closing balance** | **−₹1,34,866** | **−₹1,65,250** | **−₹1,65,819** | **−₹1,60,420** | **−₹1,44,667** | **−₹1,22,833** |
| Lowest balance in month | −₹1,34,866 | −₹1,65,250 | −₹1,85,734 | −₹1,87,402 | −₹1,77,667 | −₹1,75,116 |
| *Operating profit (accrual)* | *−₹1,32,318* | *−₹12,297* | *−₹1,412* | *₹1,743* | *₹6,281* | *₹18,045* |

## Best case: monthly cash

| ₹ | M1 | M2 | M3 | M4 | M5 | M6 |
|---|---:|---:|---:|---:|---:|---:|
| Google settlements in | ₹0 | ₹1,36,895 | ₹4,38,847 | ₹6,92,289 | ₹9,64,781 | ₹12,25,945 |
| Host payouts + fees out | −₹28,067 | −₹76,868 | −₹1,18,584 | −₹2,17,192 | −₹2,33,108 | −₹3,19,440 |
| GST out | ₹0 | −₹23,923 | −₹76,901 | −₹1,22,031 | −₹1,70,700 | −₹2,17,808 |
| Operating out | −₹33,373 | −₹40,836 | −₹46,789 | −₹55,696 | −₹64,334 | −₹84,852 |
| Pre-launch out | −₹1,00,000 | ₹0 | ₹0 | ₹0 | ₹0 | ₹0 |
| Net movement | −₹1,61,440 | −₹4,733 | ₹1,96,573 | ₹2,97,370 | ₹4,96,640 | ₹6,03,845 |
| **Closing balance** | **−₹1,61,440** | **−₹1,66,173** | **₹30,400** | **₹3,27,770** | **₹8,24,410** | **₹14,28,255** |
| Lowest balance in month | −₹1,61,440 | −₹2,13,158 | −₹2,48,410 | −₹83,199 | ₹2,23,676 | ₹5,97,026 |
| *Operating profit (accrual)* | *−₹1,13,622* | *₹1,39,210* | *₹2,70,760* | *₹3,90,049* | *₹5,20,063* | *₹7,70,988* |

Cash lags profit because Google pays about 45–55 days after a purchase while GST and hosts are paid sooner. A profitable month can still leave the bank balance falling.
