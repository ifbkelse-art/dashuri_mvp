-- Virtual gifts during one-to-one video calls (2026-11-26).
-- Spec: docs/gifts/VIRTUAL_GIFTS.md. Depends on 20261123000200 (chat
-- message context: chat.messages.call_id / context / client_message_id).
--
-- Money rule: a gift is ONE balanced ledger entry (entry_type gift_send,
-- key gift_send:<gift transaction id>) that spends the customer's Diamonds
-- (promotional first, like calls) and credits the host's Beans into the
-- 7-day hold using the SAME versioned economy rule set as calls
-- (economy.Rules.BeansForDiamonds; rule_set_version is stored). There is no
-- gift-specific commission. The 5:4 model approved on 2026-11-24 is for
-- modelling only and is NOT activated here.
--
-- gifts.catalogue          configurable catalogue (admin-managed)
-- gifts.price_changes      append-only price history (every change audited)
-- gifts.transactions       append-only: one row per sent gift, with the
--                          price, split and Beans as charged at the time
-- chat.messages.kind/gift  the gift's system message in the call's session
--                          chat (and, after the call, in normal Chat)

create schema if not exists gifts;
grant usage on schema gifts to api_service, worker_service;

create table gifts.catalogue (
  id                    text primary key check (id ~ '^[a-z][a-z0-9_]{1,39}$'),   -- stable gift id
  name                  text not null check (length(name) between 1 and 40),
  description           text not null default '' check (length(description) <= 200),
  emoji                 text not null default '🎁' check (length(emoji) between 1 and 8),            -- used in the chat line
  icon_asset            text not null check (length(icon_asset) between 1 and 200),       -- app asset key or https URL
  animation_asset       text not null check (length(animation_asset) between 1 and 200),  -- animation reference
  animation_duration_ms integer not null default 5000 check (animation_duration_ms between 1000 and 10000),
  sound_asset           text check (length(sound_asset) <= 200),
  tier                  text not null check (tier in ('common','rare','epic','legendary','mythic')),
  sort_order            integer not null default 0,
  diamond_price         bigint not null check (diamond_price between 1 and 1000000),
  active                boolean not null default true,
  available_from        timestamptz,
  available_until       timestamptz,
  -- Which approved earning rule credits the host. Only the standard
  -- conversion exists: the economy rule set in force when the gift is sent.
  earning_rule          text not null default 'standard_conversion' check (earning_rule in ('standard_conversion')),
  retired_at            timestamptz,                                           -- retired gifts are never sold again
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  check (available_until is null or available_from is null or available_until > available_from),
  check (retired_at is null or not active)
);
create trigger catalogue_touch before update on gifts.catalogue
  for each row execute function platform.touch_updated_at();
create trigger catalogue_no_delete before delete on gifts.catalogue
  for each row execute function platform.forbid_mutation();

create table gifts.price_changes (
  id          bigint generated always as identity primary key,
  gift_id     text not null references gifts.catalogue (id),
  old_price   bigint,                                     -- null when the gift was created
  new_price   bigint not null check (new_price > 0),
  changed_by  text not null,
  reason      text not null check (length(reason) between 3 and 500),
  changed_at  timestamptz not null default now()
);
create index on gifts.price_changes (gift_id, changed_at desc);
create trigger price_changes_append_only before update or delete on gifts.price_changes
  for each row execute function platform.forbid_mutation();

-- Founder-proposed initial catalogue (product decision, 2026-11-26).
insert into gifts.catalogue (id, name, description, emoji, icon_asset, animation_asset, tier, sort_order, diamond_price) values
  ('rose',         'Rose',         'A single red rose',        '🌹', 'gift/rose',         'celebration/rose',         'common',     10,   1500),
  ('teddy',        'Teddy',        'A soft teddy bear',        '🧸', 'gift/teddy',        'celebration/teddy',        'common',     20,   5000),
  ('watch',        'Watch',        'A classic wristwatch',     '⌚', 'gift/watch',        'celebration/watch',        'rare',       30,  10000),
  ('gold_ring',    'Gold Ring',    'A gold ring',              '💍', 'gift/gold_ring',    'celebration/gold_ring',    'rare',       40,  15000),
  ('diamond_ring', 'Diamond Ring', 'A sparkling diamond ring', '💎', 'gift/diamond_ring', 'celebration/diamond_ring', 'epic',       50,  25000),
  ('luxury_gift',  'Luxury Gift',  'A luxury gift box',        '🎁', 'gift/luxury',       'celebration/luxury',       'epic',       60,  50000),
  ('royal_gift',   'Royal Gift',   'A royal crown',            '👑', 'gift/royal',        'celebration/royal',        'legendary',  70, 100000),
  ('premium_gift', 'Premium Gift', 'A premium treasure chest', '🏆', 'gift/premium',      'celebration/premium',      'legendary',  80, 150000),
  ('super_gift',   'Super Gift',   'A super celebration',      '🌟', 'gift/super',        'celebration/super',        'mythic',     90, 200000),
  ('elite_gift',   'Elite Gift',   'The elite celebration',    '🚀', 'gift/elite',        'celebration/elite',        'mythic',    100, 300000);
