# Financial ledger design

Dashuri never stores a wallet as a mutable number that code edits. Every change to Diamonds, Beans or (later) rupee payouts is an **immutable, balanced journal entry**. Balances are a projection that only the posting trigger updates.

Code: `backend/internal/modules/ledger` and `economy`. Schema: `supabase/migrations/…_economy_and_ledger.sql`. Tests: `ledger_test.go`, `rules_test.go`, `supabase/tests/ledger_invariants.sql`.

## Currencies and accounts

| Account kind | Currency | Owner | Can go negative | Meaning |
|---|---|---|---|---|
| `diamond_purchased` | DIAMOND | customer | no | Unspent purchased Diamonds: **a liability to the customer**; never expires (S5) |
| `diamond_promotional` | DIAMOND | customer | no | Promotional Diamonds; expire after 30 days (S5) |
| `bean_held` | BEAN | host | no | Earned, within the 7-day hold |
| `bean_available` | BEAN | host | no | Withdrawable |
| `bean_payout_pending` | BEAN | host | no | In a payout cycle |
| `sys_diamond_issued_purchased` / `_promotional` | DIAMOND | system | yes | Source of Diamonds |
| `sys_diamond_consumed` / `_expired` / `_reversed` | DIAMOND | system | yes | Sinks |
| `sys_bean_issued` / `_paid_out` / `_clawed_back` | BEAN | system | yes | Source and sinks of Beans |

Diamonds and Beans are separate currencies: a Diamond debit can never balance a Bean credit (tested). There is no account that converts one into the other. The conversion happens in the settlement template by rule.

## Business rules (configurable, versioned)

`economy.Rules`, stored in `economy.rule_sets`. Every journal entry records `rule_set_version`.

| Rule | Value | Status |
|---|---|---|
| Earning ratio | 10,000 Beans per 16,670 Diamonds spent | Founder (S3) |
| Bean value | ₹0.005 = ½ paisa | Founder (S3) |
| Host rate | 500–10,000 D/min; level cap ladder | Range founder (S2); ladder **UNRESOLVED** |
| XP | 8 × Diamonds purchased + 1 × Beans earned | Founder (R3-3) |
| Level thresholds | 0 / 32k / 100k / … / 40M | **Proposal (P12), UNRESOLVED** |
| Hold / minimum withdrawal | 7 days / ₹500 (100,000 Beans) | Founder |
| Promo expiry | 30 days | Founder (S5) |
| Start balance / warning | 60 s / 30 s at the call rate | Founder (S6) |
| Free call | 60 s, ₹10 (2,000 Beans) to host, max 20 per host per day | Founder (S4) |
| Interruption threshold | 10 s | **Technical assumption** |
| Spend order (promo vs purchased first) | promotional_first | **UNRESOLVED** (affects revenue recognition; CA question) |
| Beans on promotional Diamonds | earned on all Diamonds spent | **UNRESOLVED** |
| Rounding residue | Beans rounded down per call; remainder credited to no one | **UNRESOLVED** |

## Rounding

