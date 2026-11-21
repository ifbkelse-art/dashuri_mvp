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
- `PlayStoreBilling` queries ProductDetails by `product_id`, calls `buyConsumable(autoConsume: false)` with `applicationUserName = sha256(userId)`, maps `purchaseStream`, and calls `completePurchase` only after the server answers `credited` or `rejected`. The server consumes the token (Play Developer API) so packs can be re-bought.
- Cashfree rail (founder decision F1): shown when the server lists `cashfree` in `rails` and the app is built with `--dart-define=DASHURI_CASHFREE_ENABLED=true`. Flow: `POST /v1/purchases/cashfree/orders` (Idempotency-Key per Pay intent) → `CashfreeSdkCheckout` (CFSessionBuilder + CFWebCheckoutPayment) → always `GET /v1/purchases/cashfree/orders/{id}`, polling with backoff for ~60 s while pending.
- Routes: `buyDiamonds` (`?rate=&host=` adds a talk-time hint), `checkout/:productId` (`?rail=` skips the rail sheet), `paymentResult/:orderId` (result via `extra`, falls back to fetching the Cashfree order).
- Package prices are an evaluation set (S11). The server catalogue maps product ids to Diamonds.
