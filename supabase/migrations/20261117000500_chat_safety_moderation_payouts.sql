-- Chat, safety (blocks, reports, enforcement, appeals), moderation, payouts, audit.

create table chat.conversations (
  id          uuid primary key default gen_random_uuid(),
  user_a      uuid not null references identity.accounts (id),
  user_b      uuid not null references identity.accounts (id),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  check (user_a < user_b),                              -- canonical order → one conversation per pair
  unique (user_a, user_b)
);

create table chat.messages (
  id               uuid primary key default gen_random_uuid(),
  conversation_id  uuid not null references chat.conversations (id),
  sender_id        uuid not null references identity.accounts (id),
  body             text not null check (length(body) between 1 and 1000),
  sent_at          timestamptz not null default now(),
  removed_at       timestamptz                          -- moderation removal (soft)
);
create index on chat.messages (conversation_id, sent_at desc);

create table safety.blocks (
  blocker_id  uuid not null references identity.accounts (id),
  blocked_id  uuid not null references identity.accounts (id),
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index on safety.blocks (blocked_id);

create table safety.reports (
  id              uuid primary key default gen_random_uuid(),
  reporter_id     uuid not null references identity.accounts (id),
  target_user_id  uuid not null references identity.accounts (id),
  category        text not null check (category in ('nudity','sexual_content','minor_safety','harassment','spam_or_scam','fake_profile','other')),
  call_id         uuid references calls.calls (id),
  details         text check (length(details) <= 1000),
  status          text not null default 'open' check (status in ('open','in_review','decided','dismissed')),
  priority        smallint not null default 3,          -- 1 = minor safety / nudity
  created_at      timestamptz not null default now(),
  check (reporter_id <> target_user_id)
);
create index on safety.reports (status, priority, created_at);

create table safety.enforcement_actions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references identity.accounts (id),
  action       text not null check (action in ('warn','restrict_calls','suspend','ban','escalate_legal')),
  reason       text not null,
  report_id    uuid references safety.reports (id),
  decided_by   uuid references identity.accounts (id),
  appealable   boolean not null default true,
  created_at   timestamptz not null default now(),
  expires_at   timestamptz
);
create index on safety.enforcement_actions (user_id, created_at desc);

create table safety.appeals (
  id              uuid primary key default gen_random_uuid(),
  enforcement_id  uuid not null unique references safety.enforcement_actions (id),
  user_id         uuid not null references identity.accounts (id),
  statement       text not null check (length(statement) <= 2000),
  status          text not null default 'open' check (status in ('open','upheld','overturned')),
  decided_by      uuid references identity.accounts (id),
  decided_at      timestamptz,
  created_at      timestamptz not null default now()
);

-- Automated nudity checks (first 3 minutes of each call, founder decision S7).
create table moderation.frame_checks (
  id          bigint generated always as identity primary key,
  call_id     uuid not null references calls.calls (id),
  user_id     uuid not null references identity.accounts (id),
  checked_at  timestamptz not null,
  vendor      text not null,
  nudity      numeric(4,3),
  sexual      numeric(4,3),
  flagged     boolean not null,
  action      text check (action in ('none','end_call','queue_review'))
);
create index on moderation.frame_checks (call_id);

-- Evidence references only; blobs live in a private bucket with retention set by legal advice.
create table moderation.evidence (
  id               uuid primary key default gen_random_uuid(),
  report_id        uuid references safety.reports (id),
  call_id          uuid references calls.calls (id),
  kind             text not null check (kind in ('frame','message_snapshot','metadata')),
  storage_ref      text not null,
  created_at       timestamptz not null default now(),
  retain_until     timestamptz not null
);

create table payouts.beneficiaries (
  host_id          uuid primary key references hosting.hosts (user_id),
  provider         text not null,
  beneficiary_ref  text not null,                       -- provider token; no raw account numbers
  name_verified    boolean not null default false,
  created_at       timestamptz not null default now()
);

create table payouts.cycles (
  id                 uuid primary key default gen_random_uuid(),
  week_start         date not null unique,
  status             text not null default 'building' check (status in ('building','ready','approved','submitted','completed','failed')),
  approved_by        uuid references identity.accounts (id),
  approved_at        timestamptz,
  provider_batch_id  text unique,
  created_at         timestamptz not null default now()
);

create table payouts.withdrawals (
  id                 uuid primary key default gen_random_uuid(),
  host_id            uuid not null references hosting.hosts (user_id),
  beans              bigint not null check (beans > 0),
  amount_paise       bigint not null check (amount_paise > 0),
  tds_paise          bigint not null default 0 check (tds_paise >= 0),
  status             text not null default 'requested' check (status in ('requested','in_cycle','paid','failed','reversed')),
  cycle_id           uuid references payouts.cycles (id),
  request_entry_id   uuid not null references ledger.journal_entries (id),
  settle_entry_id    uuid references ledger.journal_entries (id),
  provider_ref       text,
  failure_code       text,
  requested_at       timestamptz not null default now(),
  paid_at            timestamptz
);
create index on payouts.withdrawals (host_id, requested_at desc);
create index on payouts.withdrawals (status) where status in ('requested','in_cycle');

-- Manual adjustments need two different approvers.
create table ledger.adjustment_proposals (
  id            uuid primary key default gen_random_uuid(),
  account_id    bigint not null references ledger.accounts (id),
  amount        bigint not null check (amount <> 0),
  reason        text not null,
  proposed_by   uuid not null references identity.accounts (id),
  approved_by   uuid references identity.accounts (id),
  status        text not null default 'awaiting_second_approval' check (status in ('awaiting_second_approval','posted','rejected')),
  entry_id      uuid references ledger.journal_entries (id),
  created_at    timestamptz not null default now(),
  check (approved_by is null or approved_by <> proposed_by)
);

-- Security-relevant audit trail (staff actions, payouts, enforcement, config).
create table audit.events (
  id          bigint generated always as identity primary key,
  at          timestamptz not null default now(),
  actor       text not null,                            -- user id, 'system:<job>', or 'provider:<name>'
  action      text not null,
  target      text,
  request_id  text,
  details     jsonb not null default '{}'::jsonb
);
create trigger audit_append_only before update or delete on audit.events
  for each row execute function platform.forbid_mutation();
