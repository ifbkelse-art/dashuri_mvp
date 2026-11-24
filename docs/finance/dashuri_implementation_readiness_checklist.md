# Dashuri monetization: implementation readiness checklist

**Date:** 24 Nov 2026 · **Rule:** a phase starts only when every item of the previous phase meets its acceptance criterion. ☐ = not done.

**State on 24 Nov 2026:**
- Only "5:4 approved for modelling" is done.
- Everything else is ☐.
- Payments and payouts are disabled.
- Nothing is implemented.

## 1. Founder decisions

| ☐ | Item | Acceptance criterion |
|---|---|---|
| ☑ | 5 D → 4 B at ₹0.005 approved for modelling | Recorded 24 Nov 2026 |
| ☐ | 5:4 approved for **implementation** | Written founder approval naming the rule-set version and effective date. *24 Nov: founder kept it modelling-only* |
| ☑ | Fractional carry, clawback order and 90-day write-off, Free Call Card off, 14/7-day hold with conditions, weekly withdrawals (Dashuri pays fee), reserve with refund cushion, no promos at launch, payout hold at submission, split levels with caller gates, caller "your price" display, default rate 1,000 D/min, Diamond lots + price snapshot, idempotency fingerprint, Supabase Pro at launch, DLT SMS route, Cloud Run min 0, lean budget, deletion unchanged pending legal advice, advisers engaged | Register A-5…A-24 (24 Nov 2026); policy and design only, not implementation |
| ☐ | Carry, reversal recovery order, receivable write-off period (D-01…D-04 in the register) | Each decision recorded with date in the register |
| ☐ | Promo policy, Free Call Card, Account XP / Host Level, gates, holds, withdrawals, reserve, caller display | Each register item set to Approved or Rejected; none left Proposed |
| ☐ | Paid services (Supabase Pro, SMS provider, payout provider, Sightengine plan) | Explicit yes per service with monthly cost shown |

## 2. Accounting design approval

| ☐ | Item | Acceptance criterion |
|---|---|---|
| ☐ | CA reviews the chart of accounts and INR journal (spec §2, §5) | Signed note: principal/agent, GST timing, revenue recognition, breakage, chargeback treatment |
| ☐ | Tax treatment of host payouts | CA names the TDS section/rate and the GST TCS position |
| ☐ | Refund/chargeback reserve horizon | CA + Play documentation give the dispute window used in the reserve |

## 3. Database design approval

| ☐ | Item | Acceptance criterion |
|---|---|---|
| ☐ | DDL review (spec §3, §6) | Reviewed migration file in a PR; `scripts/validate-migrations.sh` passes; RLS and grants match the existing pattern |
| ☐ | Lock order and transaction boundaries (spec §7) | Reviewer confirms each operation's lock list; no operation takes locks out of order |
| ☐ | Backfill plan (spec §13) | Dry run on a staging copy: rebuilt lots and holds reconcile exactly; second run is a no-op |

## 4. Backend implementation

| ☐ | Item | Acceptance criterion |
|---|---|---|
| ☐ | Fingerprinted `PostEntry` | Same key + different payload returns `ErrIdempotencyConflict`; integration test |
| ☐ | Lots, funding, carry, holds | 5:4 identity asserted in code and in reconciliation |
| ☐ | `CallReversal` + lot-based chargeback + host clawback | Every reversal test in spec §12.2 passes |
| ☐ | Receivable, offset, withdrawal block, payout hold at submission | Integration tests for each |
| ☐ | XP / Host Level (if approved) | Edge-case tests in spec §10 pass; price capped on a level drop |
| ☐ | "Your price" endpoint (if approved) | Values from caller's lots in spend order; free Diamonds labelled; server-only |

## 5. Integration testing

| ☐ | Item | Acceptance criterion |
|---|---|---|
| ☐ | Real PostgreSQL concurrency suite (multiple connections) | All spec §12.2 cases pass 25 consecutive runs; no deadlocks logged |
| ☐ | Existing suites | `go test ./...` and `scripts/test-backend-integration.sh ./...` pass (run with `LANG`/`LC_ALL` set) |
| ☐ | Randomised invariant test | ≥ 10⁴ random operations; reconciliation empty after each batch |

## 6. Payment verification

| ☐ | Item | Acceptance criterion |
|---|---|---|
| ☐ | Play Console evidence | Screenshot of 15%-tier enrolment and a test purchase's fee line |
| ☐ | Play licence-tester purchases end to end | Credit once; RTDN replay is a no-op; voided purchase reverses unspent lot Diamonds and claws host Beans |
| ☐ | Play policy review | Written review against compensated-arrangement, UGC, sexual-content and Child Safety Standards policies; listing plan approved |

## 7. Financial reconciliation

| ☐ | Item | Acceptance criterion |
|---|---|---|
| ☐ | All spec §11 checks automated | Daily job green for 14 consecutive days in staging |
| ☐ | Play earnings report vs credited purchases | Zero unexplained differences over a test month |
| ☐ | Reserve calculation | Finance view shows the reserve formula components and cash ≥ reserve |

## 8. Compliance verification

| ☐ | Item | Acceptance criterion |
|---|---|---|
| ☐ | Consumer protection (E-Commerce Rules, Dark Patterns Guidelines) | Lawyer sign-off on price display, promo expiry, refund policy, deletion terms |
| ☐ | RBI/PPI framing | Lawyer sign-off |
| ☐ | DPDP notices and retention; IT Rules grievance officer | Published notices; named grievance officer; retention schedule |
| ☐ | Host agreement | Signed template: earning rule, deductions, receivables, KYC |
| ☐ | Incorporation and payout KYC | Entity registered; payout provider onboarding complete |

## 9. Internal testing

| ☐ | Item | Acceptance criterion |
|---|---|---|
| ☐ | Staff-only money pilot (licence testers) | 50+ paid calls, 5 disputes, 2 chargebacks simulated; reconciliation clean; host statements correct by hand check |
| ☐ | Payout dry run (provider sandbox) | Duplicate and conflicting webhooks handled; failed payout returns Beans |

## 10. Production launch approval

| ☐ | Item | Acceptance criterion |
|---|---|---|
| ☐ | Founder go/no-go | Written approval listing: rule-set version, packs, reserve funded, payouts on/off, budget limits |
| ☐ | Monitoring | Alerts on reconciliation failure, idempotency conflicts, receivables, reserve shortfall |
| ☐ | Rollback plan rehearsed | New rule set can be activated; payouts can be switched off within minutes |
