# feature_wallet

Read-only view of the account's Diamond and Bean balances and ledger history. Balances come from the server ledger; the app never computes them.

## Layers

| Layer | Folder | Contents |
|---|---|---|
| Domain | `lib/src/domain/` | Entities: `WalletSummary`, `WalletEntry`; contract `WalletRepository`; one use case per action |
| Data | `lib/src/data/` | `WalletRemoteDataSource` (Go API), JSON mappers, `WalletRepositoryImpl` |
| Application | `lib/src/application/` | `WalletCubit` (add more cubits/blocs per page) |
| Presentation | `lib/src/presentation/` | **Founder-owned pages and widgets** |
| Wiring | `lib/src/di/`, `lib/src/routes/` | `registerWalletFeature(sl)`, `WalletRoutes` |

## API endpoints used

| Use case | Method | Path | Idempotency-Key |
|---|---|---|---|
| `GetWalletSummary` | GET | `/v1/wallet` | — |
| `ListWalletEntries` | GET | `/v1/wallet/entries` | — |

## Business rules and notes

- `reservedDiamonds` are held for a call in progress; `availableDiamonds` = purchased + promotional − reserved.
- Beans: on hold for 7 days after earning, then available; withdrawals live in the host feature.
- Buying Diamonds is the purchases feature. Navigate with `RoutePaths.buyDiamonds`.
- Founder rules S5: purchased Diamonds never expire, promotional Diamonds expire after 30 days, Diamonds are non-transferable, Beans never expire.

## Pages to build

- WalletPage (RoutePaths.wallet)
- Transaction history section

## Pages

- W01 `WalletPage` (tab route `RoutePaths.wallet`, live refresh on `wallet.updated`), W08 `TransactionHistoryPage`, W09 `TransactionDetailPage` (entry via `extra`, fallback scan of `/v1/wallet/entries`).
