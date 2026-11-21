# Dashuri

A paid one-to-one video marketplace for India (Android first). This repository holds the engineering foundation: a Flutter monorepo, a Go backend, Supabase migrations, the API contract and architecture docs. Production features are **not implemented yet**. Server operations return `501`, and client integrations (Play Billing, video) are documented skeletons.

## Start here

| You want to… | Read |
|---|---|
| Understand the system | `docs/architecture/architecture-overview.md` |
| Build pages | `docs/architecture/page-integration-guide.md` |
| Know the business rules | `docs/business-model-report.md` (v0.3, Part C has the latest founder decisions) and `docs/discovery-log.md` |
| See the money model | `docs/architecture/financial-ledger-design.md` |
| See the API | `api/openapi/dashuri.v1.yaml`, `docs/architecture/api-contracts.md` |

## Requirements

Flutter 3.35+ (tested with 3.44.8 / Dart 3.12.2), Melos 8 (`dart pub global activate melos`), Go 1.25, Supabase CLI. Postgres client tools (`initdb`, `pg_ctl`, `psql`) are needed for migration validation; Docker is needed for `supabase start`.

## Commands

```sh
./scripts/bootstrap.sh            # dependencies, example configs
./scripts/validate.sh             # format, analyze, dependency rules, all tests, Go build, migrations

melos run analyze                 # dart analyze --fatal-infos in every package
melos run test                    # Dart + Flutter tests
melos run deps:check              # architecture dependency rules
melos run new:feature -- <name>   # scaffold a feature package

cd apps/mobile && flutter run -t lib/main_development.dart --dart-define-from-file=config/development.json
cd backend && go run ./cmd/api    # API on :8080 (/healthz)
cd backend && go run ./cmd/worker # lists scheduled jobs
supabase start && supabase db reset   # full local Supabase with migrations (Docker)
```

## Layout

```text
apps/mobile/            Flutter app (composition root: bootstrap, DI, router; no pages yet)
packages/               core, network, supabase, storage, navigation, design_system, lints
packages/features/      auth, profile, discovery, free_call, video_call, chat, wallet,
                        purchases, host, safety, notifications, settings
backend/                Go modular monolith (cmd/api, cmd/worker, internal/...)
api/openapi/            API contract (OpenAPI 3.1)
supabase/               config, migrations, database tests
infrastructure/         Cloud Run templates and environment plan
scripts/, tool/         bootstrap/validate scripts, dependency checker, feature scaffolder
simulation/             six-month financial simulation (dashboard + engine)
docs/                   business model, discovery log, simulation reports, architecture + ADRs
```
