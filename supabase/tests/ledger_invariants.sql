-- Ledger and call invariants enforced by the database itself.
\set ON_ERROR_STOP on
create or replace function pg_temp.expect_error(sql text, label text) returns text
language plpgsql as $$
begin
  execute sql;
  return 'FAIL ' || label || ' (no error raised)';
exception when others then
  return 'PASS ' || label || ' [' || sqlstate || '] ' || left(sqlerrm, 80);
end $$;

-- Fixtures
insert into auth.users values ('11111111-1111-4111-8111-111111111111'), ('22222222-2222-4222-8222-222222222222');
insert into identity.accounts (id) values ('11111111-1111-4111-8111-111111111111'), ('22222222-2222-4222-8222-222222222222');
insert into ledger.accounts (owner_user_id, kind, currency, non_negative) values
  ('11111111-1111-4111-8111-111111111111', 'diamond_purchased', 'DIAMOND', true),
  ('22222222-2222-4222-8222-222222222222', 'bean_held', 'BEAN', true);

-- A balanced purchase credit commits.
begin;
insert into ledger.journal_entries (id, entry_type, idempotency_key, rule_set_version, occurred_at)
  values ('aaaaaaaa-0000-4000-8000-000000000001', 'purchase_credit', 'purchase_credit:tok1', '2026-11-17-founder', now());
insert into ledger.postings (entry_id, account_id, currency, amount) values
  ('aaaaaaaa-0000-4000-8000-000000000001', (select id from ledger.accounts where kind = 'sys_diamond_issued_purchased'), 'DIAMOND', -54000),
  ('aaaaaaaa-0000-4000-8000-000000000001', (select id from ledger.accounts where kind = 'diamond_purchased'), 'DIAMOND', 54000);
commit;
select case when balance = 54000 then 'PASS balanced entry commits and updates projection'
            else 'FAIL projection ' || balance end
  from ledger.balances where account_id = (select id from ledger.accounts where kind = 'diamond_purchased');

-- Unbalanced entry is rejected at COMMIT (deferred constraint trigger).
select pg_temp.expect_error($q$
  do $d$ begin
    insert into ledger.journal_entries (id, entry_type, idempotency_key, occurred_at)
      values ('aaaaaaaa-0000-4000-8000-000000000002', 'adjustment', 'adj:1', now());
    insert into ledger.postings (entry_id, account_id, currency, amount) values
      ('aaaaaaaa-0000-4000-8000-000000000002', (select id from ledger.accounts where kind = 'diamond_purchased'), 'DIAMOND', 10);
    set constraints all immediate;
  end $d$ $q$, 'unbalanced entry rejected');

-- A user wallet cannot go negative.
select pg_temp.expect_error($q$
  do $d$ begin
    insert into ledger.journal_entries (id, entry_type, idempotency_key, occurred_at)
      values ('aaaaaaaa-0000-4000-8000-000000000003', 'call_settlement', 'call_settlement:x', now());
    insert into ledger.postings (entry_id, account_id, currency, amount) values
      ('aaaaaaaa-0000-4000-8000-000000000003', (select id from ledger.accounts where kind = 'diamond_purchased'), 'DIAMOND', -60000),
      ('aaaaaaaa-0000-4000-8000-000000000003', (select id from ledger.accounts where kind = 'sys_diamond_consumed'), 'DIAMOND', 60000);
  end $d$ $q$, 'overspend blocked by non-negative balance check');

-- Currency must match the account.
select pg_temp.expect_error($q$
  insert into ledger.postings (entry_id, account_id, currency, amount) values
    ('aaaaaaaa-0000-4000-8000-000000000001', (select id from ledger.accounts where kind = 'diamond_purchased'), 'BEAN', 5)
  $q$, 'posting currency must match account');

-- History is immutable.
select pg_temp.expect_error($q$ update ledger.postings set amount = 1 $q$, 'postings cannot be updated');
select pg_temp.expect_error($q$ delete from ledger.journal_entries $q$, 'journal entries cannot be deleted');

-- Exactly-once per business event.
select pg_temp.expect_error($q$
  insert into ledger.journal_entries (entry_type, idempotency_key, occurred_at)
    values ('purchase_credit', 'purchase_credit:tok1', now())
  $q$, 'duplicate idempotency key rejected');

-- One live call per person; one settlement per call.
insert into calls.calls (id, caller_id, receiver_id, phase, rate_per_minute, rule_set_version)
  values ('cccccccc-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222', 'active', 4000, '2026-11-17-founder');
select pg_temp.expect_error($q$
  insert into calls.calls (caller_id, receiver_id, phase, rate_per_minute, rule_set_version)
    values ('11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222', 'ringing', 4000, '2026-11-17-founder')
  $q$, 'second live call for the same caller rejected');
