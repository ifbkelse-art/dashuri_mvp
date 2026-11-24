# Dashuri ledger engineering specification (5:4 model)

**Date:** 24 Nov 2026 · **Status:** design proposal for founder and engineering review. **Nothing here is implemented.** No application code, migration, configuration or data was changed. 5 Diamonds → 4 Beans at ₹0.005/Bean is approved **for financial modelling only**.

**Companion documents:**
- [`../dashuri_monetization_math.md`](../dashuri_monetization_math.md): economics.
- [`dashuri_monetization_open_questions.md`](dashuri_monetization_open_questions.md): decision register.
- [`dashuri_monetization_audit_report.md`](dashuri_monetization_audit_report.md): audit report.
- [`dashuri_implementation_readiness_checklist.md`](dashuri_implementation_readiness_checklist.md): readiness checklist.

**Evidence base:**
- **Repository code** read on 24 Nov 2026:
  - `backend/internal/modules/ledger/{ledger,templates}.go`
  - `backend/internal/adapters/postgres/{ledger,purchases_repo,hosts_repo,wallet_repo}.go`
  - `backend/internal/modules/{calls,purchases,payouts}`
  - `supabase/migrations/20261117000300_economy_and_ledger.sql`, `…000400_commerce_hosting_calls.sql`, `20261121000400_money.sql`
- **Reference ledger** (Python): `docs/finance/monetization_ledger.py`.
- **A PostgreSQL prototype** of this design, run in a throwaway PostgreSQL 15.14 cluster with real concurrent connections (§12).

---

## 1. What exists today (and must be extended, not replaced)

The production ledger is already a **real double-entry, append-only journal**:

| Element | Today [CODE] | Keep / change |
|---|---|---|
| `ledger.accounts` | One row per (owner, kind); `currency ∈ {DIAMOND, BEAN, INR_PAISE}`; user buckets `non_negative` | Keep. Add kinds and the `BEAN_FIFTH` unit (§2) |
| `ledger.journal_entries` | `entry_type` CHECK list; `idempotency_key UNIQUE`; `rule_set_version`; `metadata`; append-only trigger | Keep. **Add `payload_fingerprint`** (§6); extend the `entry_type` list |
| `ledger.postings` | Signed amounts; currency must match the account; projection trigger; **deferred constraint: each entry sums to 0 per currency and has ≥ 2 postings**; append-only | Keep unchanged |
| `ledger.balances` | Projection maintained only by the trigger; `CHECK (not non_negative or balance >= 0)` | Keep. Add `non_positive` for receivables |
| `PostEntry` (Go) | Validates; inserts the entry `ON CONFLICT (idempotency_key) DO NOTHING`; **a duplicate key returns `replayed=true` without comparing the payload**; locks balance rows in ascending id; inserts postings | **Change:** a duplicate key with a different fingerprint must fail (§6) |
| Templates | `PurchaseCredit`, `CallSettlement`, `FreeCallCompensation`, `BeanRelease`, `WithdrawalRequested`, `PayoutSettled`, `PromoExpiry`, `PurchaseReversal`, `BeanClawback`, `Adjustment` (dual control) | Keep; add `CallReversal`, `ReceivableOffset`; change `CallSettlement` (5:4 + carry) |
| Diamond buckets | `diamond_purchased`, `diamond_promotional`; **no lots** | Add a lot subledger (§3) |
| Bean holds | One `bean_held` account per host; release per source entry, `min(credit, current held)` | Add a per-call hold subledger (§3) |
| Reversals | `PurchaseReversal` removes `min(purchase D, purchased − committed)` from the **pooled** balance | Lot-based reversal (§8) |
| Host clawback | `BeanClawback` template exists but **is not called anywhere** | Implement through `CallReversal` (§8) |
| Payouts | Withdrawal request built; `PayoutSettled` has no caller; `PAYOUTS_ENABLED=false` | Out of scope until founder approval |
| INR | `INR_PAISE` allowed; **no INR accounts or postings** | Separate INR finance journal (§2.4) |
| Purchase price | `commerce.purchases` has **no price column** (price is read from `economy.diamond_packages` at order time) | **Add `price_paise` snapshot** (needed for lot pricing and revenue) |

---

## 2. Chart of accounts

**Sign convention** (existing): a posting's amount is added to the account's balance.
- User accounts hold what the user owns (≥ 0).
- System accounts are the other side and may go negative.
- "Debit/credit" below uses the accounting meaning for the platform's books.

### 2.1 DIAMOND unit (stored-value units owed to customers)

| Account | Owner | Type (platform view) | Normal sign | Control / subledger | Status |
|---|---|---|---|---|---|
| `diamond_purchased` | customer | Liability: paid stored value | ≥ 0 | Control. Subledger `ledger.diamond_lots` (kind purchased) | exists |
| `diamond_promotional` | customer | Contingent liability: no cash received | ≥ 0 | Control. Subledger `ledger.diamond_lots` (kind promotional) | exists |
| `sys_diamond_issued_purchased` | system | Contra: issuance against cash | ≤ 0 | — | exists |
| `sys_diamond_issued_promotional` | system | Contra: issuance as marketing | ≤ 0 | — | exists |
| `sys_diamond_consumed` | system | Consumed (revenue basis) | ≥ 0 | Subledger `calls.settlements` | exists |
| `sys_diamond_consumption_reversed` | system | Consumption undone (dispute, chargeback of spent) | ≥ 0 | Subledger `ledger.call_reversals` | **new** |
| `sys_diamond_expired` | system | Promo expiry | ≥ 0 | `ledger.promo_grant_expiries` | exists |
| `sys_diamond_reversed` | system | Unspent Diamonds removed on refund/chargeback | ≥ 0 | `commerce.purchases` | exists |
| `sys_diamond_adjustment` | system | Dual-control corrections | any | `adjustment` entries | exists |

### 2.2 BEAN unit (whole Beans owed to hosts, ₹0.005 each)

