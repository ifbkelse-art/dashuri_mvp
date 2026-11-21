# Dashuri simulation — automated test results

- **Run:** 2026-11-17 12:42 UTC with Node v24.3.0
- **Command:** `cd simulation && npm test`

```
✔ 16,670 Diamonds spent = 10,000 Beans (exact, founder decision) (0.393625ms)
✔ 10,000 Beans = ₹50 at ₹0.005 per Bean (0.060625ms)
✔ ₹500 minimum withdrawal = 100,000 Beans (0.04025ms)
✔ per-second billing at 4,000 D/min matches founder examples, rounded in customer favour (0.054792ms)
✔ paused seconds are not billable; failed connection costs nothing (0.047666ms)
✔ GST contained in a GST-inclusive price (0.053833ms)
✔ Play fee on net-of-GST vs gross base (0.0555ms)
✔ agent-model GST applies only to the margin above host share (0.043791ms)
✔ ₹1,199 pack waterfall reconciles line by line (0.131875ms)
✔ break-even returns no result when contribution per minute is not positive (0.095792ms)
✔ XP formula and levels (0.055083ms)
✔ rate ladders stay inside founder 500–10,000 range (0.060416ms)
✔ contribution per minute is consistent with the package waterfall (no reserve, no moderation) (0.059083ms)
✔ deterministic: same seed and inputs give identical results (16.127708ms)
✔ different seeds give different results (12.582542ms)
✔ worst: Diamond wallet reconciles (purchased − refunded − consumed = closing wallet) (2.650417ms)
✔ worst: Bean ledger reconciles (earned − clawed back − withdrawn = held + available) (2.609792ms)
✔ worst: revenue never exceeds top-ups net of GST (no recognising unspent Diamonds) (1.738125ms)
✔ worst: monthly P&L lines add up (no double counting) (1.608416ms)
✔ worst: cash balance equals the sum of daily cash movements (1.047959ms)
✔ base: Diamond wallet reconciles (purchased − refunded − consumed = closing wallet) (2.601167ms)
✔ base: Bean ledger reconciles (earned − clawed back − withdrawn = held + available) (2.637083ms)
✔ base: revenue never exceeds top-ups net of GST (no recognising unspent Diamonds) (2.5825ms)
✔ base: monthly P&L lines add up (no double counting) (2.46425ms)
✔ base: cash balance equals the sum of daily cash movements (2.40775ms)
✔ best: Diamond wallet reconciles (purchased − refunded − consumed = closing wallet) (6.447666ms)
✔ best: Bean ledger reconciles (earned − clawed back − withdrawn = held + available) (12.640125ms)
✔ best: revenue never exceeds top-ups net of GST (no recognising unspent Diamonds) (12.223625ms)
✔ best: monthly P&L lines add up (no double counting) (12.392917ms)
✔ best: cash balance equals the sum of daily cash movements (10.049542ms)
✔ free-call host cost is ₹10 per completed free call and capped at 20 per host per day (2.458ms)
✔ host payouts happen only on weekly days and respect the ₹500 minimum (2.428541ms)
✔ Google settlement for Month 1 arrives on day 15 of Month 2 plus transit (5.498917ms)
✔ Google-remits GST mode: no GST cash out; Dashuri mode: GST paid on top-ups (11.14675ms)
✔ higher Play fee lowers six-month operating profit (31.11225ms)
✔ stats helper (0.052209ms)
✔ five seeds per scenario (0.046125ms)
ℹ tests 37
ℹ suites 0
ℹ pass 37
ℹ fail 0
ℹ cancelled 0
ℹ skipped 0
ℹ todo 0
ℹ duration_ms 196.704
```