select pg_temp.expect_error($q$
  insert into calls.calls (caller_id, receiver_id, phase, rate_per_minute, rule_set_version)
    values ('22222222-2222-4222-8222-222222222222', '11111111-1111-4111-8111-111111111111', 'ringing', 400, '2026-11-17-founder')
  $q$, 'paid rate below 500 D/min rejected');
insert into calls.settlements (call_id, billed_seconds, diamonds_charged, beans_earned)
  values ('cccccccc-0000-4000-8000-000000000001', 65, 4333, 2599);
select pg_temp.expect_error($q$
  insert into calls.settlements (call_id, billed_seconds, diamonds_charged, beans_earned)
    values ('cccccccc-0000-4000-8000-000000000001', 65, 4333, 2599)
  $q$, 'second settlement for a call rejected');

-- Clients cannot read domain tables.
set role authenticated;
select pg_temp.expect_error($q$ select * from ledger.balances $q$, 'authenticated role cannot read ledger');
reset role;

-- Verified Host pricing (2026-11-23): above 3,000 D/min needs an active
-- Verified Host; one open verification application per host; clients cannot
-- read verification evidence.
insert into hosting.hosts (user_id, state, kyc_state, rate_per_minute)
  values ('22222222-2222-4222-8222-222222222222', 'approved', 'approved', 3000);
select pg_temp.expect_error($q$
  update hosting.hosts set rate_per_minute = 3001 where user_id = '22222222-2222-4222-8222-222222222222'
  $q$, 'non-verified host above 3,000 D/min rejected');
select pg_temp.expect_error($q$
  update hosting.hosts set verification_status = 'suspended', rate_per_minute = 4000
   where user_id = '22222222-2222-4222-8222-222222222222'
  $q$, 'suspended host above 3,000 D/min rejected');
update hosting.hosts set verification_status = 'verified', rate_per_minute = 4000
 where user_id = '22222222-2222-4222-8222-222222222222';
select pg_temp.expect_error($q$
  update hosting.hosts set verification_status = 'revoked' where user_id = '22222222-2222-4222-8222-222222222222'
  $q$, 'revoking without capping the price rejected');
update hosting.hosts set verification_status = 'revoked', rate_per_minute = 3000
 where user_id = '22222222-2222-4222-8222-222222222222';
insert into hosting.verification_applications (host_id, status, submitted_at)
  values ('22222222-2222-4222-8222-222222222222', 'submitted', now());
select pg_temp.expect_error($q$
  insert into hosting.verification_applications (host_id, status, submitted_at)
    values ('22222222-2222-4222-8222-222222222222', 'under_review', now())
  $q$, 'second open verification application rejected');
select pg_temp.expect_error($q$
  update hosting.verification_applications set decided_by = host_id
   where host_id = '22222222-2222-4222-8222-222222222222'
  $q$, 'self-decided verification rejected');
set role authenticated;
select pg_temp.expect_error($q$ select * from hosting.verification_evidence $q$, 'authenticated role cannot read verification evidence');
reset role;

-- Online sessions and arrival photos (2026-11-26): availability opens and
-- closes exactly one session; a photo belongs to one session; ending the
-- session expires the photo.
update hosting.hosts set is_available = true where user_id = '22222222-2222-4222-8222-222222222222';
select pg_temp.expect_error($q$
  insert into hosting.online_sessions (host_id) values ('22222222-2222-4222-8222-222222222222')
  $q$, 'second open online session rejected');
insert into hosting.arrival_photos (host_id, session_id, content_type, storage_path, upload_expires_at)
select host_id, id, 'image/jpeg', 'inv/photo1.jpg', now() + interval '10 minutes'
  from hosting.online_sessions where host_id = '22222222-2222-4222-8222-222222222222' and ended_at is null;
select pg_temp.expect_error($q$
  insert into hosting.arrival_photos (host_id, session_id, content_type, storage_path, upload_expires_at)
  select host_id, id, 'image/jpeg', 'inv/photo2.jpg', now() + interval '10 minutes'
    from hosting.online_sessions where host_id = '22222222-2222-4222-8222-222222222222' and ended_at is null
  $q$, 'second current arrival photo in one session rejected');
select pg_temp.expect_error($q$
  update hosting.arrival_photos set content_type = 'image/png' where storage_path = 'inv/photo1.jpg'
  $q$, 'non-JPEG arrival photo rejected');
update hosting.hosts set is_available = false where user_id = '22222222-2222-4222-8222-222222222222';
select pg_temp.expect_error($q$
  do $d$ begin
    if (select status from hosting.arrival_photos where storage_path = 'inv/photo1.jpg') = 'expired'
       and not exists (select 1 from hosting.online_sessions where host_id = '22222222-2222-4222-8222-222222222222' and ended_at is null)
    then raise exception 'ok: offline ends the session and expires the photo' using errcode = 'P0099'; end if;
  end $d$
  $q$, 'going offline ends the session and expires its arrival photo');