| Account | Owner | Type | Normal sign | Control / subledger | Status |
|---|---|---|---|---|---|
| `bean_held` | host | Liability: earned, inside the hold | ≥ 0 | Control. Subledger `ledger.bean_holds` (per call) | exists (subledger new) |
| `bean_available` | host | Liability: withdrawable | ≥ 0 | — | exists |
| `bean_payout_pending` | host | Liability: in a payout cycle | ≥ 0 | Subledger `payouts.withdrawals` | exists |
| `bean_receivable` | host | **Asset: Beans the host owes back** (post-release/post-payout reversal) | **≤ 0** (`non_positive`) | Subledger `ledger.call_reversals` | **new** |
| `sys_bean_issued` | system | Contra: issuance | ≤ 0 | — | exists |
| `sys_bean_paid_out` | system | Beans settled in INR | ≥ 0 | Subledger `payouts.withdrawals` (state paid) | exists |
| `sys_bean_clawed_back` | system | Beans recovered by reversal | ≥ 0 | `ledger.call_reversals` | exists |
| `sys_bean_adjustment` | system | Dual-control corrections | any | — | exists |

### 2.3 BEAN_FIFTH unit (fractional entitlement, 1 unit = 1/5 Bean)

| Account | Owner | Type | Normal sign | Control / subledger | Status |
|---|---|---|---|---|---|
| `bean_fifth_carry` | host | Liability: entitlement below one Bean | 0..4 | Control. Mirror `ledger.bean_carry.fifths` | **new** |
| `sys_bean_fifth_issued` | system | Contra | any | — | **new** |

### 2.4 INR_PAISE unit (finance journal, separate entry types; posted by finance jobs, not by call handlers)

Treatment is subject to CA advice (principal vs agent, GST timing, breakage). The accounts are proposed so that every rupee is traceable.

| Account | Type | Debit increases? | Notes |
|---|---|---|---|
| `inr_play_receivable` | Asset | yes | Sales reported by Google, not yet paid |
| `inr_bank` | Asset | yes | Bank statement reconciliation |
| `inr_tax_withheld_receivable` | Asset | yes | 0.1% income-tax TDS and GST TCS withheld by Google (creditable) |
| `inr_host_receivable` | Asset | yes | INR mirror of `bean_receivable` |
| `inr_customer_stored_value` | Liability | no | Ex-GST value of unspent purchased Diamonds (deferred revenue) |
| `inr_gst_output` | Liability | no | GST on Diamond sales (timing per CA) |
| `inr_gst_rcm_payable` | Liability | no | Reverse-charge GST on Google's fee (with matching ITC asset) |
| `inr_host_payable` | Liability | no | INR mirror of whole Beans held + available + pending |
| `inr_tds_payable` | Liability | no | TDS deducted from host payouts (section per CA) |
| `inr_call_revenue` | Income | no | Recognised on consumption of purchased Diamonds |
| `inr_revenue_reversal` | Contra-income | yes | Disputes and chargebacks of consumed Diamonds |
| `inr_store_fee_expense` | Expense | yes | Google Play service fee |
| `inr_gateway_fee_expense` | Expense | yes | Cashfree (only if ever enabled) |
| `inr_host_compensation_expense` | Expense | yes | Host Beans on paid consumption (if Dashuri is principal) |
| `inr_marketing_host_cost` | Expense | yes | Host Beans on promotional consumption and free calls |
| `inr_payout_fee_expense` | Expense | yes | Transfer fee + GST |
| `inr_chargeback_loss` | Expense | yes | Spent Diamonds charged back |
| `inr_rounding` | Suspense | either | Sub-paisa residue; must stay below ±1 paisa per document |

The units are never mixed in one balance. An entry may carry postings in several units, and **each unit must sum to zero independently**. The existing deferred trigger already enforces this.

---

## 3. New subledger tables (proposal; DDL not executed)

```sql
-- 3.1 Diamond lots: what each Diamond cost (FIFO pricing, chargeback attribution, "your price")
create table ledger.diamond_lots (
  id               uuid primary key default gen_random_uuid(),
  owner_user_id    uuid not null references identity.accounts (id),
  kind             text not null check (kind in ('purchased','promotional')),
  source_entry_id  uuid not null unique references ledger.journal_entries (id),  -- PurchaseCredit / PromoGrant
  purchase_id      uuid references commerce.purchases (id),
  original         bigint not null check (original > 0),
  remaining        bigint not null check (remaining between 0 and original),
  price_paise      bigint not null check (price_paise >= 0),                        -- 0 for promotional
  expires_at       timestamptz,                                                     -- promotional only
  charged_back_at  timestamptz,
  seq              bigint generated always as identity,
  check ((kind = 'promotional') = (expires_at is not null))
);
create index on ledger.diamond_lots (owner_user_id, kind, expires_at, seq) where remaining > 0;

-- 3.2 Which lots funded each call (immutable rows + counters bounded by checks)
create table ledger.call_funding (
  call_id     uuid not null references calls.calls (id),
  lot_id      uuid not null references ledger.diamond_lots (id),
  seq         smallint not null,
  used        bigint not null check (used > 0),
  returned    bigint not null default 0 check (returned >= 0),
  cb_reversed bigint not null default 0 check (cb_reversed >= 0),
  primary key (call_id, lot_id),
  check (returned + cb_reversed <= used)
);

-- 3.3 Per-host fractional carry (one row per host; the mutex row for all host-side Bean work)
create table ledger.bean_carry (
  host_user_id     uuid primary key references identity.accounts (id),
  fifths           smallint not null check (fifths between 0 and 4),
  total_fifths     bigint   not null check (total_fifths >= 0),   -- 4 × Σ net Diamonds charged on this host's calls
  rule_set_version text not null references economy.rule_sets (version),
  updated_at       timestamptz not null default now()
);

-- 3.4 Per-call Bean holds (replaces "release min(credit, current held)")
create table ledger.bean_holds (
  call_id      uuid primary key references calls.calls (id),
  host_user_id uuid not null references identity.accounts (id),
  entry_id     uuid not null unique references ledger.journal_entries (id),
  credited     bigint not null check (credited >= 0),
  clawed       bigint not null default 0 check (clawed >= 0),
  released     bigint not null default 0 check (released >= 0),
  release_at   timestamptz not null,
  check (clawed + released <= credited)
);
create index on ledger.bean_holds (release_at) where credited > clawed + released;

-- 3.5 Settlement record: add the 5:4 audit columns
alter table calls.settlements
  add column reversed_diamonds bigint not null default 0,
  add column carry_before smallint, add column carry_after smallint, add column fifths_added bigint;
-- reversed_diamonds is the only mutable column: replace the append-only trigger on calls.settlements with one
-- that allows only "reversed_diamonds" to increase, and add CHECK (reversed_diamonds between 0 and diamonds_charged).

-- 3.6 Reversals (append-only)
create table ledger.call_reversals (
  id              uuid primary key default gen_random_uuid(),
  reversal_key    text not null unique,                  -- caller-supplied id (dispute id, chargeback id + call)
  call_id         uuid not null references calls.calls (id),
  mode            text not null check (mode in ('dispute','chargeback','fraud')),
  lot_id          uuid references ledger.diamond_lots (id),   -- chargeback only
  diamonds        bigint not null check (diamonds > 0),
  beans_clawed    bigint not null check (beans_clawed >= 0),
  from_held       bigint not null, from_available bigint not null, to_receivable bigint not null,
  carry_before    smallint not null, carry_after smallint not null,
  entry_id        uuid not null unique references ledger.journal_entries (id),
  created_at      timestamptz not null default now(),
  check (from_held + from_available + to_receivable = beans_clawed),
  check ((mode = 'chargeback') = (lot_id is not null))
);

-- 3.7 Purchases: snapshot the price paid
alter table commerce.purchases add column price_paise bigint check (price_paise > 0);
```

