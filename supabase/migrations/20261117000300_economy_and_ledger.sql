-- Business rules (versioned) and the double-entry ledger.
-- See docs/architecture/financial-ledger-design.md.

create table economy.rule_sets (
  version         text primary key,
  rules           jsonb       not null,       -- economy.Rules serialised
  effective_from  timestamptz not null,
  approved_by     uuid,
  created_at      timestamptz not null default now()
);
create trigger rule_sets_append_only before update or delete on economy.rule_sets
  for each row execute function platform.forbid_mutation();

create table economy.diamond_packages (
  product_id   text primary key,               -- Google Play product id
  diamonds     bigint  not null check (diamonds > 0),
  active       boolean not null default true,
  sort_order   smallint not null default 0
);

-- Accounts: one row per (owner, kind). owner null = system account.
create table ledger.accounts (
  id             bigint generated always as identity primary key,
  owner_user_id  uuid references identity.accounts (id),
  kind           text   not null,
  currency       text   not null check (currency in ('DIAMOND','BEAN','INR_PAISE')),
  non_negative   boolean not null,             -- true for every user wallet bucket
  created_at     timestamptz not null default now(),
  unique nulls not distinct (owner_user_id, kind),
  check ((owner_user_id is null) = (kind like 'sys\_%'))
);

-- Balance projection, maintained only by the posting trigger below.
create table ledger.balances (
  account_id    bigint primary key references ledger.accounts (id),
  balance       bigint not null default 0,
  non_negative  boolean not null,
  version       bigint not null default 0,
  updated_at    timestamptz not null default now(),
  check (not non_negative or balance >= 0)       -- user wallets can never go negative
);

create table ledger.journal_entries (
  id               uuid primary key default gen_random_uuid(),
  entry_type       text not null check (entry_type in (
                     'purchase_credit','promo_grant','call_settlement','free_call_compensation',
                     'bean_release','withdrawal_requested','payout_paid','payout_failed',
                     'purchase_reversal','bean_clawback','promo_expiry','adjustment')),
  idempotency_key  text not null unique,         -- exactly-once per business event
  rule_set_version text references economy.rule_sets (version),
  reference        text,
  occurred_at      timestamptz not null,
  recorded_at      timestamptz not null default now(),
  metadata         jsonb not null default '{}'::jsonb,
  created_by       text not null default current_user
);
create index on ledger.journal_entries (reference);

create table ledger.postings (
  id          bigint generated always as identity primary key,
  entry_id    uuid   not null references ledger.journal_entries (id),
  account_id  bigint not null references ledger.accounts (id),
  currency    text   not null,
  amount      bigint not null check (amount <> 0)
);
create index on ledger.postings (entry_id);
create index on ledger.postings (account_id, id);

-- Immutable history.
create trigger journal_entries_append_only before update or delete on ledger.journal_entries
  for each row execute function platform.forbid_mutation();
create trigger postings_append_only before update or delete on ledger.postings
  for each row execute function platform.forbid_mutation();

-- Each posting: currency must match the account; update the projection.
-- Callers lock balance rows first (SELECT … FOR UPDATE, ascending account id).
create or replace function ledger.apply_posting() returns trigger
language plpgsql as $$
declare
  acct_currency text;
  acct_non_negative boolean;
begin
  select currency, non_negative into acct_currency, acct_non_negative
    from ledger.accounts where id = new.account_id;
  if acct_currency is distinct from new.currency then
    raise exception 'posting currency % does not match account % currency %', new.currency, new.account_id, acct_currency
      using errcode = 'P0002';
  end if;
  insert into ledger.balances as b (account_id, balance, non_negative, version, updated_at)
       values (new.account_id, new.amount, acct_non_negative, 1, now())
  on conflict (account_id) do update
       set balance = b.balance + excluded.balance, version = b.version + 1, updated_at = now();
  return new;
end $$;
create trigger postings_apply after insert on ledger.postings
  for each row execute function ledger.apply_posting();

