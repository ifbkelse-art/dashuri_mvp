# ADR-008: Infrastructure-as-code deferred to the first staging environment

- **Status:** Accepted, 2026-11-17

## Context
No cloud resources exist yet. Writing Terraform now would encode guesses: project ids, regions, provider choices still pending.

## Decision
Ship documented templates (`infrastructure/README.md`, the Cloud Run service YAML, the Dockerfile). Introduce Terraform for GCP (Cloud Run, Scheduler, Secret Manager, Pub/Sub, Artifact Registry, IAM) when staging is created. Supabase settings stay in `supabase/config.toml` plus migrations.

## Trade-offs
The first environment is set up partly by hand; record each step and convert it to Terraform before production.