The other tables are unchanged:
- `payouts.withdrawals` already exists for withdrawal requests.
- Payout provider results use the fingerprinted journal key.
- `ledger.xp_events` gains new source types (§10).

---

## 4. The 5:4 conversion with exact carry

**Constants** (rule set): `beans_per_diamond = 4/5`, `paise_per_bean = 1/2`. Integers only.

**Ownership.** The fractional entitlement belongs to the **host**, not to a call:
- Calls create entitlement (4 × D fifths). The host's whole-Bean balance is `⌊total_fifths ÷ 5⌋`, and the carry is the remainder.
- This makes the outcome **independent of settlement order** (tested: out-of-order and concurrent settlements give the same totals).

```text
Settlement of D > 0 Diamonds (D = ⌊R × s ÷ 60⌋ as today)
  T0 = bean_carry.total_fifths          (row locked)
  T1 = T0 + 4·D                         (int64; reject if 4·D or T1 would overflow)
  credit = T1 div 5 − T0 div 5          → BEAN postings
  carry' = T1 mod 5, Δcarry = carry' − carry   → BEAN_FIFTH postings (Δ ∈ −4..4; skip when 0)
  identity: 5·credit + Δcarry = 4·D     (asserted before posting)
```

| Case | Diamonds | Result |
|---|---|---|
| One call of 1 D | 1 | 0 Beans, carry 4/5 (tested on PostgreSQL: `{"beans":0,"carry":4}`) |
| Five calls of 1 D | 5 | Beans 0, 0, 0, 0, 4 → total 4, carry 0 |
| One call of 5 D | 5 | 4 Beans, carry 0 |
| 500 concurrent calls of 1–3 D | 999 | 5 × Beans + carry = 4 × 999 (tested) |
| Interrupted call (pauses ≥ 10 s unbilled) | D from billable seconds only | Same formula on the final D |
| Duplicate / retried settlement | — | Fingerprinted idempotency: replay returns the stored result; a different D fails |

**Carry lifecycle:**

| Event | Carry behaviour |
|---|---|
| Release, withdrawal, payout | Not involved. Only whole Beans move |
| Reversal / refund / chargeback | Recomputed exactly from `T − 4·D_r` (§8) |
| Account deletion / closure | If carry > 0, post one `carry_rounding` entry: FIFTH −carry, +1 Bean held (host-favourable, ≤ ₹0.005), then settle the account normally |
| Rule change to a ratio with another denominator | Same rounding-up entry at the cut-over, then the new rule starts at carry 0 |
| Rounding policy | Diamonds charged: floor once per call (customer-favourable). Beans: exact via carry. Paise at payout: Beans × 1/2. Withdrawals in whole Beans; odd Bean counts leave ½ paisa → **withdrawals in multiples of 2 Beans** [PROPOSAL] |

**Overflow.** Go `int64` max is 9.22 × 10¹⁸. `4·D` overflows only above 2.3 × 10¹⁸ Diamonds. `total_fifths` per host is bounded by lifetime spend. The existing `BeansForDiamonds` overflow guard pattern is kept (`D > MaxInt64/4 → ErrOverflow`).

---

## 5. Journal entries per business event (worked numbers, base example)

Example: a caller buys **Popular ₹1,199 → 54,000 D**, then makes a 10-minute call at 1,500 D/min = **15,000 D** to a host whose carry is 0.

