# MVP workstream rules (parallel implementation)

Several engineers (agents) work in this repo **at the same time**. These rules prevent collisions.

## Absolute rules
1. Work **only** inside `/Users/balakumaaranbharathiyar/Development/projects/dashuri_mvp`. **Never read from or write to** `/Users/balakumaaranbharathiyar/Development/projects/Dashuri` or `~/Projects/Dashuri` (the founder's original, which is read-only and the same folder via a symlink). Always `cd` into `dashuri_mvp` with an absolute path in every shell command; the shell may start in the original folder.
2. Do **not** run `git commit`, `git stash`, `git checkout`, `git reset` or `git clean`. The integrator commits.
3. Do **not** run repo-wide formatters or fixers (`dart format .`, `dart fix`, `gofmt -w .`). Format only the files you own (`dart format <your paths>`, `gofmt -w <your files>`).
4. Do **not** add new pub or Go dependencies. The needed SDKs are already present (`stream_video_flutter`, `in_app_purchase`, `flutter_cashfree_pg_sdk`, `geolocator`, `permission_handler`, `google_fonts`; Go: `pgx`, `golang-jwt/jwt/v5`, `keyfunc`). Standard library and existing deps only. If something is truly impossible without a dependency, say so in your final report.
5. Edit only the files and directories your workstream owns (listed in your task). For any other shared file, **append only** where explicitly allowed, and re-read the file immediately before editing.
6. No fake success: no hardcoded successful API responses, no placeholder screens, no dead buttons. If an integration needs credentials, implement it fully against the real API and fail with a clear, user-facing "not configured" error when credentials are absent.
7. Never put secrets in client code. The app receives only short-lived tokens or session ids from the Go API.

## Product source of truth
- `docs/mvp/MVP_DECISIONS_AND_CONTRACT.md`: founder decisions and **API contract additions**. Follow it exactly so the backend and the app agree.
- `api/openapi/dashuri.v1.yaml`: the existing API contract (read the schemas for your endpoints).
- `docs/architecture/*.md`: architecture, ledger, video-call, security and dependency rules.
- Design: `design/Dashuri_Design/<Folder>/<ID>_*.png` (view the PNGs with your image-reading tool) and the HTML sources in `design/_build/s_*.js` (screen copy, notes and states).

## Backend conventions (Go, `backend/`)
- Module layout: `internal/modules/<m>/{dto.go, http.go, service.go, ports.go, module.go}`. Keep handlers thin.
- Postgres implementations of a module's `Repository` port live in `internal/adapters/postgres/<module>_repo.go`. Vendor HTTP clients live in `internal/adapters/<vendor>/`.
- Build the module in `internal/app/wire_<module>.go` from `wiring.Env` (Pool, Tx, Rules, Clock, Realtime, Config, HTTP). You own your modules' wire files.
- Money: use only `ledger` templates and `postgres.PostEntry(ctx, tx, entry)` inside a transaction (`env.Tx.WithTx`). Lock balances with `postgres.LockUserBalances` (ascending order). Never update balances directly.
- When `env.Pool == nil`, return `apperr.Unavailable("database_unavailable", …)`; never panic.
- Errors: `apperr.BusinessRule(rule, detail)` for 409s with the rule names from `docs/architecture/api-contracts.md` and the MVP contract.
- Scheduled jobs: add a file in `internal/jobs/` that calls `jobs.Register` in `init()`.
- Tests: unit tests (`go test ./...`) plus **integration tests** with build tag `integration` using `internal/testsupport/pgtest` (`pgtest.Pools`, `pgtest.NewUser`). Run them with `./scripts/test-backend-integration.sh ./internal/<your packages>/...` (it starts a throwaway Postgres with all migrations and connects as `api_service`). Use a **different** `DASHURI_TEST_PG_PORT` per workstream to avoid clashes: BE-identity 55441, BE-calls 55442, BE-money 55443.
- Schema changes: add a new migration file `supabase/migrations/2026112100<NN>00_<area>.sql` using **your assigned number range** (BE-identity 02xx, BE-calls 03xx, BE-money 04xx; e.g. `20261121000210_identity_extras.sql`). Enable and force RLS, add the `service_all` policy, grant to `api_service` and `worker_service`, and revoke from `anon` and `authenticated` for every new table (copy the loop at the end of `20261121000100_mvp_foundation.sql`). Validate with `./scripts/validate-migrations.sh`.
- Run `gofmt -l`, `go vet ./...` and `go build ./...` before finishing.

## Flutter conventions (`apps/mobile`, `packages/`)
- Read `docs/architecture/flutter-architecture.md` and `dependency-rules.md` (enforced by `dart run tool/check_dependencies.dart`). Features never import other features; navigate with `RoutePaths` constants (`packages/navigation/lib/src/route_paths.dart`; screen ids are in comments).
- Layers: domain (entities, repository interfaces, use cases) → data (models, remote data sources using `ApiClient`, repository impl) → application (Cubit/Bloc with sealed states) → presentation (pages and widgets). DI in `di/<f>_module.dart`; routes in `routes/<f>_routes.dart` (route builders create BLoCs with `GetIt.instance`).
- UI: use `package:dashuri_design_system` (tokens, `DashuriTheme`, `ResponsiveCenter`, `TwoPane`, `context.windowSize`, `context.pageGutter`, `context.gridColumns`, `BalancePill`, `CurrencyAmount`, `StatusTag`, `UserAvatar`, `EmptyStateView`, `ErrorStateView`, `LoadingView`, `PrimaryButton`, `showConfirmDialog`, `DashuriFormat`, `DiamondIcon`, `BeanIcon`). You may **add** new component files under `packages/design_system/lib/src/components/<your_area>_*.dart` and export them by appending a line to `lib/dashuri_design_system.dart`; do not modify existing design-system files.
- **Responsive is required.** Every page must work at 360×640, 390×844, 600×960 (foldable), 1024×768 and 1280×800: no overflow, readable widths (`ResponsiveCenter` for single-column content), adaptive grids (`context.gridColumns`), two-pane on expanded windows where it helps (inbox + conversation), text scaling up to 1.3×, and safe areas. Use `LayoutBuilder` and `Flexible`/`Expanded`, not fixed heights.
- Every page handles loading, empty, error (with retry) and success states. Map `BusinessRuleFailure.code` to plain-language copy from the designs.
- Tests: BLoC tests (`bloc_test` + `mocktail`), repository/model tests, and **widget tests per page** (at least loaded and error states) at a phone size and a tablet size. In widget tests set `DashuriText.useGoogleFonts = false` (no network).
- Run `dart analyze --fatal-infos <your packages>`, `flutter test` in your packages and `dart run tool/check_dependencies.dart` before finishing. Format only your files.

## Final report (keep it under 400 words)
Files and areas changed; endpoints and screens implemented; tests added and their **actual** pass/fail output; anything not finished; anything needing real credentials; any change you need from another workstream or from shared files.
- Migration validation: set `DASHURI_MIGRATION_PG_PORT` to your test port + 100 (e.g. 55541) when running `./scripts/validate-migrations.sh`.
