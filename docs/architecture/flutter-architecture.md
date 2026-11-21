# Flutter architecture

Melos 8 monorepo on pub workspaces, Clean Architecture per feature package, BLoC for state, `get_it` for dependency injection, `go_router` for navigation, Material 3. Android first; the iOS project exists but is not built or released (R3-2).

## Packages

| Package | Kind | Responsibility | Public interface |
|---|---|---|---|
| `dashuri_lints` | Dart | Analysis rules for every package | `analysis_options.yaml` |
| `dashuri_core` | pure Dart | `Result`/`Success`/`Err`, sealed `Failure`s, `UseCase`/`StreamUseCase`, `Diamonds`/`Beans`/`Paise` unit types, `Page`/`PageRequest`, `AppConfig`, `Clock`, `AppLogger`, `AnalyticsSink`, `SessionGateway` + `AuthSession`, `IdempotencyKey` | `package:dashuri_core/dashuri_core.dart` |
| `dashuri_network` | Dart | `ApiClient` (bearer token, request id, Idempotency-Key, problem+json → `Failure`, never throws), page and object decoders, `AccessTokenProvider`, `RealtimeGateway` + `RealtimeEvent` | `dashuri_network.dart` |
| `dashuri_supabase` | Flutter | Supabase Auth → `SessionGateway`/`AccessTokenProvider`; Supabase Realtime private channels → `RealtimeGateway`; `initSupabase` | used only by `apps/mobile` DI |
| `dashuri_storage` | Flutter | `KeyValueStore`, `SecureKeyValueStore` | |
| `dashuri_navigation` | Flutter | `RoutePaths`, `FeatureRoutes`, `RouteGuard`; re-exports go_router | |
| `dashuri_design_system` | Flutter | `DashuriTokens` (placeholders), `DashuriTheme` (M3), `components/` | |
| `feature_*` (12) | Flutter | One product area each (table below) | `feature_x.dart` barrel |
| `apps/mobile` | Flutter app | Bootstrap, DI composition, router composition, route guard. **No pages, no business logic.** | |

### Feature boundaries

The brief's 16 candidate modules were reviewed; 12 were kept.

| Feature | Responsibility | Main BLoC | Notes |
|---|---|---|---|
| `auth` | Phone OTP, session, account status | `SessionCubit` (app-wide), `SignInCubit` | Eligibility comes from `GET /v1/me` |
| `profile` | Own/public profile, photos, shared level and XP display | `MyProfileCubit` | Absorbs **levels** (display only; XP is server-side) |
| `discovery` | Browse online hosts and their rates | `DiscoveryCubit` | |
| `free_call` | Free Call Card | `FreeCallCardCubit` | Replaces **matchmaking**: random matching exists only for this card (S4). Hidden on iOS. |
| `video_call` | Request, ring, accept, media, end; server billing display | `CallBloc` | `VideoEngine` port; Stream adapter TODO |
| `chat` | Conversations, messages, messaging privacy | `ConversationsCubit` | |
| `wallet` | Diamond and Bean balances, ledger history (read-only) | `WalletCubit` | |
| `purchases` | Diamond packs via Play Billing + server verification | `PurchaseBloc` | Was **payments**; renamed because payouts are separate |
| `host` | Host application, KYC, availability, rate, Free Call opt-in, earnings, withdrawals | `HostDashboardCubit` | Absorbs host-side **payments** (withdrawals) |
| `safety` | Report, block, age gate, enforcement notices, appeals | `BlockedUsersCubit` | Absorbs user-facing **moderation**. Moderator tooling is backend/admin only. |
| `notifications` | Push registration, inbox | `InboxCubit` | |
| `settings` | Consents, account deletion, data export (DPDP) | `SettingsCubit` | |

Not created, with reasons:
- **customer:** the customer experience is spread over discovery, wallet, purchases and video_call. A separate package would be empty.
- **matchmaking:** covered by `free_call`.
- **levels:** shown in `profile` and computed by the backend.
- **moderation (mobile):** no moderator UI in the app.
- **location:** no founder decision requires location. It would add DPDP and Play data-safety obligations. Add it later with `melos run new:feature -- location` if a decision needs it.
- **dependency_injection, configuration, logging, analytics, utilities, common_widgets** as separate packages: the contracts live in `dashuri_core`, wiring lives in the app, and widgets live in `design_system/components`. Separate micro-packages would add friction without adding boundaries.