| # | Event | Unit | Postings (sum 0 per unit) | Idempotency key | Source |
|---|---|---|---|---|---|
| 1 | Purchase credited | DIAMOND | `sys_diamond_issued_purchased −54,000`; `diamond_purchased(caller) +54,000` | `purchase_credit:<token hash>` | Play purchase verification |
| 1-INR | Sale reported (finance job) | INR | Dr `inr_play_receivable 119,900`; Cr `inr_customer_stored_value 101,610`; Cr `inr_gst_output 18,290` (taxable = ⌊119,900 × 100 ÷ 118⌋ = 101,610; GST = remainder) | `inr_sale:<order id>` | Play earnings report |
| 1-INR-b | Store fee | INR | Dr `inr_store_fee_expense 17,985` (15% of 119,900, base assumption); Cr `inr_play_receivable 17,985` | `inr_store_fee:<order id>` | Play earnings report |
| 2 | Call settled | DIAMOND | `diamond_purchased(caller) −15,000`; `sys_diamond_consumed +15,000` | `call_settlement:<call id>` | Settlement tx |
|  |  | BEAN | `sys_bean_issued −12,000`; `bean_held(host) +12,000` |  |  |
|  |  | BEAN_FIFTH | none (Δcarry = 0) |  |  |
| 2-INR | Revenue and host cost (daily finance job from settlements × lots) | INR | Dr `inr_customer_stored_value 28,225` (15,000 × 101,610 ÷ 54,000, floored; residue to `inr_rounding`); Cr `inr_call_revenue 28,225`; Dr `inr_host_compensation_expense 6,000`; Cr `inr_host_payable 6,000` | `inr_consumption:<call id>` | Settlement + lot price |
| 3 | Hold ends | BEAN | `bean_held −12,000`; `bean_available +12,000` (after receivable offset, §8) | `bean_release:<call id>` | Release job |
| 4 | Withdrawal requested (100,000 B) | BEAN | `bean_available −100,000`; `bean_payout_pending +100,000` | `withdrawal:<id>` | Host request |
| 5 | Payout paid (₹500) | BEAN | `bean_payout_pending −100,000`; `sys_bean_paid_out +100,000` | `payout_result:<withdrawal id>` (fingerprint = outcome) | Provider webhook |
| 5-INR | Cash out | INR | Dr `inr_host_payable 50,000`; Cr `inr_bank 49,950`; Cr `inr_tds_payable 50` (0.1% **only if** CA confirms 194-O applies); Dr `inr_payout_fee_expense 944`; Cr `inr_bank 944` | `inr_payout:<id>` | Bank/provider statement |
| 6 | Payout failed | BEAN | `bean_payout_pending −100,000`; `bean_available +100,000` | `payout_result:<id>` | Provider webhook |
| 7 | Promo grant 2,000 D | DIAMOND | `sys_diamond_issued_promotional −2,000`; `diamond_promotional +2,000` | `promo_grant:<grant id>` | Admin/campaign (budget-checked) |
| 7b | Promo consumed in a call (2,000 D) | DIAMOND/BEAN | as #2 from the promotional bucket; Beans +1,600 | `call_settlement:<id>` | — |
| 7b-INR | Promo host cost | INR | Dr `inr_marketing_host_cost 800`; Cr `inr_host_payable 800` (no revenue) | `inr_consumption:<id>` | — |
| 8 | Promo expiry | DIAMOND | `diamond_promotional −x`; `sys_diamond_expired +x` | `promo_expiry:<grant>` | Expiry job |
| 9 | Dispute: reverse 1,000 D of the call | DIAMOND | `sys_diamond_consumed −1,000`; `diamond_purchased(caller) +1,000` | `call_reversal:<reversal key>` | Support decision |
|  |  | BEAN | `bean_held −800`; `sys_bean_clawed_back +800` |  |  |
| 9-INR | — | INR | Dr `inr_revenue_reversal 1,881`; Cr `inr_customer_stored_value 1,881`; Dr `inr_host_payable 400`; Cr `inr_host_compensation_expense 400` | `inr_reversal:<key>` | — |
| 10 | Chargeback of the purchase (39,000 unspent + 15,000 spent) | DIAMOND | Unspent: `diamond_purchased −39,000`; `sys_diamond_reversed +39,000`. Spent: `sys_diamond_consumed −15,000`; `sys_diamond_consumption_reversed +15,000` | `purchase_reversal:<case>` + `call_reversal:cb:<case>:<call>` | Play voided purchase |
|  |  | BEAN | Claw 12,000 from that call's hold → available → receivable (§8) |  |  |
| 10-INR | — | INR | Dr `inr_customer_stored_value 73,385`; Dr `inr_revenue_reversal 28,225`; Dr `inr_gst_output 18,290` (credit note, per CA); Cr `inr_play_receivable 119,900`; host side mirrors #9; spent part net of clawback → `inr_chargeback_loss` | `inr_chargeback:<case>` | — |
| 11 | Reversal after payout | BEAN | `bean_receivable −x`; `sys_bean_clawed_back +x` | `call_reversal:<key>` | — |
| 12 | Receivable offset at the next release | BEAN | `bean_held −r`; `bean_available +(r − o)`; `bean_receivable +o` | `bean_release:<call id>` | Release job |
| 13 | Free-call compensation (if ever enabled) | BEAN | `sys_bean_issued −2,000`; `bean_held +2,000` (INR: Dr `inr_marketing_host_cost 1,000`) | `free_call_comp:<id>` | Existing |
| 14 | Carry rounding at closure | BEAN/FIFTH | `bean_fifth_carry −c`; `sys_bean_fifth_issued +c`; `sys_bean_issued −1`; `bean_held +1` | `carry_rounding:<host>:<reason>` | Closure job |
| 15 | Admin adjustment | any one unit | Existing dual-control template; reason code required | `adjustment:<proposal>` | Two staff |

**Balances after #1 and #2:**
- Caller `diamond_purchased` = 39,000.
- `sys_diamond_consumed` = +15,000; `sys_diamond_issued_purchased` = −54,000.
- Host `bean_held` = 12,000; `sys_bean_issued` = −12,000.
- DIAMOND sum = −54,000 + 39,000 + 15,000 = 0. BEAN sum = 0.

---

## 6. Idempotency (fixes a gap in today's `PostEntry`)

