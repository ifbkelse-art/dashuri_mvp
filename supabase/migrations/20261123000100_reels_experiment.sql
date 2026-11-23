-- EXPERIMENT: Dashuri Reels (short videos, creators, follows, likes) — not
-- approved for permanent inclusion. Everything lives in the separate `reels`
-- schema so the experiment can be removed without touching existing tables:
-- see docs/reels/experiment/README.md (drop script) and
-- docs/reels/DASHURI_REELS_DATABASE_AND_API.md.
--
-- Existing tables are only referenced (identity.accounts, hosting.hosts and
-- safety.blocks are read by the API); none is altered.
--
-- Publication rule (fail closed): a video can only become `published` when
-- its latest moderation decision is `approve`. The trigger below enforces
-- this in the database, so no code path can publish unmoderated content.

create schema if not exists reels;
revoke all on schema reels from public;
grant usage on schema reels to api_service, worker_service;

-- ---------------------------------------------------------------- creators
-- Any 18+ active account can be a creator. Host status is NOT stored here:
-- paid-call privileges stay with hosting.hosts (approved + KYC).
create table reels.creator_profiles (
  user_id     uuid primary key references identity.accounts (id),
  bio         text check (length(bio) <= 300),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create trigger creator_profiles_touch before update on reels.creator_profiles
  for each row execute function platform.touch_updated_at();

-- ---------------------------------------------------------------- videos
-- One row per uploaded reel; provider ids are the only link to the media.
create table reels.videos (
  id                    uuid primary key default gen_random_uuid(),
  creator_id            uuid not null references identity.accounts (id),
  caption               text not null default '' check (length(caption) <= 300),
  language              text check (language ~ '^[a-z]{2}$'),
  declared_duration_ms  integer not null check (declared_duration_ms between 15000 and 60000),
  duration_ms           integer check (duration_ms between 1 and 61000),   -- reported by the provider
  status                text not null default 'awaiting_upload' check (status in (
                          'awaiting_upload',     -- upload URL issued, no file yet
                          'processing',          -- provider received the file and is transcoding
                          'pending_moderation',  -- ready; automated check not finished (or provider outage)
                          'in_review',           -- automated check uncertain/unavailable: human queue
                          'published',           -- approved; visible in feeds
                          'rejected',            -- moderation refused publication
                          'removed',             -- taken down after publication
                          'failed',              -- provider could not process the file
                          'deleted')),           -- deleted by the creator or account deletion
  rejection_code        text,                  -- user-facing reason code for rejected/removed/failed
  provider              text not null,
  provider_upload_id    text unique,
  provider_asset_id     text unique,
  playback_id           text,
  aspect_ratio          text,
  like_count            integer not null default 0 check (like_count >= 0),
  view_count            integer not null default 0 check (view_count >= 0),
  completed_count       integer not null default 0 check (completed_count >= 0),
  share_count           integer not null default 0 check (share_count >= 0),
  evidence_hold_until   timestamptz,           -- media kept for review evidence until then
  media_purged_at       timestamptz,           -- provider asset deleted
  published_at          timestamptz,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz,
  check (status <> 'published' or published_at is not null),
  check (status <> 'deleted' or deleted_at is not null)
);
create trigger videos_touch before update on reels.videos
  for each row execute function platform.touch_updated_at();
-- Feed queries: newest published first, per creator, and the moderation queue.
create index reels_videos_published on reels.videos (published_at desc, id desc) where status = 'published';
create index reels_videos_by_creator on reels.videos (creator_id, created_at desc, id desc);
create index reels_videos_pending on reels.videos (status, updated_at) where status in ('processing','pending_moderation','in_review');
create index reels_videos_purge on reels.videos (status) where media_purged_at is null and status in ('deleted','rejected','removed','failed');

-- ---------------------------------------------------------------- moderation
-- A case is opened for every video that needs a decision (automated result
-- uncertain or unavailable, a user report, or an appeal).
create table reels.moderation_cases (
  id                uuid primary key default gen_random_uuid(),
  video_id          uuid not null references reels.videos (id),
  source            text not null check (source in ('automated','report','appeal','provider_unavailable')),
  status            text not null default 'open' check (status in ('open','decided')),
  priority          smallint not null default 3 check (priority between 1 and 5),  -- 1 = minor safety / nudity
  automated_scores  jsonb,           -- classifier maxima only; no media
  created_at        timestamptz not null default now(),
  decided_at        timestamptz
);
create unique index reels_one_open_case on reels.moderation_cases (video_id) where status = 'open';
create index reels_cases_queue on reels.moderation_cases (status, priority, created_at) where status = 'open';

-- Every automated or human decision, append-only (audit trail).
create table reels.moderation_decisions (
  id           uuid primary key default gen_random_uuid(),
  video_id     uuid not null references reels.videos (id),
  case_id      uuid references reels.moderation_cases (id),
  decision     text not null check (decision in ('approve','reject','remove','restore')),
  reason_code  text not null check (length(reason_code) between 1 and 60),
  note         text check (length(note) <= 2000),
  source       text not null check (source in ('automated','moderator')),
  decided_by   uuid references identity.accounts (id),
  created_at   timestamptz not null default clock_timestamp(),
  check ((source = 'moderator') = (decided_by is not null))
);
create index reels_decisions_by_video on reels.moderation_decisions (video_id, created_at desc);
create trigger reels_decisions_append_only before update or delete on reels.moderation_decisions
  for each row execute function platform.forbid_mutation();

-- Fail closed: publication needs an approving latest decision.
create or replace function reels.guard_publication() returns trigger
language plpgsql set search_path = '' as $$
declare latest text;
begin
  if tg_op = 'INSERT' then
    if new.status <> 'awaiting_upload' then
      raise exception 'reels: new videos start as awaiting_upload' using errcode = '23514';
    end if;
    return new;
  end if;
  if new.status = 'published' and old.status is distinct from 'published' then
    select d.decision into latest from reels.moderation_decisions d
     where d.video_id = new.id order by d.created_at desc, d.id desc limit 1;
    if latest is distinct from 'approve' and latest is distinct from 'restore' then
      raise exception 'reels: video % cannot be published without an approving moderation decision', new.id
        using errcode = '23514';
    end if;
  end if;
  if old.status = 'deleted' and new.status <> 'deleted' then
    raise exception 'reels: deleted videos cannot be revived' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger videos_guard_publication before insert or update on reels.videos
  for each row execute function reels.guard_publication();

-- ---------------------------------------------------------------- engagement
create table reels.likes (
  user_id     uuid not null references identity.accounts (id),
  video_id    uuid not null references reels.videos (id),
  created_at  timestamptz not null default now(),
  primary key (video_id, user_id)
);
create index reels_likes_by_user on reels.likes (user_id, created_at desc);

create table reels.follows (
  follower_id  uuid not null references identity.accounts (id),
  creator_id   uuid not null references identity.accounts (id),
  created_at   timestamptz not null default now(),
  primary key (follower_id, creator_id),
  check (follower_id <> creator_id)
);
create index reels_follows_by_creator on reels.follows (creator_id);

-- One row per viewer, video and day: idempotent view counting and the
-- "already seen" signal for the feed.
create table reels.views (
  video_id     uuid not null references reels.videos (id),
  viewer_id    uuid not null references identity.accounts (id),
  day          date not null,
  watched_ms   integer not null default 0 check (watched_ms >= 0),
  completed    boolean not null default false,
  updated_at   timestamptz not null default now(),
  primary key (video_id, viewer_id, day)
);
create index reels_views_by_viewer on reels.views (viewer_id, day desc);

create table reels.reports (
  id           uuid primary key default gen_random_uuid(),
  video_id     uuid not null references reels.videos (id),
  reporter_id  uuid not null references identity.accounts (id),
  category     text not null check (category in ('nudity','sexual_content','minor_safety','harassment',
                 'violence','hate','spam_or_scam','copyright','privacy','other')),
  details      text check (length(details) <= 1000),
  created_at   timestamptz not null default now(),
  unique (video_id, reporter_id)
);
create index reels_reports_by_video on reels.reports (video_id);

create table reels.appeals (
  id           uuid primary key default gen_random_uuid(),
  video_id     uuid not null unique references reels.videos (id),
  creator_id   uuid not null references identity.accounts (id),
  statement    text not null check (length(statement) between 1 and 2000),
  status       text not null default 'open' check (status in ('open','upheld','overturned')),
  decided_by   uuid references identity.accounts (id),
  decided_at   timestamptz,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------- analytics
-- Product events only: ids, event names and durations. No captions, no
-- free text, no device data.
create table reels.feed_events (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references identity.accounts (id),
  event       text not null check (event in ('reel_impression','reel_play_started','reel_play_completed',
                'reel_watch_duration','reel_liked','creator_followed','creator_profile_opened','reel_shared',
                'reel_reported','host_call_cta_clicked')),
  video_id    uuid references reels.videos (id),
  creator_id  uuid references identity.accounts (id),
  value_ms    integer check (value_ms between 0 and 600000),
  session_id  text check (length(session_id) <= 64),
  created_at  timestamptz not null default now()
);
create index reels_events_by_type on reels.feed_events (event, created_at);
create index reels_events_cta on reels.feed_events (user_id, creator_id, created_at) where event = 'host_call_cta_clicked';

-- Provider webhook deliveries (dedupe only; payload not kept).
create table reels.provider_webhooks (
  delivery_hash  text primary key,
  provider       text not null,
  event_type     text not null,
  received_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------- access control
-- Only the API and worker roles can read or write; clients (anon,
-- authenticated) have no access, so unapproved videos are never reachable
-- through PostgREST or Realtime.
do $$
declare t record;
begin
  for t in select * from (values
      ('reels','creator_profiles'), ('reels','videos'), ('reels','moderation_cases'),
      ('reels','moderation_decisions'), ('reels','likes'), ('reels','follows'), ('reels','views'),
      ('reels','reports'), ('reels','appeals'), ('reels','feed_events'), ('reels','provider_webhooks')) as v(s, n)
  loop
    execute format('alter table %I.%I enable row level security', t.s, t.n);
    execute format('alter table %I.%I force row level security', t.s, t.n);
    execute format('create policy service_all on %I.%I for all to api_service, worker_service using (true) with check (true)', t.s, t.n);
    execute format('grant select, insert, update, delete on %I.%I to api_service, worker_service', t.s, t.n);
    execute format('revoke all on %I.%I from anon, authenticated', t.s, t.n);
  end loop;
end $$;
grant usage on sequence reels.feed_events_id_seq to api_service, worker_service;
-- Decisions are append-only even for the service roles.
revoke update, delete on reels.moderation_decisions from api_service, worker_service;