-- Each entry must balance per currency, checked at COMMIT.
create or replace function ledger.assert_entry_balanced() returns trigger
language plpgsql as $$
declare
  bad record;
begin
  select currency, sum(amount) as total into bad
    from ledger.postings where entry_id = new.entry_id
   group by currency having sum(amount) <> 0 limit 1;
  if found then
    raise exception 'journal entry % unbalanced: % sums to %', new.entry_id, bad.currency, bad.total
      using errcode = 'P0003';
  end if;
  if (select count(*) from ledger.postings where entry_id = new.entry_id) < 2 then
    raise exception 'journal entry % needs at least two postings', new.entry_id using errcode = 'P0003';
  end if;
  return null;
end $$;
create constraint trigger postings_balanced after insert on ledger.postings
  deferrable initially deferred
  for each row execute function ledger.assert_entry_balanced();

-- Diamonds reserved for a call in progress (not ledger postings).
-- available = purchased + promotional − active reservations.
create table ledger.diamond_reservations (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references identity.accounts (id),
  call_id     uuid not null unique,
  amount      bigint not null check (amount > 0),
  status      text not null default 'active' check (status in ('active','settled','released')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create unique index one_active_reservation_per_user on ledger.diamond_reservations (user_id) where status = 'active';

-- Lifetime XP (append-only). XP = 8 × eligible Diamonds purchased + eligible Beans earned.
create table ledger.xp_events (
  id           bigint generated always as identity primary key,
  user_id      uuid   not null references identity.accounts (id),
  source_type  text   not null check (source_type in ('purchase','bean_earning','reversal')),
  source_id    text   not null,
  xp_delta     bigint not null,
  created_at   timestamptz not null default now(),
  unique (source_type, source_id)
);
create index on ledger.xp_events (user_id);
create trigger xp_events_append_only before update or delete on ledger.xp_events
  for each row execute function platform.forbid_mutation();

create view ledger.user_xp as
  select user_id, sum(xp_delta)::bigint as lifetime_xp from ledger.xp_events group by user_id;

-- Founder rule set (2026-11-17). Unresolved values are marked in the JSON.
insert into economy.rule_sets (version, rules, effective_from) values (
  '2026-11-17-founder',
  jsonb_build_object(
    'beans_per_diamonds', jsonb_build_object('beans', 10000, 'diamonds', 16670),
    'paise_per_bean', jsonb_build_object('numerator', 1, 'denominator', 2),
    'rate_per_minute', jsonb_build_object('min', 500, 'max', 10000, 'level_caps', null, 'status', 'ladder_unresolved'),
    'xp', jsonb_build_object('diamond_weight', 8, 'bean_weight', 1,
            'thresholds', jsonb_build_array(0,32000,100000,250000,600000,1500000,3500000,8000000,18000000,40000000),
            'thresholds_status', 'proposal_unresolved'),
    'bean_hold_days', 7, 'min_withdrawal_paise', 50000, 'promo_diamond_ttl_days', 30,
    'min_start_balance_seconds', 60, 'low_balance_warning_seconds', 30,
    'free_call', jsonb_build_object('seconds', 60, 'host_comp_paise', 1000, 'max_per_host_per_day', 20),
    'interruption_threshold_seconds', 10, 'interruption_threshold_status', 'technical_assumption',
    'spend_order', 'promotional_first', 'spend_order_status', 'unresolved'
  ),
  '2026-11-17T00:00:00Z'
);

-- System accounts.
insert into ledger.accounts (owner_user_id, kind, currency, non_negative) values
  (null, 'sys_diamond_issued_purchased', 'DIAMOND', false),
  (null, 'sys_diamond_issued_promotional', 'DIAMOND', false),
  (null, 'sys_diamond_consumed', 'DIAMOND', false),
  (null, 'sys_diamond_expired', 'DIAMOND', false),
  (null, 'sys_diamond_reversed', 'DIAMOND', false),
  (null, 'sys_bean_issued', 'BEAN', false),
  (null, 'sys_bean_paid_out', 'BEAN', false),
  (null, 'sys_bean_clawed_back', 'BEAN', false);