| Item | Specification |
|---|---|
| Key format | `<event>:<stable business id>`, e.g. `call_settlement:<call uuid>`, `call_reversal:<support case id>`, `payout_result:<withdrawal id>`, `purchase_credit:<sha256(token)>` |
| Scope | Global unique across `ledger.journal_entries` (exists) and `ledger.idempotency` for operations that post several entries (chargeback) |
| Fingerprint | `sha256` of a canonical encoding of the economic payload: for settlement `(caller, host, D, rule_set_version)`; for reversal `(call, D_r, mode, lot)`; for payout result `(withdrawal, outcome)` |
| Same key + same fingerprint | Return the stored result; post nothing |
| Same key + different fingerprint | **Error `idempotency_conflict` (HTTP 409); the transaction rolls back.** Today's `PostEntry` returns `replayed=true` here, which would silently accept a different payload |
| Concurrent duplicates | The unique index serialises them. The second waits for the first to commit, then reads the stored result (prototype T1: 50 concurrent identical settlements, one charge) |
| Retry after network failure | Client retries with the same key. A committed result is replayed; an aborted one leaves no key (the key insert is in the same transaction) |
| Retention | Journal keys: forever (part of the journal). `ledger.idempotency` result rows for multi-entry operations: forever (small). No TTL on financial keys |
| Failure recovery | Any error aborts the whole transaction, including the key. No partial state (prototype T11: a refused over-reversal leaves no key) |

```sql
alter table ledger.journal_entries add column payload_fingerprint bytea;   -- nullable for history; required for new entry types
create table ledger.idempotency (key text primary key, fingerprint bytea not null, result jsonb, created_at timestamptz not null default now());
```

```go
// PostEntry change (pseudocode)
fp := e.Fingerprint()                       // sha256(canonical JSON of type, key, postings, rule version)
err = tx.QueryRow(ctx, `insert ... (..., payload_fingerprint) values (..., $7)
                        on conflict (idempotency_key) do nothing returning id`, ..., fp).Scan(&entryID)
if errors.Is(err, pgx.ErrNoRows) {
    var stored []byte
    tx.QueryRow(ctx, `select id, payload_fingerprint from ledger.journal_entries where idempotency_key = $1`, e.IdempotencyKey).Scan(&entryID, &stored)
    if stored != nil && !bytes.Equal(stored, fp) {
        return "", false, ErrIdempotencyConflict // never a silent replay
    }
    return entryID, true, nil
}
```

---

## 7. Transaction boundaries and locking

**Isolation:** READ COMMITTED (the repo default) with explicit row locks. SERIALIZABLE is not required, because every read that decides an amount is made under `FOR UPDATE` on the row that serialises that decision. The existing retry of 40001/40P01 up to 3 times is kept (the prototype allowed 10; none were needed in 25 runs).

**Global lock order** (prevents deadlocks; verified by 25 prototype runs with no deadlock in the server log):
1. Idempotency key (unique insert).
2. **Caller wallet mutex:** the caller's `ledger.balances` rows for `diamond_purchased` + `diamond_promotional`, ascending id. This already exists as `LockUserBalances`.
3. The caller's `diamond_lots` rows, in spend order.
4. `calls.calls` / `calls.settlements` row of the call.
5. **Host mutex:** `ledger.bean_carry` row of the host.
6. `ledger.bean_holds` row of the call.
7. All balance rows to be posted, ascending account id (existing `lockAccounts`).

Operations touching several hosts (a chargeback funding calls to many hosts) process hosts in ascending host id.

| Operation | One transaction containing | Locks (in order) | Guards |
|---|---|---|---|
| Call settlement | Billable seconds → D; lot consumption; `call_funding`; carry update; `bean_holds` insert; `CallSettlement` entry; `calls.settlements`; reservation → settled | 1, 2, 3, 4 (optimistic phase check, as today), 5, 7 | D > 0; D ≤ reservation and ≤ available; non-negative CHECKs; key fingerprint |
| Diamond consumption | (part of settlement) | 2, 3 | `remaining ≥ 0` CHECK |
| Bean entitlement + carry | (part of settlement) | 5 | `fifths 0..4`; identity `5·credit + Δ = 4·D` asserted in Go before posting |
| Journal posting | `PostEntry` | 7 | Deferred balance trigger; ≥ 2 non-zero postings; **skip zero-amount entries instead of posting them** (prototype bug found and fixed) |
| Reversal | Bound check; Diamonds back to lots (dispute) or counters (chargeback); carry recompute; recovery split; `CallReversal` entry; `call_reversals` row; XP reversal | 1, 2, 3, 4 (`FOR UPDATE`), 5, 6, 7 | `reversed + D_r ≤ charged`; chargeback D_r ≤ lot's net funding; unknown references raise |
| Host release | Per hold: offset receivable, then release remainder | 5, 6, 7 | `SKIP LOCKED` in batch selection; key `bean_release:<call>` |
| Payout initiation (withdrawal) | `WithdrawalRequested` + withdrawal row | 1, 5, 7 | Receivable = 0; available ≥ amount ≥ minimum; no open fraud case; `PAYOUTS_ENABLED` |
| Payout submission (cycle) | Mark the batch submitted | withdrawal rows `FOR UPDATE SKIP LOCKED`, then 5 | **Re-check receivable and open cases at submission** (§8.4) |
| Payout confirmation | `PayoutSettled` + state change | 1 (fingerprint = outcome), withdrawal row, 5, 7 | State must be `pending`/`submitted`; unknown id raises |

**Constraints used:**
- **Unique:** idempotency keys, `call_funding (call, lot)`, `bean_holds.call_id`, `bean_carry.host`, `one_active_reservation_per_user` (exists), `call_reversals.reversal_key`.
- **Foreign keys:** every subledger row references its journal entry.
- **CHECKs:** bounds (`remaining between 0 and original`, `returned + cb_reversed ≤ used`, `clawed + released ≤ credited`, `fifths 0..4`, `reversed ≤ charged`, balance sign rules).

**Advisory locks are not needed:** row locks on the wallet and carry rows serve as the per-user mutexes.

---

## 8. Reversal model

