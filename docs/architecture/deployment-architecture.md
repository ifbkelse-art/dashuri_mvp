# Deployment architecture

## Targets

| Piece | Runtime | Region |
|---|---|---|
| Go API | Cloud Run service `api` (min 1 instance in production for incoming-call latency) | `asia-south1` (Mumbai) |
| Jobs | Cloud Run jobs from the same image (`/app/worker <job>`) + Cloud Scheduler | `asia-south1` |
| Database, Auth, Realtime, Storage | Supabase project per environment | Mumbai (`ap-south-1`) |
| Android app | Google Play: internal → closed → production tracks, on the existing BK Enterprises account (S10) | — |

Details and templates are in `infrastructure/`.

## Environments

Three environments: development (local Supabase via `supabase start`, `go run ./cmd/api`), staging, and production. Each has its own GCP project, Supabase project, secrets and Play track. Production data is never copied to lower environments.

## CI/CD (to set up)

1. **On every pull request:** `scripts/validate.sh` (format, analyze, dependency rules, Dart and Flutter tests, Go vet, race tests and build, migration validation), plus an OpenAPI linter.
2. **On merge to main:**
   - build the image and push it to Artifact Registry;
   - `supabase db push` to staging;
   - deploy the Cloud Run revision to staging;
   - run smoke tests (`/readyz`, an authenticated `GET /v1/me`).
3. **Production:** manual approval, then the same steps against production. Roll back by routing traffic to the previous revision; database migrations stay forward-only and backward-compatible for one release.
4. **App:** build the AAB with `--dart-define-from-file=config/production.json`, sign it with Play App Signing, and upload to the internal track.

## Release prerequisites (from the business model, not code)

- [ ] Applicant/application id `com.bkenterprises.dashuri` confirmed. It cannot change after the first upload.
- [ ] Decide whether Dashuri should use a separate Play developer account to isolate Route (business-model report, Part C1.3).
- [ ] Play Console: target audience 18+, minor-blocking tools (random chat, from 26 Aug 2026), Child Safety Standards, data-safety form, UGC policy compliance.
- [ ] Payout provider written acceptance; incorporation before `PAYOUTS_ENABLED=true`.
- [ ] CA opinion (GST principal or agent, TDS section), lawyer opinion (IT Act and IT Rules, moderation model, DPDP retention).
- [ ] Video provider validated (ADR-005 checklist).