- **Diamonds charged** = ⌊rate × billable seconds ÷ 60⌋, computed **once** at settlement (customer's favour). Example: 65 s at 4,000/min = 4,333.
- **Beans** = ⌊Diamonds charged × 10,000 ÷ 16,670⌋, once per call, never per second, so floors cannot accumulate. Example: 4,333 D → 2,599 Beans.
- **Paise for Beans** = ⌊Beans ÷ 2⌋.
- Integer arithmetic only, with an overflow guard.

## Entry templates (the only way to post)

| Template | Postings | Idempotency key |
|---|---|---|
| `PurchaseCredit` | issued_purchased −D; user purchased +D | `purchase_credit:<token hash>` |
| `CallSettlement` | user promo −x, user purchased −(D−x), consumed +D; bean_issued −B, host bean_held +B | `call_settlement:<call id>` |
| `FreeCallCompensation` | bean_issued −2,000; host bean_held +2,000 | `free_call_comp:<free call id>` |
| `BeanRelease` | bean_held −B; bean_available +B | `bean_release:<source entry>` |
| `WithdrawalRequested` | bean_available −B; payout_pending +B | `withdrawal:<id>` |
| `PayoutSettled` (paid) | payout_pending −B; paid_out +B | `payout_paid:<id>` |
| `PayoutSettled` (failed) | payout_pending −B; bean_available +B | `payout_failed:<id>` |
| `PromoExpiry` | user promo −x; expired +x | `promo_expiry:<grant>` |
| `PurchaseReversal` | user purchased −unspent; reversed +unspent | `purchase_reversal:<purchase>` |
| `BeanClawback` | host bean_held −B; clawed_back +B | `bean_clawback:<case>` |
| Adjustment | proposal + second approver → entry | `adjustment:<proposal>` |

## Reservations (concurrent call billing)

Spending happens at settlement, but a call must not start, or keep running, on Diamonds already committed elsewhere.

- `ledger.diamond_reservations` holds an amount per active call; at most one active reservation per user (partial unique index), alongside one live call per person.
- **available = purchased + promotional − active reservations.**
- At call request: lock the customer's balance rows (`SELECT … FOR UPDATE`, ascending account id), check `CanStartCall` (60 s), and insert a reservation for the first window (e.g. 120 s).
- While the call is active, the webhook handler or ticker extends the reservation in windows if the balance allows, sends `call.low_balance` 30 s before exhaustion, and ends the call at zero.
- At settlement, in **one transaction**: lock balances, compute the charge (capped at the reservation), post `CallSettlement`, insert `calls.settlements`, and mark the reservation settled. Any retry hits the unique keys and becomes a no-op.

## Operations that need locking or atomic updates

| Operation | Locks / atomicity |
|---|---|
| Call request (reserve) | Customer Diamond balance rows FOR UPDATE; insert reservation (unique active per user); insert call (unique live per person) |
| Reservation extension | Reservation row + customer balance rows FOR UPDATE |
| Call settlement | Call row (optimistic `WHERE phase = …`), customer balance rows, host Bean row; entry + settlement + reservation in one transaction |
| Purchase credit | Insert purchase (unique token hash) + entry in one transaction |
| Free call match | `freecall.cards` row FOR UPDATE; host daily counter row FOR UPDATE (`count < 20`) |
| Bean release | `FOR UPDATE SKIP LOCKED` over due held amounts; entry key per source entry |
| Withdrawal request | Host `bean_available` row FOR UPDATE; check ≥ 100,000 Beans and ≤ available |
| Payout cycle build and settle | Withdrawals FOR UPDATE SKIP LOCKED; per-item entries keyed by withdrawal |
| Purchase reversal and clawback | Customer and host balance rows; reversal limited to the unspent amount |
| Promo expiry | Grant rows SKIP LOCKED; keyed per grant |
| XP grant and reversal | Unique (source_type, source_id) |
| Rate change | Host row; not applied to a call already in progress (rate snapshotted on the call) |

Lock order is always ascending `ledger.accounts.id`, to avoid deadlocks. `TxManager` retries serialization and deadlock errors up to 3 times; every operation is idempotent, so retries are safe.

## Refunds, chargebacks and fraud

- Detected by Google Play RTDN plus a daily Voided Purchases API poll.
- **Unspent** Diamonds from the purchase are removed with `PurchaseReversal`.
- **Spent** Diamonds cannot be recovered from the customer. The shortfall is recorded on the purchase and a fraud case is opened.
- Host Beans from calls funded by that purchase that are still on hold are clawed back with `BeanClawback`. The 7-day hold exists for this (C19).
- XP from the purchase is reversed (negative `xp_events` row, source `reversal`).
- Payouts for hosts with an open fraud case are skipped by the cycle builder.

## Payout lifecycle

```text
bean_held ──7 days──▶ bean_available ──request (≥ ₹500)──▶ payout_pending ──weekly cycle, finance approval, provider──▶ paid_out
                                                                    └──provider failure──▶ bean_available
```

The cycle builder computes TDS per CA advice (section unresolved; see the business-model report B4). Provider integration is behind `PayoutProvider`. Nothing runs while `PAYOUTS_ENABLED=false`, which stays until incorporation and provider onboarding are complete (R3-7).

## Liabilities and reconciliation

- **Customer liability** = Σ user `diamond_purchased` (+ promotional, reported separately).
- **Host liability** = Σ user `bean_*` × ₹0.005.
- `reconcile-ledger` (daily):
  - recomputes every balance from postings and compares it with `ledger.balances`;
  - checks that every journal entry balances;
  - compares credited purchases against Google Play earnings reports;
  - compares paid withdrawals against provider statements.
  - Any difference raises an alert and an `audit.events` record. Discrepancies are corrected only by new entries (dual-control adjustments).

## Accounting note

The ledger records virtual units and payout obligations. Revenue recognition (on consumption), GST treatment (principal vs agent), TDS and the Play-fee base are **CA decisions** (business-model report B4) and are produced from ledger data by reporting, not encoded as postings.
