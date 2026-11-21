-- Purchases, hosts, Free Call Card, calls.

create table commerce.purchases (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null references identity.accounts (id),
  product_id          text not null references economy.diamond_packages (product_id),
  purchase_token_hash text not null unique,            -- sha256 of the Play token; token itself is not stored
  order_id            text unique,
  state               text not null check (state in ('pending','credited','rejected','reversed')),
  diamonds            bigint not null check (diamonds > 0),
  credit_entry_id     uuid references ledger.journal_entries (id),
  created_at          timestamptz not null default now(),
  verified_at         timestamptz,
  voided_at           timestamptz,
  void_reason         text
);
create index on commerce.purchases (user_id, created_at desc);

create table commerce.play_notifications (
  message_id   text primary key,                       -- Pub/Sub message id (dedupe)
  received_at  timestamptz not null default now(),
  kind         text not null,
  payload      jsonb not null
);

create table hosting.hosts (
  user_id             uuid primary key references identity.accounts (id),
  state               text not null default 'applied' check (state in ('applied','kyc_pending','approved','suspended')),
  kyc_state           text not null default 'not_started' check (kyc_state in ('not_started','in_progress','approved','rejected')),
  rate_per_minute     bigint not null default 500 check (rate_per_minute between 500 and 10000),
  is_available        boolean not null default false,
  last_heartbeat_at   timestamptz,
  free_call_opt_in    boolean not null default false,
  approved_at         timestamptz,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  check (not is_available or state = 'approved')
);
create index available_hosts on hosting.hosts (last_heartbeat_at desc) where is_available;
create trigger hosts_touch before update on hosting.hosts
  for each row execute function platform.touch_updated_at();

create table hosting.kyc_sessions (
  id              text primary key,                    -- vendor session id
  host_id         uuid not null references hosting.hosts (user_id),
  status          text not null check (status in ('started','approved','rejected','expired')),
  failure_code    text,
  created_at      timestamptz not null default now(),
  completed_at    timestamptz
);

create table freecall.cards (
  user_id              uuid primary key references identity.accounts (id),
  phone_hash           text not null unique,           -- one card per phone number
  device_binding_hash  text unique,                    -- one card per device (Play Integrity)
  status               text not null default 'available' check (status in ('available','used','revoked')),
  used_at              timestamptz
);

create table freecall.host_daily_counts (
  host_id  uuid not null references hosting.hosts (user_id),
  day      date not null,                              -- IST calendar day
  count    integer not null default 0 check (count between 0 and 20),
  primary key (host_id, day)
);

create table calls.calls (
  id                uuid primary key default gen_random_uuid(),
  caller_id         uuid not null references identity.accounts (id),
  receiver_id       uuid not null references identity.accounts (id),
  phase             text not null check (phase in ('requested','ringing','accepted','connecting','active','paused','ending','ended','declined','missed','failed')),
  rate_per_minute   bigint not null check (rate_per_minute between 0 and 10000),
  is_free_call      boolean not null default false,
  provider          text not null default 'stream',
  provider_call_id  text unique,
  rule_set_version  text not null references economy.rule_sets (version),
  end_reason        text,
  billed_seconds    bigint check (billed_seconds >= 0),
  diamonds_charged  bigint check (diamonds_charged >= 0),
  created_at        timestamptz not null default now(),
  accepted_at       timestamptz,
  connected_at      timestamptz,
  ended_at          timestamptz,
  check (caller_id <> receiver_id),
  check (is_free_call or rate_per_minute >= 500)
);
-- One live call per person, as caller or receiver.
create unique index one_live_call_as_caller on calls.calls (caller_id)
  where phase in ('requested','ringing','accepted','connecting','active','paused','ending');
create unique index one_live_call_as_receiver on calls.calls (receiver_id)
  where phase in ('requested','ringing','accepted','connecting','active','paused','ending');

-- Provider webhook events (deduplicated). Billing is computed from these.
create table calls.media_events (
  provider_event_id  text primary key,
  call_id            uuid not null references calls.calls (id),
  user_id            uuid,
  kind               text not null,
  occurred_at        timestamptz not null,
  received_at        timestamptz not null default now()
);
create index on calls.media_events (call_id, occurred_at);
create trigger media_events_append_only before update or delete on calls.media_events
  for each row execute function platform.forbid_mutation();

-- Exactly one settlement per call.
create table calls.settlements (
  call_id           uuid primary key references calls.calls (id),
  entry_id          uuid unique references ledger.journal_entries (id),
  billed_seconds    bigint not null check (billed_seconds >= 0),
  diamonds_charged  bigint not null check (diamonds_charged >= 0),
  beans_earned      bigint not null check (beans_earned >= 0),
  computed_at       timestamptz not null default now()
);
create trigger settlements_append_only before update or delete on calls.settlements
  for each row execute function platform.forbid_mutation();

-- Realtime Authorization helper: is the current user a participant?
create or replace function calls.is_participant(p_call_id text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from calls.calls c
     where c.id::text = p_call_id
       and (select auth.uid()) in (c.caller_id, c.receiver_id)
  );
$$;
revoke all on function calls.is_participant(text) from public;
