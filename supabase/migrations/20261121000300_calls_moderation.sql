-- BE-calls (2026-11-21): calls, Free Call Card, hosts, moderation (S7).
-- See docs/mvp/api/calls_hosts_moderation.md.

-- ---------------------------------------------------------------- calls
alter table calls.calls
  add column low_balance_notified_at timestamptz,
  add column free_call_compensated   boolean not null default false;
create index calls_live_phase on calls.calls (phase, created_at)
  where phase in ('requested','ringing','accepted','connecting','active','paused','ending');
create index calls_moderation_window on calls.calls (moderation_window_ends_at)
  where moderation_window_ends_at is not null;

-- ---------------------------------------------------------------- safety
-- Automated cases (nudity classifier, missing frames) have no human reporter.
alter table safety.reports
  alter column reporter_id drop not null,
  add column source           text not null default 'user' check (source in ('user','automated')),
  add column automated_reason text,
  add constraint reports_reporter_matches_source check (source = 'automated' or reporter_id is not null);
-- One automated case per (call, target, reason): job reruns never duplicate.
create unique index reports_one_automated_case on safety.reports (call_id, target_user_id, automated_reason)
  where source = 'automated';

-- ---------------------------------------------------------------- moderation
-- Every staff decision on a report or appeal (ModerationDecision.decision_id).
create table moderation.decisions (
  id              uuid primary key default gen_random_uuid(),
  report_id       uuid references safety.reports (id),
  appeal_id       uuid references safety.appeals (id),
  action          text not null,
  reason          text not null check (length(reason) <= 2000),
  enforcement_id  uuid references safety.enforcement_actions (id),
  decided_by      uuid not null references identity.accounts (id),
  created_at      timestamptz not null default now(),
  check ((report_id is null) <> (appeal_id is null))
);
create index on moderation.decisions (report_id);
create trigger decisions_append_only before update or delete on moderation.decisions
  for each row execute function platform.forbid_mutation();

-- ---------------------------------------------------------------- free call
create table freecall.requests (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references identity.accounts (id),
  status      text not null check (status in ('searching','matched','no_host_available','cancelled')),
  call_id     uuid unique references calls.calls (id),
  host_id     uuid references identity.accounts (id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index on freecall.requests (user_id, created_at desc);
create trigger freecall_requests_touch before update on freecall.requests
  for each row execute function platform.touch_updated_at();

-- The phone number stays in auth.users (Supabase Auth). The Free Call Card
-- needs only its SHA-256 (one card per phone), computed inside the database
-- so the number never reaches the API.
create or replace function freecall.phone_hash(p_user_id uuid) returns text
language plpgsql stable security definer set search_path = '' as $$
declare
  v text;
begin
  execute 'select phone::text from auth.users where id = $1' into v using p_user_id;
  if v is null or v = '' then
    return null;
  end if;
  return encode(sha256(convert_to(v, 'UTF8')), 'hex');
exception when undefined_column then
  return null;
end $$;
revoke all on function freecall.phone_hash(uuid) from public;
grant execute on function freecall.phone_hash(uuid) to api_service, worker_service;

-- ---------------------------------------------------------------- hosting
create index on hosting.kyc_sessions (host_id, created_at desc);

-- ---------------------------------------------------------------- access control for new tables
do $$
declare t record;
begin
  for t in select * from (values ('moderation','decisions'), ('freecall','requests')) as v(s, n)
  loop
    execute format('alter table %I.%I enable row level security', t.s, t.n);
    execute format('alter table %I.%I force row level security', t.s, t.n);
    execute format('create policy service_all on %I.%I for all to api_service, worker_service using (true) with check (true)', t.s, t.n);
    execute format('grant select, insert, update, delete on %I.%I to api_service, worker_service', t.s, t.n);
    execute format('revoke all on %I.%I from anon, authenticated', t.s, t.n);
  end loop;
end $$;
revoke update, delete on moderation.decisions from api_service, worker_service;
