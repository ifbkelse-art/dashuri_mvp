# ADR-004: Immutable double-entry ledger for Diamonds and Beans

- **Status:** Accepted, 2026-11-17

## Context
- Diamonds are prepaid value owed to customers until spent.
- Beans are payout obligations to hosts.
- Refunds, chargebacks, holds, weekly payouts, promotional expiry and XP all depend on an exact, auditable history.
- A mutable `balance` column cannot explain itself, is vulnerable to lost updates under concurrency, and cannot be reconciled against Google Play or payout statements.

## Decision
- Double-entry ledger: `ledger.accounts`, immutable `journal_entries` and `postings`, and a `balances` projection updated only by the posting trigger.
- The database enforces:
  - each entry balances per currency, at commit;
  - currency matches the account;
  - user balances can never be negative;
  - history is append-only;
  - each business event posts once (unique idempotency key).
- Entries are built only by Go templates (`ledger/templates.go`).
- Business rules come from a versioned rule set recorded on every entry.
- Reservations are a separate table, so concurrent calls cannot overspend.

## Alternatives
- **Mutable balances + transaction log:** two sources of truth that drift.
- **Event sourcing everything:** more machinery than needed; the ledger already is the event log for money.
- **External ledger service:** vendor lock-in and latency; unnecessary at this scale.

## Trade-offs
More rows, and every write is a multi-row transaction with locks. Reads use the projection, so they stay fast.

## Future
Partition `postings` by month when large. An INR ledger for payouts and TDS can be added as more currencies and accounts without changing the model.
