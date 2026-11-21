# feature_purchases

Buying Diamonds on Android through Google Play Billing. Diamonds are digital goods, so Play Billing is required (Play Payments policy). Alternative billing in India is NOT assumed available.

## Flow

```
App                         Google Play             Go API                      Ledger
 │ PurchasePackageSelected ─▶ purchase sheet
 │ ◀── purchaseStream (purchased, token)
 │ POST /v1/purchases/google-play {token} (Idempotency-Key) ─▶ verify token with
 │                                                             Play Developer API ─▶ credit purchased
 │ ◀── {status: credited, diamonds_credited}                                          Diamonds once
 │ complete/consume with Play (only after "credited")
```

- The server is the only writer of Diamonds. The purchase token is unique in the database, so a replay cannot credit twice.
- Refunds and chargebacks reach the server through Real-Time Developer Notifications and the Voided Purchases API (backend `purchases` module), which reverses the ledger.
- `PlayStoreBilling` is a documented TODO skeleton; it returns `billing_not_implemented` until built.
- Package prices are an evaluation set (S11). The server catalogue maps product ids to Diamonds.