insert into gifts.price_changes (gift_id, old_price, new_price, changed_by, reason)
select id, null, diamond_price, 'system:migration', 'initial founder-proposed catalogue (2026-11-26)' from gifts.catalogue;

-- ---------------------------------------------------------------- ledger
alter table ledger.journal_entries drop constraint journal_entries_entry_type_check;
alter table ledger.journal_entries add constraint journal_entries_entry_type_check check (entry_type in (
  'purchase_credit','promo_grant','call_settlement','free_call_compensation',
  'bean_release','withdrawal_requested','payout_paid','payout_failed',
  'purchase_reversal','bean_clawback','promo_expiry','adjustment','gift_send'));

-- ---------------------------------------------------------------- transactions
create table gifts.transactions (
  id                 uuid primary key,                                   -- generated by the API
  sender_id          uuid not null references identity.accounts (id),   -- the customer (call caller)
  recipient_id       uuid not null references identity.accounts (id),   -- the host (call receiver)
  call_id            uuid not null references calls.calls (id),
  gift_id            text not null references gifts.catalogue (id),
  gift_name          text not null,                                      -- snapshot at send time
  tier               text not null,                                      -- snapshot
  emoji              text not null,                                      -- snapshot
  animation_asset    text not null,                                      -- snapshot
  diamond_price      bigint not null check (diamond_price > 0),          -- price CHARGED (never re-priced)
  from_promotional   bigint not null check (from_promotional >= 0),
  from_purchased     bigint not null check (from_purchased >= 0),
  host_beans         bigint not null check (host_beans >= 0),
  rule_set_version   text not null references economy.rule_sets (version),
  ledger_entry_id    uuid not null unique references ledger.journal_entries (id),
  client_request_id  uuid not null,                                      -- the Idempotency-Key
  request_hash       text not null,                                      -- gift_id + recipient + call
  risk_flags         text[] not null default '{}',
  created_at         timestamptz not null default now(),
  unique (sender_id, client_request_id),
  check (sender_id <> recipient_id),
  check (from_promotional + from_purchased = diamond_price)
);
create index on gifts.transactions (call_id, created_at);
create index on gifts.transactions (recipient_id, created_at desc);
create index on gifts.transactions (sender_id, created_at desc);
create index on gifts.transactions (gift_id, created_at desc);
create index gifts_flagged on gifts.transactions (created_at desc) where risk_flags <> '{}';
create trigger transactions_append_only before update or delete on gifts.transactions
  for each row execute function platform.forbid_mutation();

-- ---------------------------------------------------------------- chat
-- A gift's system message: an ordinary message of the pair's conversation,
-- in the call's session (context 'call', call_id set), sent by the customer.
-- One message per gift (unique gift_transaction_id): a replay can never
-- add a second one.
alter table chat.messages
  add column kind text not null default 'text' check (kind in ('text','gift')),
  add column gift_transaction_id uuid unique references gifts.transactions (id),
  add constraint messages_gift_kind check ((kind = 'gift') = (gift_transaction_id is not null)),
  add constraint messages_gift_in_call check (kind <> 'gift' or (context = 'call' and call_id is not null));

-- ---------------------------------------------------------------- access control
do $$
declare t record;
begin
  for t in select * from (values ('gifts','catalogue'), ('gifts','price_changes'), ('gifts','transactions')) as v(s, n)
  loop
    execute format('alter table %I.%I enable row level security', t.s, t.n);
    execute format('alter table %I.%I force row level security', t.s, t.n);
    execute format('create policy service_all on %I.%I for all to api_service, worker_service using (true) with check (true)', t.s, t.n);
    execute format('revoke all on %I.%I from anon, authenticated', t.s, t.n);
  end loop;
end $$;
grant select, insert, update on gifts.catalogue to api_service, worker_service;
grant select, insert on gifts.price_changes, gifts.transactions to api_service, worker_service;
grant usage on all sequences in schema gifts to api_service, worker_service;
grant select on all tables in schema gifts to reporting_readonly;
create policy reporting_read on gifts.transactions for select to reporting_readonly using (true);
