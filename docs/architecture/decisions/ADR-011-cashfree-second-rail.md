# ADR-011: Cashfree PG as a second, server-verified Diamond rail (behind a flag)

- **Status:** Accepted, 2026-11-21 (founder decision F1). Amends ADR-010.

## Context
The design handoff (W03–W07) and the founder's MVP brief specify Cashfree checkout states. ADR-010 requires Google Play Billing for virtual currency sold in apps distributed on Google Play. Cashfree has not yet confirmed the category in writing (business-model report R6).

## Decision
- **Google Play Billing stays the default** for Play-distributed builds.
- **Cashfree PG** is implemented end to end, but enabled only when **both** `CASHFREE_ENABLED=true` (server) and `DASHURI_CASHFREE_ENABLED=true` (app build) are set. The server advertises enabled rails in `GET /v1/purchases/packages` (`rails`).
- The server creates every Cashfree order. The amount comes from `economy.diamond_packages` and never from the client.
- Diamonds are credited **only** after server-side verification: a signature-verified webhook (HMAC-SHA256 over timestamp + raw body) followed by a server-to-server order fetch, or a server-to-server fetch triggered by the app's status poll. Crediting uses `ledger.PurchaseCredit` keyed by `sha256("cashfree:" + order_id)`, so it happens exactly once whatever the race.
- The ledger, XP and reversal paths are shared with Play.

## Consequences
- Turning Cashfree on in a Play build is a **policy decision, not a code change**. It needs Play's User Choice Billing / alternative billing enrollment for India, or a non-Play distribution channel, and Cashfree's written category approval.
- Refunds and chargebacks on Cashfree must be reconciled from Cashfree's dashboard or webhooks (`REFUND_STATUS_WEBHOOK`, disputes). These are listed as outstanding in `PROJECT_STATUS.md`.
