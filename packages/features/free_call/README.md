# feature_free_call

The one-minute Free Call Card for eligible new customers: card status and a random match with an opted-in host.

## Layers

| Layer | Folder | Contents |
|---|---|---|
| Domain | `lib/src/domain/` | Entities: `FreeCallCard`, `FreeCallRequest`; contract `FreeCallRepository`; one use case per action |
| Data | `lib/src/data/` | `FreeCallRemoteDataSource` (Go API), JSON mappers, `FreeCallRepositoryImpl` |
| Application | `lib/src/application/` | `FreeCallCardCubit` (add more cubits/blocs per page) |
| Presentation | `lib/src/presentation/` | **Founder-owned pages and widgets** |
| Wiring | `lib/src/di/`, `lib/src/routes/` | `registerFreeCallFeature(sl)`, `FreeCallRoutes` |

## API endpoints used

| Use case | Method | Path | Idempotency-Key |
|---|---|---|---|
| `GetFreeCallCard` | GET | `/v1/free-call/card` | — |
| `RequestFreeCall` | POST | `/v1/free-call/requests` | required |
| `GetFreeCallRequest` | GET | `/v1/free-call/requests/{requestId}` | — |

## Business rules and notes

- Founder decision S4: one card per phone and device, random match among opted-in hosts, max 20 free calls per host per day, ₹10 host compensation per eligible free-call minute. All enforced server-side.
- Android only. Disabled on iOS (Apple guideline 1.2 excludes random chat): the app hides this feature when `Platform.isIOS`.
- Play policy: random-chat apps must block minors via Play Console tools (from 26 Aug 2026).
- Device binding needs a Play Integrity token; the data source will send it once the integration is chosen (TODO).
- When matched, navigate to the call route with the returned `callId`; the video_call feature takes over.

## Pages to build

- FreeCallPage (RoutePaths.freeCall)
