# feature_host

Becoming a host, verification (KYC) status, availability, rate setting, Free Call pool opt-in, earnings and withdrawal requests.

## Layers

| Layer | Folder | Contents |
|---|---|---|
| Domain | `lib/src/domain/` | Entities: `HostStatus`, `HostEarnings`, `Withdrawal`, `KycSession`; contract `HostRepository`; one use case per action |
| Data | `lib/src/data/` | `HostRemoteDataSource` (Go API), JSON mappers, `HostRepositoryImpl` |
| Application | `lib/src/application/` | `HostDashboardCubit` (add more cubits/blocs per page) |
| Presentation | `lib/src/presentation/` | **Founder-owned pages and widgets** |
| Wiring | `lib/src/di/`, `lib/src/routes/` | `registerHostFeature(sl)`, `HostRoutes` |

## API endpoints used

| Use case | Method | Path | Idempotency-Key |
|---|---|---|---|
| `GetHostStatus` | GET | `/v1/host` | — |
| `ApplyAsHost` | POST | `/v1/host/application` | required |
| `StartKyc` | POST | `/v1/host/kyc/sessions` | required |
| `SetAvailability` | PUT | `/v1/host/availability` | — |
| `SendHeartbeat` | POST | `/v1/host/availability/heartbeat` | — |
| `SetRate` | PUT | `/v1/host/rate` | — |
| `SetFreeCallOptIn` | PUT | `/v1/host/free-call-opt-in` | — |
| `GetEarnings` | GET | `/v1/host/earnings` | — |
| `RequestWithdrawal` | POST | `/v1/host/withdrawals` | required |
| `ListWithdrawals` | GET | `/v1/host/withdrawals` | — |

## Business rules and notes

- Host independence (C14): no quotas, no forced availability. The app only sends the host's own choices.
- Rate limits come from the server (`minRatePerMinute`/`maxRatePerMinute` for the host's shared level; platform range 500–10,000 D/min, ladder unresolved).
- Withdrawals: weekly payout cycle, ₹500 minimum, 7-day hold (C19). Payouts are blocked until incorporation and a payout provider are in place (R3-7); the API returns `payouts_not_enabled` until then.
- KYC vendor is not chosen; `startKyc` returns a provider-neutral session.

## Pages to build

- HostDashboardPage (RoutePaths.hostDashboard)
- HostEarningsPage (RoutePaths.hostEarnings)
- WithdrawPage (RoutePaths.hostWithdraw)
- Host application / KYC flow