set role authenticated;
select pg_temp.expect_error($q$ select * from hosting.arrival_photos $q$, 'authenticated role cannot read arrival photos');
reset role;

-- Virtual gifts (2026-11-26): gift transactions are append-only, record the
-- price charged, and have exactly one chat line.
select pg_temp.expect_error($q$
  insert into ledger.journal_entries (entry_type, idempotency_key, occurred_at) values ('gift_bonus', 'inv:bad-type', now())
  $q$, 'unknown ledger entry type rejected');
insert into ledger.journal_entries (id, entry_type, idempotency_key, rule_set_version, occurred_at)
  values ('aaaaaaaa-0000-4000-8000-0000000000f1', 'gift_send', 'gift_send:inv1', '2026-11-17-founder', now());
insert into gifts.transactions (id, sender_id, recipient_id, call_id, gift_id, gift_name, tier, emoji, animation_asset,
  diamond_price, from_promotional, from_purchased, host_beans, rule_set_version, ledger_entry_id, client_request_id, request_hash)
values ('dddddddd-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222',
  'cccccccc-0000-4000-8000-000000000001', 'rose', 'Rose', 'common', '🌹', 'celebration/rose', 1500, 0, 1500, 899,
  '2026-11-17-founder', 'aaaaaaaa-0000-4000-8000-0000000000f1', 'eeeeeeee-0000-4000-8000-000000000001', 'h');
select pg_temp.expect_error($q$
  update gifts.transactions set diamond_price = 1 where id = 'dddddddd-0000-4000-8000-000000000001'
  $q$, 'gift transactions cannot be updated');
select pg_temp.expect_error($q$
  delete from gifts.transactions where id = 'dddddddd-0000-4000-8000-000000000001'
  $q$, 'gift transactions cannot be deleted');
select pg_temp.expect_error($q$
  insert into gifts.transactions (id, sender_id, recipient_id, call_id, gift_id, gift_name, tier, emoji, animation_asset,
    diamond_price, from_promotional, from_purchased, host_beans, rule_set_version, ledger_entry_id, client_request_id, request_hash)
  values ('dddddddd-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222',
    'cccccccc-0000-4000-8000-000000000001', 'rose', 'Rose', 'common', '🌹', 'celebration/rose', 1500, 0, 1500, 899,
    '2026-11-17-founder', 'aaaaaaaa-0000-4000-8000-0000000000f1', 'eeeeeeee-0000-4000-8000-000000000002', 'h')
  $q$, 'one gift per ledger entry');
select pg_temp.expect_error($q$
  insert into gifts.transactions (id, sender_id, recipient_id, call_id, gift_id, gift_name, tier, emoji, animation_asset,
    diamond_price, from_promotional, from_purchased, host_beans, rule_set_version, ledger_entry_id, client_request_id, request_hash)
  values ('dddddddd-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222',
    'cccccccc-0000-4000-8000-000000000001', 'rose', 'Rose', 'common', '🌹', 'celebration/rose', 1500, 0, 1400, 899,
    '2026-11-17-founder', 'aaaaaaaa-0000-4000-8000-0000000000f1', 'eeeeeeee-0000-4000-8000-000000000003', 'h')
  $q$, 'gift split must equal the price charged');
insert into chat.conversations (id, user_a, user_b)
  values ('ffffffff-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', '22222222-2222-4222-8222-222222222222');
insert into chat.messages (conversation_id, sender_id, body, context, call_id, kind, gift_transaction_id)
  values ('ffffffff-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'gift', 'call',
          'cccccccc-0000-4000-8000-000000000001', 'gift', 'dddddddd-0000-4000-8000-000000000001');
select pg_temp.expect_error($q$
  insert into chat.messages (conversation_id, sender_id, body, context, call_id, kind, gift_transaction_id)
    values ('ffffffff-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'gift again', 'call',
            'cccccccc-0000-4000-8000-000000000001', 'gift', 'dddddddd-0000-4000-8000-000000000001')
  $q$, 'second chat line for one gift rejected');
select pg_temp.expect_error($q$
  insert into chat.messages (conversation_id, sender_id, body, kind) values ('ffffffff-0000-4000-8000-000000000001',
    '11111111-1111-4111-8111-111111111111', 'fake gift', 'gift')
  $q$, 'gift message without a gift transaction rejected');
select pg_temp.expect_error($q$
  update gifts.price_changes set new_price = 1 where gift_id = 'rose'
  $q$, 'gift price history is append-only');
select pg_temp.expect_error($q$
  delete from gifts.catalogue where id = 'rose'
  $q$, 'gift catalogue rows cannot be deleted (retire instead)');
set role authenticated;
select pg_temp.expect_error($q$ select * from gifts.transactions $q$, 'authenticated role cannot read gift transactions');
reset role;