## Layers inside a feature

```text
packages/features/<name>/
├── lib/
│   ├── feature_<name>.dart            # public barrel: entities, contracts, use cases, BLoCs, DI, routes
│   └── src/
│       ├── domain/
│       │   ├── entities/              # immutable Equatable classes
│       │   ├── repositories/          # abstract interface class XRepository
│       │   ├── usecases/              # one class per action, returns Result<T>
│       │   └── ports/                 # (when needed) provider-neutral interfaces, e.g. VideoEngine
│       ├── data/
│       │   ├── models/                # JSON ↔ entity mappers (snake_case wire format)
│       │   ├── datasources/           # XRemoteDataSource (ApiClient), store/video adapters
│       │   └── repositories/          # XRepositoryImpl
│       ├── application/               # BLoCs/Cubits + states (+ events)
│       ├── presentation/
│       │   ├── pages/                 # FOUNDER-OWNED (README lists planned pages)
│       │   └── widgets/
│       ├── di/<name>_module.dart      # registerXFeature(GetIt)
│       └── routes/<name>_routes.dart  # XRoutes implements FeatureRoutes
└── test/
    ├── application/                   # bloc_test + mocktail
    └── domain/
```

## Conventions

### Results and errors
- Repositories and use cases return `Result<T>`, never throw. `ApiClient` converts transport, HTTP and decoding errors into `Failure`s.
- BLoCs `switch` on `Success`/`Err`. Pages branch on `Failure` subtypes: `BusinessRuleFailure.code` (e.g. `insufficient_diamonds`) drives specific messages, and `UnexpectedFailure` means a bug to report.

### BLoC
- Use a **Cubit** for request/response screens and a **Bloc** when there are several event sources (realtime, store streams, media), as in `CallBloc` and `PurchaseBloc`.
- States are sealed classes (`Initial`/`Loading`/`Loaded`/`Failed`) or one immutable state with a status enum when fields accumulate (call, purchase, sign-in).
- One BLoC per page or flow, provided at the route with `BlocProvider(create: (_) => sl<X>())`. App-wide state (`SessionCubit`) is a singleton provided above the router.
- BLoCs never touch `ApiClient`, Supabase or SDKs.

### Idempotency
Value-moving and create actions take an `IdempotencyKey` in the use-case input. The BLoC creates **one key per user intent** and reuses it for retries. Examples: `CallBloc` keeps `_requestKey` and `_endKey`; `PurchaseBloc` keys by purchase token. Never generate a new key on retry.

### Dependency injection
- `GetIt sl` lives only in `apps/mobile/lib/app/di/injector.dart`. Each feature exports `registerXFeature(GetIt sl)`.
- Data sources and repositories are lazy singletons; use cases and BLoCs are factories.
- Platform adapters (Supabase, storage, ApiClient) are registered before features.
- Pages never call `GetIt`. Route builders create BLoCs.

### Navigation
- Paths live in `RoutePaths`. Each feature returns `List<RouteBase>` from `XRoutes`, and `buildRouter` concatenates them.
- The `SessionRouteGuard` redirect rules are: unknown → splash, signed out → sign-in, not 18+ → age gate. Enable the guard in `app_router.dart` once those three pages exist.

### Loading, pagination, realtime
- **Loading:** a `Loading` state; pages show skeletons or spinners from the design system.
- **Pagination:** cursor-based. Cubits keep `Page.items` + `nextCursor` and request `PageRequest(cursor: next)`. Generated cubits load the first page; add `loadMore()` when building the page.
- **Realtime:** `RealtimeGateway.subscribe('user:<id>' | 'call:<id>')` events are hints. On a hint, re-fetch from the API (source of truth). Subscriptions are owned by BLoCs and cancelled in `close()`.

## Adding a feature

```sh
melos run new:feature -- gifts      # or: dart run tool/new_feature.dart gifts
```

Then follow the printed steps: add it to the root `workspace:` list and to the app `pubspec.yaml`, call `registerGiftsFeature(sl)` in `injector.dart`, and add `GiftsRoutes()` in `app_router.dart`. Finish with `dart pub get && melos run analyze && melos run deps:check`.
