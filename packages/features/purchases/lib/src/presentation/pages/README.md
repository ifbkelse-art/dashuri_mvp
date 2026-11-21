# purchases pages (founder-owned)

- BuyDiamondsPage (RoutePaths.buyDiamonds): list `state.packages`, dispatch `PurchasePackageSelected(productId)`, then show `pendingPayment` / `verifying` / `completed` / `failed`.

Show the Diamonds credited from `state.lastVerification`, never a number computed on the device. A `pending` verification means Play has not confirmed payment yet (common with UPI); the balance updates later.
