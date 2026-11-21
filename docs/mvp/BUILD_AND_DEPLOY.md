# Build and deployment

## Toolchain (verified on the build machine, 2026-11-21)

| Tool | Version used | Notes |
|---|---|---|
| Flutter / Dart | 3.44.x / 3.12.x | `flutter --version` |
| Melos | 8.x | `dart pub global activate melos` |
| Go | 1.25.3 | backend |
| PostgreSQL client + server | 15 (`initdb`, `pg_ctl`, `psql`) | migration validation and integration tests |
| Java | **17** for Gradle toolchains | The Stream Video plugin (`thermal`) asks for a Java 17 toolchain. `apps/mobile/android/gradle.properties` points `org.gradle.java.installations.paths` at Homebrew `openjdk@17`; change or remove that line on other machines or CI (e.g. `actions/setup-java` with 17). |
| Supabase CLI + Docker | latest | optional full local stack |

## First-time setup

```sh
./scripts/bootstrap.sh          # pub get, melos bootstrap, go mod download, copies example configs
```

## Validate everything

```sh
./scripts/validate.sh                       # format, analyze, dependency rules, Dart/Flutter tests, Go vet/race tests/build, migrations
./scripts/test-backend-integration.sh       # Go integration tests against a throwaway Postgres (as api_service)
./scripts/validate-migrations.sh            # migrations + DB invariants only (port via DASHURI_MIGRATION_PG_PORT)
```

## Run locally

```sh
# Backend
cd backend && cp .env.example .env && set -a && . ./.env && set +a && go run ./cmd/api
go run ./cmd/worker                  # lists jobs; e.g. `go run ./cmd/worker settle-stale-calls`

# Full Supabase stack (Docker)
supabase start && supabase db reset  # applies supabase/migrations
# then: alter role api_service login password '<local>'; and use it in DATABASE_URL.
# Local Supabase issues HS256 tokens: set SUPABASE_DEV_JWT_SECRET (development only; refused elsewhere).

# App
cd apps/mobile && cp config/development.example.json config/development.json   # fill in values
flutter run -t lib/main_development.dart --dart-define-from-file=config/development.json
```

## Android builds

```sh
cd apps/mobile
flutter build apk --debug -t lib/main_development.dart --dart-define-from-file=config/development.json
flutter build appbundle --release -t lib/main_production.dart --dart-define-from-file=config/production.json
```

Release builds have R8 minification and resource shrinking on, cleartext traffic and backup disabled, and keep rules for Cashfree, Stream/WebRTC and Play Integrity (`android/app/proguard-rules.pro`).

**Before the first Play upload:**
- create the upload keystore and release signing config (release currently signs with the debug key, for local testing only);
- confirm `applicationId` `com.bkenterprises.dashuri` (it can never change);
- set `DASHURI_PLAY_CLOUD_PROJECT_NUMBER` (Gradle property or env) for Play Integrity.

## Backend deployment (Cloud Run, asia-south1)

1. Build and push the distroless, non-root image: `docker build -t asia-south1-docker.pkg.dev/<project>/dashuri/api:<sha> backend`.
2. Migrations: `supabase db push` to staging, then production after review (forward-only).
3. Give `api_service` and `worker_service` LOGIN with passwords from Secret Manager.
4. Deploy the service `api` (min instances 1 in production) with every variable in `backend/.env.example`. Secrets come from Secret Manager (`infrastructure/cloudrun/`).
5. Deploy Cloud Run **jobs** from the same image with `args: ["<job>"]` plus Cloud Scheduler. Run `go run ./cmd/worker` for the authoritative list (jobs self-register in `internal/jobs`). Suggested schedules:

| Job | Schedule (IST) |
|---|---|
| `settle-stale-calls`, `mark-offline-hosts`, `moderation-missing-frames` | every minute |
| `release-bean-holds` | every 15 min |
| `poll-cashfree-orders` | every 5 min (only if Cashfree is enabled) |
| `expire-promo-diamonds` | hourly |
| `reconcile-ledger` | daily 02:00 |
| `purge-expired-idempotency` | daily 03:00 |
| `poll-voided-purchases` | daily 03:30 |

6. Webhooks: Stream → `https://<api>/v1/webhooks/video/stream`; Cashfree → `https://<api>/v1/webhooks/cashfree`; Google Play RTDN Pub/Sub push → `https://<api>/v1/webhooks/google-play/rtdn` (OIDC audience = `PLAY_RTDN_AUDIENCE`).
7. Smoke test: `/healthz`, `/readyz`, and an authenticated `GET /v1/me`.
