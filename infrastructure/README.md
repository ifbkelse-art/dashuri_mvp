# Infrastructure

Nothing here is provisioned yet. These are the intended layout and templates. Infrastructure-as-code (Terraform) is deferred until the first staging environment is created; see ADR-008.

## Environments

| | development | staging | production |
|---|---|---|---|
| GCP project | `dashuri-dev` | `dashuri-staging` | `dashuri-prod` |
| Supabase project | local (`supabase start`) | separate project | separate project, Mumbai region |
| Cloud Run region | — | `asia-south1` (Mumbai) | `asia-south1` |
| Payouts | off | off | off until R3-7 is satisfied |

Project ids are placeholders. Keep the database and the API in the same region (India) for latency and data-residency reasons; legal review of data residency is still pending.

## Google Cloud components

| Component | Purpose |
|---|---|
| Cloud Run service `api` | Go API (`backend/cmd/api`). Min instances 1 in production so incoming-call requests are not delayed by cold starts. |
| Cloud Run jobs `worker-*` | `backend/cmd/worker <job>`, one job per schedule |
| Cloud Scheduler | Triggers the jobs (schedules listed in `backend/cmd/worker`) |
| Artifact Registry | Container images (one image, two entry points) |
| Secret Manager | `DATABASE_URL` (api_service role), Play service-account JSON, Stream secret, Realtime server key, payout-provider credentials |
| Pub/Sub topic `play-rtdn` | Google Play Real-Time Developer Notifications → push subscription to `/v1/webhooks/google-play/rtdn` with OIDC auth |
| Cloud Armor + external HTTPS load balancer | WAF and IP rate limiting in front of the API (recommended before launch) |
| Cloud Logging / Monitoring / Error Reporting | Logs are structured JSON with `severity` |

## Deploy (manual, until CI exists)

```sh
cd backend
gcloud builds submit --tag asia-south1-docker.pkg.dev/$PROJECT/dashuri/api:$(git rev-parse --short HEAD)
gcloud run services replace ../infrastructure/cloudrun/api.service.yaml --region asia-south1
```

Database changes ship only as migrations: `supabase db push` against the target project, reviewed in a pull request. Never edit production schemas by hand.