```text
reverse(key, call, D_r, mode, lot?)
  claim key (fingerprint) ─ replay / conflict
  lock caller wallet → lots → call row
  require 0 < D_r and settlements.reversed + D_r ≤ diamonds_charged          (ReversalExceedsCharge)
  mode=dispute:    give back last-spent lot first; never refill a charged-back lot (→ sys_diamond_reversed)
  mode=chargeback: D_r ≤ call_funding(lot).net; cb_reversed += D_r; nothing returned
  lock host carry: T1 = T0 − 4·D_r; claw = T0 div 5 − T1 div 5; carry' = T1 mod 5
  recover: own = min(claw, hold.credited − clawed − released)   → bean_held
           avail = min(claw − own, bean_available)               → bean_available
           recv = claw − own − avail                             → bean_receivable (≤ 0 balance)
  post CallReversal; insert call_reversals; XP events (§10)
```

### 8.1 Properties (all tested in Python and/or PostgreSQL)

| Property | Evidence |
|---|---|
| Call-specific: removes only that call's 4·D_r fifths; other calls' held Beans are untouched | Py `test_reversal_after_subsequent_settlements…`; PG T4 |
| Bounded: Σ D_r ≤ D charged; Σ claw ∈ {⌊4D/5⌋, ⌈4D/5⌉} | Py `test_partial…`; PG T5 (two racing 600 D reversals of a 1,000 D call: one refused) |
| Idempotent; conflicting payload refused | Py `test_duplicate_reversal…`; PG T5 |
| Cumulative partials | Py `test_partial…` |
| After release: claw from available | Py `test_reversal_after_release…` |
| After payout: receivable, offset at next release, withdrawals blocked | Py `test_reversal_after_payout…`; PG T6/T6b/T6c |
| Dispute then chargeback; chargeback then dispute (refused) | Py `test_dispute_then_chargeback…`; PG T11 |
| Concurrent reversals and settlements | PG T4, T5, T9 |
| Failed reversal leaves no state | PG T11 |

**Why the claw can exceed the call's own credit by one Bean.** If call A left 2/5 in the carry and call B completed a whole Bean with it, removing A must remove that Bean too; otherwise the host keeps 0.4 Bean that no call supports. The extra Bean is taken from available Beans, else booked as a receivable. It is never taken from B's held Beans.

### 8.2 "Recover from available" takes from unrelated released earnings

It does. Those Beans are already the host's free balance, and the amount is the host's own debt. The alternative is to always book a receivable and leave available untouched, so the host withdraws first and owes later.

**Recommendation:** recover from available. It lowers credit risk, and the host is notified with the reason. This is a founder decision (D-REV-1).

### 8.3 Money already withdrawn

A reversal after payout leaves `bean_receivable` < 0 (an asset of doubtful recovery):
- It is offset against future releases (prototype T6c).
- Withdrawals are blocked while it is open (T6b).
- After N days without recovery it is written off to `inr_chargeback_loss` by a dual-approved adjustment. N is a founder decision.
- **Nothing ever goes negative without an account:** the receivable account is the representation.

### 8.4 Reversal during payout processing (gap found)

In both the reference ledger and the prototype, a withdrawal already `pending` is not touched by a reversal, so the payout can still complete and the claw becomes a receivable (prototype T6). This is consistent, but it pays out money that is now owed back.

**Proposal:** the payout cycle builder and the provider-submission step re-check `bean_receivable` and open fraud cases under the host mutex. A withdrawal of a host with a new receivable is put **on hold** (state `held_for_review`) instead of being submitted. Once a payout is submitted to the provider it cannot be stopped, and the receivable path applies.

### 8.5 Reference-ledger gaps found by this audit (Python spec; not production)

| # | Finding | Severity | Spec fix |
|---|---|---|---|
| R1 | A dispute returns promotional Diamonds to an **expired** promo lot, and they stay spendable until the next `expire()` run | Medium (promo farming) | Return to an expired lot posts directly to `sys_diamond_expired` |
| R2 | `settle()` accepts D = 0 (creates an empty call) | Low | Require D > 0 (production template already returns `ErrNothingToSettle`) |
| R3 | Pending withdrawal unaffected by reversal (see 8.4) | Medium | Hold at payout submission |
| R4 | Concurrency is a single process lock | Not evidence | Replaced by PostgreSQL tests (§12) |
| R5 | No XP, no INR journal, no lots for revenue | Scope | §2.4, §3, §10 |

---

## 9. Go service architecture (proposal)

```text
modules/economy      Rules (adds BeansPerDiamond 4/5, PaisePerBean 1/2, hold by trust, host-level gates)
modules/ledger       Entry templates: CallSettlement(5:4 + carry), CallReversal, ReceivableOffset, CarryRounding;
                     Entry.Fingerprint(); ErrIdempotencyConflict
modules/calls        settle.go → SettlementService.Settle(tx, call) (pure computation in Go, posting via repo)
modules/reversals    NEW: Reverse(ctx, ReverseRequest{Key, CallID, Diamonds, Mode, LotID}) → ReversalResult
modules/purchases    ReversePurchase → lot-based: unspent from that lot; spent → reversals.Reverse per funded call
modules/payouts      Withdraw / BuildCycle / Submit / ApplyResult (still behind PAYOUTS_ENABLED)
modules/levels       HostLevel(view) + AccountXP; consumers: hosts (price ceiling), discovery
adapters/postgres    LedgerRepo: LockWallet, ConsumeLots, LockCarry, UpdateCarry, InsertHold, Release, PostEntry
jobs                 release-bean-holds, expire-promo-diamonds, reconcile-ledger (extended §11), finance-inr-journal
```

