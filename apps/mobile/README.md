# dashuri_mobile

The Android app (iOS project present but not released; R3-2). This package is the **composition root only**:

| File | Purpose |
|---|---|
| `lib/main_{development,staging,production}.dart` | Entry points per environment |
| `lib/bootstrap/bootstrap.dart` | Error hooks, BLoC observer, config, DI, `runApp` |
| `lib/app/di/injector.dart` | Registers platform adapters and every feature (`register…Feature`) |
| `lib/app/router/app_router.dart` | Composes feature routes into one `GoRouter` |
| `lib/app/router/session_route_guard.dart` | Signed-out → sign-in; not 18+ → age gate (enable once those pages exist) |
| `lib/app/app.dart` | `MaterialApp.router` with the design-system theme |
| `config/*.example.json` | Client-safe configuration (copy to `*.json`, git-ignored) |

Pages live in their feature packages; see `docs/architecture/page-integration-guide.md`.

Run: `flutter run -t lib/main_development.dart --dart-define-from-file=config/development.json`. Without a config file, development builds start with every backend call failing as `backend_not_configured`; staging and production refuse to start.

**Application id:** `com.bkenterprises.dashuri`. Confirm it before the first Play upload; it can never change.
