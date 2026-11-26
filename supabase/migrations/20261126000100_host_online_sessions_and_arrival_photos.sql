-- Host online sessions and the optional arrival photo (2026-11-26).
-- Spec: docs/host/HOST_HOME_SESSION_AND_ARRIVAL_PHOTO.md.
--
-- online_sessions   one row per continuous "online" period of a host. Opened
--                   when availability goes false -> true, closed when it goes
--                   back to false (host, heartbeat job, suspension). At most
--                   one open session per host (unique partial index).
-- arrival_photos    an OPTIONAL in-app camera photo taken when the session
--                   starts. Belongs to exactly one session, is shown in
--                   discovery only while that session is open and the photo
--                   is approved, expires when the session closes and is
--                   purged from the private bucket after a retention window.
--
-- The photo is never "live video" and never identity verification: the API
-- exposes it only as "captured <time> ago".

create table hosting.online_sessions (
  id          uuid primary key default gen_random_uuid(),
  host_id     uuid not null references hosting.hosts (user_id),
  started_at  timestamptz not null default now(),
  ended_at    timestamptz,
  end_reason  text check (end_reason in ('host_offline','heartbeat_timeout','host_ineligible','superseded')),
  check ((ended_at is null) = (end_reason is null)),
  check (ended_at is null or ended_at >= started_at)
);
create unique index online_sessions_one_open on hosting.online_sessions (host_id) where ended_at is null;
create index on hosting.online_sessions (host_id, started_at desc);

-- Hosts already online when this migration runs get an open session so the
-- invariant "available => open session" holds from the start.
insert into hosting.online_sessions (host_id, started_at)
select user_id, coalesce(last_heartbeat_at, now()) from hosting.hosts where is_available;

create table hosting.arrival_photos (
  id                 uuid primary key default gen_random_uuid(),
  host_id            uuid not null references hosting.hosts (user_id),
  session_id         uuid not null references hosting.online_sessions (id),
  status             text not null default 'awaiting_upload' check (status in (
                       'awaiting_upload',  -- ticket issued, object not confirmed
                       'pending_review',   -- uploaded and validated; waiting for a moderator
                       'approved',         -- visible in discovery while the session is open
                       'rejected',         -- moderation refused it
                       'removed',          -- removed by the host or by staff
                       'expired')),        -- session ended / ticket abandoned
  content_type       text not null check (content_type = 'image/jpeg'),
  storage_path       text not null unique,
  byte_size          integer check (byte_size between 1 and 2097152),
  width              integer check (width between 240 and 4096),
  height             integer check (height between 240 and 4096),
  moderation_source  text check (moderation_source in ('classifier','staff','auto_unscanned')),
  moderation_score   numeric(4,3),
  decision_reason    text check (length(decision_reason) <= 500),
  decided_by         text,
  upload_expires_at  timestamptz not null,
  captured_at        timestamptz,          -- server time the upload was confirmed
  decided_at         timestamptz,
  ended_at           timestamptz,          -- when it stopped being current (expired/removed/rejected)
  purge_after        timestamptz,          -- object deleted from storage after this
  purged_at          timestamptz,
  created_at         timestamptz not null default now(),
  check ((status in ('awaiting_upload')) or captured_at is not null or status in ('expired','removed')),
  check (status not in ('expired','removed','rejected') or ended_at is not null)
);
-- One current (not ended) photo per session; a retake replaces the
-- previous one only after it is ended.
create unique index arrival_photos_one_current on hosting.arrival_photos (session_id)
  where status in ('awaiting_upload','pending_review','approved');
create index on hosting.arrival_photos (host_id, created_at desc);
create index arrival_photos_review_queue on hosting.arrival_photos (created_at) where status = 'pending_review';
create index arrival_photos_purge on hosting.arrival_photos (purge_after) where purged_at is null and purge_after is not null;

-- Sessions follow hosting.hosts.is_available, whoever changes it (host
-- toggle, heartbeat job, KYC rejection, moderation, account deletion), so
-- "available <=> exactly one open session" always holds. Callers may name
-- the reason with `set local dashuri.offline_reason = '...'`.
create or replace function hosting.sync_online_session() returns trigger
language plpgsql as $$
declare
  reason text := coalesce(nullif(current_setting('dashuri.offline_reason', true), ''), 'host_offline');
begin
  if tg_op = 'INSERT' then
    if new.is_available then
      insert into hosting.online_sessions (host_id) values (new.user_id);
    end if;
    return new;
  end if;
  if new.is_available and not old.is_available then
    update hosting.online_sessions set ended_at = now(), end_reason = 'superseded'
     where host_id = new.user_id and ended_at is null;
    insert into hosting.online_sessions (host_id) values (new.user_id);
  elsif old.is_available and not new.is_available then
    update hosting.online_sessions set ended_at = now(), end_reason = reason
     where host_id = new.user_id and ended_at is null;
    -- The session's photo stops being current immediately and is never
    -- reused; the object is purged after a short retention window (longer
    -- while a report about it is open; see the purge job).
    update hosting.arrival_photos
       set status = 'expired', ended_at = now(), purge_after = now() + interval '24 hours'
     where host_id = new.user_id and status in ('awaiting_upload','pending_review','approved');
  end if;
  return new;
end $$;
create trigger hosts_online_session after update of is_available on hosting.hosts
  for each row when (old.is_available is distinct from new.is_available)
  execute function hosting.sync_online_session();
create trigger hosts_online_session_insert after insert on hosting.hosts
  for each row when (new.is_available)
  execute function hosting.sync_online_session();

-- A customer report may point at the arrival photo it is about.
alter table safety.reports add column arrival_photo_id uuid references hosting.arrival_photos (id);

-- Private bucket: objects are only reachable through short-lived signed
-- URLs issued by the Go API.
insert into storage.buckets (id, name, public) values
  ('host-arrival-photos', 'host-arrival-photos', false)
on conflict (id) do nothing;

-- ---------------------------------------------------------------- access control
do $$
declare t record;
begin
  for t in select * from (values ('hosting','online_sessions'), ('hosting','arrival_photos')) as v(s, n)
  loop
    execute format('alter table %I.%I enable row level security', t.s, t.n);
    execute format('alter table %I.%I force row level security', t.s, t.n);
    execute format('create policy service_all on %I.%I for all to api_service, worker_service using (true) with check (true)', t.s, t.n);
    execute format('grant select, insert, update on %I.%I to api_service, worker_service', t.s, t.n);
    execute format('revoke all on %I.%I from anon, authenticated', t.s, t.n);
  end loop;
end $$;
