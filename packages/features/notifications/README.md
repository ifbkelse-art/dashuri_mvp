# feature_notifications

Push-token registration and the in-app notification inbox.

## Layers

| Layer | Folder | Contents |
|---|---|---|
| Domain | `lib/src/domain/` | Entities: `InboxItem`; contract `NotificationsRepository`; one use case per action |
| Data | `lib/src/data/` | `NotificationsRemoteDataSource` (Go API), JSON mappers, `NotificationsRepositoryImpl` |
| Application | `lib/src/application/` | `InboxCubit` (add more cubits/blocs per page) |
| Presentation | `lib/src/presentation/` | **Founder-owned pages and widgets** |
| Wiring | `lib/src/di/`, `lib/src/routes/` | `registerNotificationsFeature(sl)`, `NotificationsRoutes` |

## API endpoints used

| Use case | Method | Path | Idempotency-Key |
|---|---|---|---|
| `RegisterDevice` | PUT | `/v1/me/devices` | — |
| `UnregisterDevice` | DELETE | `/v1/me/devices/{token}` | — |
| `ListInbox` | GET | `/v1/notifications` | — |
| `MarkRead` | POST | `/v1/notifications/{notificationId}/read` | — |

## Business rules and notes

- The push provider (FCM) is not added yet. A platform adapter will supply the token to `RegisterDevice`.
- Incoming-call alerts while the app is backgrounded need a high-priority push plus Android full-screen-intent handling; Play restricts full-screen intents. To validate.

## Pages to build

- NotificationsPage (RoutePaths.notifications)