```go
// Settlement core (pseudocode; runs inside calls' existing settle transaction)
func (s *Settler) Settle(ctx context.Context, tx pgx.Tx, c Call, billable int64) (Charge, error) {
    d := s.rules.DiamondsForSeconds(c.RatePerMinute, billable)                       // floor once
    if d == 0 { return Charge{}, nil }                                                // no entry
    wallet, err := s.repo.LockWallet(ctx, tx, c.CallerID)                             // lock 2
    d = min(d, c.ReservedAmount, wallet.Available)
    lots, err := s.repo.ConsumeLots(ctx, tx, c.CallerID, d, s.rules.SpendOrder)       // lock 3; FIFO
    carry, err := s.repo.LockCarry(ctx, tx, c.ReceiverID)                             // lock 5
    t1, ok := addOverflow(carry.TotalFifths, mulOverflow(4, d))
    if !ok { return Charge{}, economy.ErrOverflow }
    credit, next := t1/5-carry.TotalFifths/5, int16(t1%5)
    if 5*credit+int64(next-carry.Fifths) != 4*d { panic("5:4 identity") }             // invariant
    entry := ledger.CallSettlement(ledger.CallCharge{ /* lots split, credit, Δcarry, rule version */ })
    if _, replayed, err := postgres.PostEntry(ctx, tx, entry); err != nil || replayed { return ..., err }
    s.repo.UpdateCarry(ctx, tx, c.ReceiverID, next, t1, s.rules.Version)
    s.repo.InsertHold(ctx, tx, c.ID, c.ReceiverID, entryID, credit, now.Add(s.rules.HoldFor(host)))
    s.repo.InsertFunding(ctx, tx, c.ID, lots)
    return Charge{Diamonds: d, HostBeans: credit, CarryBefore: carry.Fifths, CarryAfter: next}, nil
}
```

**The server is the only authority** for price, balance, billable seconds, D, Beans, carry, XP, Host Level and payout eligibility (it already is). The client sends identifiers only.

---

## 10. XP and Host Level (proposal; awaiting approval)

| Question | Recommendation | Why |
|---|---|---|
| 1. Basis | **Net eligible Beans released**: Beans from paid (purchased-Diamond-funded) calls, counted when released from hold, minus reversals | Progression only for money that has cleared the clawback window |
| 2. Refund | Negative `host_xp` event equal to the Beans clawed from that call, **if** they had been released and counted | Symmetric |
| 3. Chargeback | Same as 2 | — |
| 4. Receivables | No extra penalty (the reversal already reduced XP); withdrawals are blocked | Avoid double counting |
| 5. Falls below threshold | Level drops; stored price is capped by the existing `CapRate` path (already used for purchase-reversal level drops) | Price ceiling integrity |
| 6. Can it decrease? | Only through reversals | — |
| 7. Payout | No effect | Payout is cash movement, not earning |
| 8. Free-call compensation | Not eligible | No revenue |
| 9. Promotional Diamonds | Host is paid; **not eligible for Host XP** (needs `call_funding` lots to know the share) | Stops promo-funded self-dealing |
| 10. Fraud restrictions | Progression frozen while a case is open (no new positive events); reversals still apply | — |

**Formulas:**
- **HostXP** = Σ eligible released Beans − Σ clawed eligible Beans.
- **Account XP** = 8 × purchased Diamonds consumed (net of reversals) + HostXP. This preserves `XPDiamondWeight 8`, `XPBeanWeight 1`.

**Thresholds:**
- Keep P12 `[0, 32k, 100k, 250k, 600k, 1.5M, 3.5M, 8M, 18M, 40M]` for Host Level (Level 10 = 40M Beans = ₹2 lakh).
- Distinct paying callers `[0,2,5,10,20,35,60,100,150,250]` and a 20% per-caller cap: **proposal**.

**Events and recalculation:**
- `ledger.xp_events.source_type` adds `call_consumption`, `bean_release`, `call_reversal`, `recalc`.
- Historical recalculation never edits events. It posts `recalc` deltas computed from the journal.

**Edge-case tests:**
- release then full reversal → XP back to the previous value;
- reversal before release → no XP was ever granted;
- a promo-only call → host paid, HostXP 0;
- the 20% cap with one whale caller;
- a level drop caps the price before the next call but not during a live call.

---

## 11. Reconciliation (extend `reconcile-ledger`)

Daily; any difference raises an alert and an `audit.events` row. It is corrected only by new entries.

1. Every entry balances per unit (DB-enforced; re-checked).
2. `ledger.balances` = Σ postings per account (exists).
3. **Lots:** Σ `diamond_lots.remaining` per (user, kind) = `diamond_purchased` / `diamond_promotional`.
4. **Funding:** per call, Σ (used − returned − cb_reversed) = diamonds_charged − reversed_diamonds.
5. **Holds:** per host, Σ (credited − clawed − released) = `bean_held`.
6. **5:4 identity:** per host, 5 × (held + available + pending + receivable) + 5 × paid(host) + `bean_fifth_carry` = `bean_carry.total_fifths` = 4 × Σ net Diamonds of the host's calls (rule version 5:4 only). `bean_carry.fifths` = `bean_fifth_carry`.
7. **Payouts:** `sys_bean_paid_out` = Σ paid withdrawals; provider statement = paid withdrawals × ₹0.005 − TDS.
8. **Purchases:** credited purchases = Play earnings report rows (exists); reversed purchases = Play voided purchases.
9. **Promo:** Σ promotional lots remaining = `diamond_promotional`; promo budget ledger ≥ grants.
10. **INR:** `inr_host_payable` = whole Beans (held + available + pending) × ½ paisa; `inr_customer_stored_value` = Σ lots remaining × lot ex-GST price per Diamond (± rounding suspense < 1 paisa per lot).

---

## 12. Test strategy and evidence

### 12.1 Executed on 24 Nov 2026

| Suite | Command | Result |
|---|---|---|
| Go unit (economy, ledger, calls, levels, wallet) | `cd backend && go test ./internal/modules/{economy,ledger,calls,purchases,payouts,levels,wallet}/...` | exit 0; all packages ok (purchases and payouts have no unit tests) |
| Go integration, real PostgreSQL (repo script, throwaway cluster, all migrations) | `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 ./scripts/test-backend-integration.sh -v ./...` | exit 0; **223 PASS, 0 FAIL, 0 SKIP**. Includes `TestPostEntryExactlyOnceUnderConcurrency`, `TestPlayPurchaseCreditedOnceUnderConcurrency`, `TestParallelEndAndStaleSweepSettleOnce`, `TestVoidedPurchaseReversesOnlyUnspent`. Without the locale variables the script fails at `initdb` (environment issue) |
| Python reference ledger | `python3 -I -m unittest discover -s docs/finance -p 'test_*.py' -v` | exit 0; 22 tests OK |
| **Prototype of this spec on PostgreSQL 15.14** (scratch cluster, pgx pool of 64 connections; scratch files, not in the repo) | throwaway `initdb` + `schema.sql` + Go driver | **29/29 checks passed in 25 consecutive runs; no deadlocks** after two prototype bugs were found and fixed (below) |

