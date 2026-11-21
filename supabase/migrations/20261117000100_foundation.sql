-- Foundation: schemas, service roles, shared helpers.
--
-- Access model (docs/architecture/database-architecture.md):
--   * The mobile app NEVER reads or writes domain tables through PostgREST.
--     It uses Supabase only for Auth, Realtime (private channels) and Storage
--     via signed URLs issued by the Go API.
--   * The Go API connects as `api_service`; scheduled jobs as `worker_service`.
--   * Every table has RLS enabled; anon/authenticated get no grants or
--     policies on domain schemas (deny by default).

create extension if not exists pgcrypto with schema extensions;

create schema if not exists identity;
create schema if not exists economy;
create schema if not exists ledger;
create schema if not exists commerce;
create schema if not exists hosting;
create schema if not exists calls;
create schema if not exists freecall;
create schema if not exists chat;
create schema if not exists safety;
create schema if not exists moderation;
create schema if not exists payouts;
create schema if not exists notify;
create schema if not exists platform;
create schema if not exists audit;

-- Service roles (NOLOGIN here; LOGIN + password are set per environment
-- outside migrations, from Secret Manager).
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'api_service') then
    create role api_service nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'worker_service') then
    create role worker_service nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'reporting_readonly') then
    create role reporting_readonly nologin;
  end if;
end $$;

-- Clients get nothing on domain schemas.
revoke all on schema identity, economy, ledger, commerce, hosting, calls, freecall, chat,
  safety, moderation, payouts, notify, platform, audit from public;
grant usage on schema identity, economy, ledger, commerce, hosting, calls, freecall, chat,
  safety, moderation, payouts, notify, platform, audit to api_service, worker_service;
grant usage on schema ledger, commerce, payouts, economy to reporting_readonly;

-- Shared: reject UPDATE/DELETE on append-only tables.
create or replace function platform.forbid_mutation() returns trigger
language plpgsql as $$
begin
  raise exception '% on %.% is not allowed: append-only table', tg_op, tg_table_schema, tg_table_name
    using errcode = 'P0001';
end $$;

create or replace function platform.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- Idempotency keys for value-moving HTTP requests (24 h).
create table platform.idempotency_keys (
  scope         text        not null,
  key           text        not null check (length(key) between 16 and 64),
  request_hash  text        not null,
  status        integer,
  body          bytea,
  completed     boolean     not null default false,
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null,
  primary key (scope, key)
);
create index on platform.idempotency_keys (expires_at);
