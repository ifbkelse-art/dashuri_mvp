# Dashuri six-month financial simulation

An interactive what-if model of Dashuri's first six months: Diamond top-ups, paid calls, host Beans, the Free Call Card, Google Play settlement, GST, host payouts and cash. **Results are conditional scenarios, not forecasts.** Demand inputs (installs, conversion, retention, top-up mix) have no market data behind them and are labelled as hypotheses throughout.

This folder contains the simulation and analytics only. It is not the Dashuri app.

## Open the dashboard

Double-click `dist/dashuri-simulation.html`, or open it from a terminal:

```sh
open simulation/dist/dashuri-simulation.html      # macOS
```

It is a single self-contained file. It needs no server, install or internet; with internet it loads the IBM Plex fonts, and without it falls back to system fonts.

### What you can do

| Section | Use it to |
|---|---|
| Overview | See headline results, the verdict, cash balance and launch blockers |
| Scenario comparison | Compare Worst / Base / Best: mean, median, min, max and SD across 5 runs |
| Customers | View the registration and Free Call Card funnel, payers, top-ups, package mix and customer value |
| Hosts | View utilisation, rates, Beans, payouts, the earnings distribution, levels and the rate ladder |
| Wallets & liabilities | Track Diamonds purchased and consumed, Beans held, withdrawable and withdrawn, and the reconciliations |
| Unit economics | Adjust package, rate, GST treatment, Play fee, Bean value, video, reserve and moderation; the waterfall updates live |
| Cash flow | See the daily balance, monthly inflows and outflows, peak requirement and reserve |
| Sensitivity & break-even | Read the tornado chart, try live what-if sliders and use the break-even calculator |
| Business model report | Read the full `docs/business-model-report.md`, with evidence labels highlighted |
| Assumptions & method | See every input with its evidence status, sources, formulas, seeds, limitations and professional-review items |

- Use the **scenario switch** at the top to choose Worst, Base, Best or Compare.
- **Edit assumptions** changes any input for the selected scenario, including the rate ladder, GST treatment and packages. Then press *Apply and rerun*.
- **Export CSV** gives monthly projections (one or all scenarios), the scenario comparison and assumptions. Download works when the file is opened locally; Copy works everywhere.

## Rebuild, test, regenerate reports

Requires Node 18+ (tested on Node 24). There are no npm dependencies.

```sh
cd simulation
npm test           # 37 automated tests (formulas, reconciliations, settlement timing)
npm run report     # regenerate docs/simulation/*.md and data/*.csv
npm run build      # rebuild dist/ (also re-embeds docs/business-model-report.md)
```

Rebuild after editing `docs/business-model-report.md` so the dashboard shows the latest report.

## Structure

```
simulation/
  src/engine/assumptions.js  inputs, scenarios, sources, evidence labels, rate ladders
  src/engine/rng.js          seeded random numbers (deterministic)
  src/engine/finance.js      pure formulas: Beans, billing, GST, Play fee, waterfall, break-even, XP
  src/engine/simulate.js     daily simulation (180 days), accounting and cash timeline
  src/engine/runs.js         multi-seed runs, statistics, sensitivity
  src/engine/export.js       CSV builders
  src/ui/                    dashboard (SVG charts, Markdown renderer, app, template)
  scripts/build.mjs          bundles everything into dist/*.html
  scripts/generate-reports.mjs  writes docs/simulation/
  tests/                     node:test suites
  dist/dashuri-simulation.html  the dashboard (open this)
  dist/artifact.html         same dashboard without the document wrapper, for hosted publishing
```

## Accounting rules the engine enforces

- Top-ups are cash and a customer liability, **not revenue**. Revenue is recognised only when purchased Diamonds are spent in billable calls.
- The Play fee is deferred with the Diamonds and expensed as they are consumed.
- Host Beans are an expense and a liability when earned. Cash leaves only at weekly payouts (7-day hold, ₹500 minimum).
- Google pays a month's sales from day 15 of the next month, plus bank transit.
- Tests check that Diamonds purchased − refunded − consumed = closing wallet, that Beans earned − clawed back − withdrawn = held + withdrawable, that P&L lines add up, and that the cash balance equals the sum of daily movements.
