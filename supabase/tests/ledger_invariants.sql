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
