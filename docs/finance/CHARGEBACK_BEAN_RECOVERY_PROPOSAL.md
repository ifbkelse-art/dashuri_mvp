# Chargeback Bean recovery: proposed policy

**Status: PROPOSAL. Not implemented. Needs founder approval and a financial/business review (CA) before any code.**
Written 2026-11-27. Founder instruction: document it only.

## 1. What the code does today

When Google Play refunds or charges back a Diamond purchase (RTDN `voidedPurchaseNotification` or the `poll-voided-purchases` job):

1. `purchases.ReversalAmount` removes only the customer's **unspent purchased Diamonds**, capped at the purchase size and excluding Diamonds committed to a live call. It posts `purchase_reversal`.
2. Diamonds already spent (on calls or gifts) are **not recovered**. The shortfall is recorded in `commerce.purchases.unrecovered_diamonds` and in the audit event `purchase.reversal_shortfall`.
3. The host who earned Beans from those spent Diamonds **keeps them**. The ledger template `ledger.BeanClawback` (held Beans → `sys_bean_clawed_back`, key `bean_clawback:<case id>`) exists, but nothing calls it.

The result is that Dashuri absorbs the full loss on a refunded purchase whose Diamonds were spent. A customer and host working together could exploit this: buy, spend on the friendly host, then charge back.

## 2. Proposed policy (for review)

| # | Proposal | Reason |
|---|---|---|
| P1 | Recover Beans only while they are still **on hold** (the 7-day hold). Never take available or paid-out Beans automatically. | The hold exists to absorb this risk. Taking released Beans would break the hosts' expectation of what they can withdraw. |
| P2 | Attribute spent Diamonds from the refunded purchase to calls and gifts **first-in-first-out** after the purchase time. Recover the Beans each of those entries created (at that entry's own rule-set version), up to the shortfall. | The ledger pools purchased Diamonds, so there is no direct link between a purchase and a spend. FIFO is deterministic and auditable. |
| P3 | Each recovery is one `bean_clawback` entry per (case, source entry), keyed `bean_clawback:<purchase_id>:<source_entry_id>`. The case is the reversed purchase. | Exactly once; reversible later by a dual-control adjustment. |
| P4 | Anything not recoverable from held Beans stays a **shortfall** for finance review, with no automatic negative balances. | Wallet accounts are non-negative by design (DB CHECK). |
| P5 | Notify the host in plain language ("Earnings from a refunded payment were reversed"), with the amount. | Transparency; required by the Host Agreement. |
| P6 | Repeated chargebacks: a staff review of the customer, and of the host if one host receives most of a refunded customer's spend. No automatic ban. | Fraud signal, with human judgment. |
| P7 | Free Call Card compensation (paid by Dashuri, not by a customer purchase) is never clawed back. | It was not funded by the refunded purchase. |

## 3. Questions for the founder and the CA

1. Is recovering held Beans compatible with the Host Agreement and Indian consumer law? The Host Agreement text would need a clause.
2. Hold-only (P1), or also recover released-but-not-withdrawn Beans?
3. Should gifts and calls be treated the same way? (Open gift decision 5.)
4. Who absorbs the residual shortfall, and how is it booked (bad-debt expense)?
5. Should the host see the refunded customer's identity, or only "a refunded payment"?

## 4. What implementation would need (once approved)

- A spend-attribution query (purchase → later `call_settlement`/`gift_send` entries), and the clawback step inside the same transaction as `ReversePurchase`.
- A `bean_clawback` caller, wallet.updated for the host, notification copy, and an admin view of the cases.
- Integration tests: held vs released Beans, partial recovery, replay, concurrent release job versus clawback.

Until then, behaviour stays as in section 1.
