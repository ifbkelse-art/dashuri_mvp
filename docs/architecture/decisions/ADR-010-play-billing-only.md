# ADR-010: Google Play Billing for Diamonds; server-side verification

- **Status:** Accepted, 2026-11-17

## Context
- Diamonds are digital goods; Play's Payments policy requires Play Billing for virtual currency.
- Alternative billing in India exists but is **not assumed available** (business model, audit B3).
- Cashfree has not accepted Dashuri.

## Decision
- Android purchases use Play Billing through a `StoreBilling` port.
- The server verifies every purchase token with the Play Developer API and credits the ledger once (unique token hash). Only then does the app complete or consume with Play.
- Refunds and chargebacks arrive through RTDN plus the Voided Purchases API.
- Payouts are a separate, provider-neutral `PayoutProvider`, disabled until R3-7.

## Trade-offs
Play's fee (15% on the first US$1M of revenue each year, with enrollment) applies. If alternative billing is later approved, it becomes another `StoreBilling` adapter plus a server verification path. The ledger does not change.
