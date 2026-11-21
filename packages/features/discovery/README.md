# feature_discovery

Browse hosts who are online and accepting calls, with the rate each host has set.

## Layers

| Layer | Folder | Contents |
|---|---|---|
| Domain | `lib/src/domain/` | Entities: `HostCard`; contract `DiscoveryRepository`; one use case per action |
| Data | `lib/src/data/` | `DiscoveryRemoteDataSource` (Go API), JSON mappers, `DiscoveryRepositoryImpl` |
| Application | `lib/src/application/` | `DiscoveryCubit` (add more cubits/blocs per page) |
| Presentation | `lib/src/presentation/` | **Founder-owned pages and widgets** |
| Wiring | `lib/src/di/`, `lib/src/routes/` | `registerDiscoveryFeature(sl)`, `DiscoveryRoutes` |

## API endpoints used

| Use case | Method | Path | Idempotency-Key |
|---|---|---|---|
| `ListAvailableHosts` | GET | `/v1/discovery/hosts` | — |

## Business rules and notes

- Availability is server-owned (host toggle + heartbeat). The list can be stale by seconds; the call request is the real check.
- `ratePerMinute` is in Diamonds per minute and is always shown before a call (founder decision C13).
- Filters (language, rate band) are not decided; add query parameters when they are.

## Pages to build

- DiscoveryPage (RoutePaths.discovery)