**Prototype checks:**

| ID | Scenario |
|---|---|
| T1 | 50 concurrent identical settlements → one charge, one result |
| T2 | 40 concurrent settlements of one call id with two payloads → 20 accepted (same payload), 20 `idempotency_conflict` |
| T3 | 300 concurrent 1,000 D calls on a 100,000 D wallet → exactly 100 settle, balance 0 |
| T4 | 50 settlements racing 50 reversals on one host → entitlement exact |
| T5 | Two 600 D reversal keys of a 1,000 D call racing ×10 each → one accepted, the other refused |
| T6 | Full reversal racing 5 duplicate "paid" webhooks → paid once, receivable 100,000; withdrawal blocked; next release offsets the receivable |
| T7 | 10 concurrent 100,000-Bean withdrawals on 250,000 available → exactly 2 |
| T8 | Unknown withdrawal webhook refused; paid/failed webhooks racing → one outcome, one entry, the other conflicts |
| T9 | Chargeback racing 6 settlements and a dispute on the same lot → lot fully reversed, nothing still funded by it |
| T10 | 1 D, 5 × 1 D, 5 D, 500 concurrent small calls → exact |
| T11 | Over-reversal leaves no trace; dispute → chargeback → later dispute refused |
| all | Invariant query after each test: balanced entries, projection = journal, per-host 5:4 identity, held = holds, lots = buckets, funding = net charge, paid = withdrawals |

**Prototype bugs found (both are design requirements now):**
1. A payout webhook for an **unknown withdrawal** was accepted and posted an empty entry. Rule: unknown references raise; `PostEntry` must refuse entries with fewer than two non-zero postings.
2. A chargeback of a **fully spent** purchase tried to post an empty "remove unspent" entry and failed under the new guard. This was intermittent: 3 of 25 runs. Rule: zero-amount steps are skipped, never posted. The Go code already does `if remove > 0`.

### 12.2 Required before implementation is accepted (Go + PostgreSQL, `-tags integration`, multiple connections)

| Area | Tests |
|---|---|
| Arithmetic | 4/5 exactness; carry over 10⁵ random calls; out-of-order equality; overflow guard at `MaxInt64/4`; D = 1 |
| Ledger | Every new template balances; projection = journal; append-only triggers; compensating entries only |
| Idempotency | Same key + same payload; same key + different payload (409); concurrent duplicates; retry after a client timeout with the server committed |
| Concurrency | Settlements on one wallet; settlement vs reversal; reversal vs payout submission; simultaneous withdrawals; chargeback vs settlement; release vs reversal |
| Reversals | Full, partial, repeated, excessive, post-release, post-payout, dispute→chargeback, chargeback→dispute, failed |
| Reconciliation | All §11 checks on a seeded month of synthetic traffic |
| Migration | Backfill replay equals current balances (§13) on a copy of staging |

---

## 13. Migration and historical backfill (design only; nothing executed)

**Facts:**
- Payments are not configured.
- Payouts are disabled.
- The hosted Supabase project holds demo/test data only [project notes].
- **No real money has moved.** This makes the cut-over low-risk, but every step must still be reproducible.

| Data | Recoverable? | Treatment |
|---|---|---|
| Wallet balances | Yes (journal) | Verified against the projection before and after |
| Diamond lots | **Partly.** Purchases and settlements are in the journal, but consumption was pooled | Rebuild lots by replaying purchase credits and settlements in time order, assuming FIFO (and promo-first). Document as **an assumption, not history**. Price per lot from `economy.diamond_packages` by `product_id`; **actual price paid is not stored** (add the snapshot column first) |
| Bean balances | Yes | Unchanged; Beans keep ₹0.005 value |
| Per-call holds | Yes (`call_settlement` / `free_call_compensation` postings and `bean_release:<entry>` keys) | Backfill `bean_holds` with released = released amount |
| Fractional carry | **No.** M1 floored per call and credited residue to no one | Start every host at carry 0, total_fifths 0 at cut-over. Do **not** invent historical carry. The 5:4 identity is checked only for calls settled under the 5:4 rule version |
| Settlements | Yes | Add the new columns as null for M1 settlements |
| Reversals | Yes (`purchase_reversal` entries, `commerce.purchases.reversed/unrecovered`) | No host clawbacks exist historically (template unused) |
| Promo credits | None granted (no promo grants exist) | Nothing to migrate |
| Payout records | Withdrawal requests may exist; no payouts | Keep |
| XP | Yes (events) | New-basis XP recomputed from the journal and posted as `recalc` deltas; old events kept |

**Steps:**
1. Pre-validation: `reconcile-ledger` clean; zero active reservations; payouts off; maintenance window.
2. Snapshot the database (Supabase backup) and export the journal.
3. Apply DDL (§3, §6) as one reviewed migration.
4. Backfill lots, holds and XP deltas with an idempotent job. Run it twice to prove the second run changes nothing.
5. Shadow validation in staging: run both rule versions on a replay of the same synthetic traffic and compare totals.
6. Cut-over: insert rule set `…-5to4` with `effective_from`; calls created after it snapshot the new version.
7. Post-validation: all §11 checks; spot-check 20 calls by hand.
8. Rollback: insert a new rule set with the old ratio (append-only). New tables stay, unused. Beans already credited under 5:4 stay credited. **They are host earnings and cannot be taken back.** This is the irreversible part, and the reason founder approval is required before cut-over.

**Irreversible risks:**
- Beans credited and withdrawn under 5:4.
- Lot reconstruction is an assumption for pre-cut-over balances.
- Published host terms.
