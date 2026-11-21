-- BE-money (2026-11-21): wallet, purchases (Google Play + Cashfree), payouts,
-- finance administration. See docs/mvp/api/wallet_payments.md.

-- ---------------------------------------------------------------- ledger
-- Counter-accounts for dual-control manual adjustments (ledger.Adjustment).
insert into ledger.accounts (owner_user_id, kind, currency, non_negative) values
  (null, 'sys_diamond_adjustment', 'DIAMOND', false),
  (null, 'sys_bean_adjustment', 'BEAN', false)
on conflict do nothing;

-- One row per promotional grant processed by `expire-promo-diamonds`, so a
-- grant whose Diamonds were already spent is not re-examined every run.
create table ledger.promo_grant_expiries (
  grant_entry_id  uuid primary key references ledger.journal_entries (id),
  user_id         uuid not null references identity.accounts (id),
  expired         bigint not null check (expired >= 0),
  entry_id        uuid references ledger.journal_entries (id),
  processed_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------- commerce
-- Reversal record: what was taken back and what had already been spent.
alter table commerce.purchases
  add column reversed_diamonds    bigint check (reversed_diamonds >= 0),
  add column unrecovered_diamonds bigint check (unrecovered_diamonds >= 0),
  add column reversal_entry_id    uuid references ledger.journal_entries (id);

-- The customer's phone number lives only in auth.users (Supabase Auth). The
-- API needs it once per Cashfree order (Cashfree requires customer_phone), so
-- it reads it through this narrow definer function instead of a table grant.
create or replace function commerce.customer_phone(p_user_id uuid) returns text
language plpgsql stable security definer set search_path = '' as $$
declare
  v text;
begin
  execute 'select phone::text from auth.users where id = $1' into v using p_user_id;
  return nullif(v, '');
exception when undefined_column then
  return null;
end $$;
revoke all on function commerce.customer_phone(uuid) from public;
grant execute on function commerce.customer_phone(uuid) to api_service, worker_service;

-- ---------------------------------------------------------------- access control for new tables
do $$
declare t record;
begin
  for t in select * from (values ('ledger','promo_grant_expiries')) as v(s, n)
  loop
    execute format('alter table %I.%I enable row level security', t.s, t.n);
    execute format('alter table %I.%I force row level security', t.s, t.n);
    execute format('create policy service_all on %I.%I for all to api_service, worker_service using (true) with check (true)', t.s, t.n);
    -- Ledger tables are append-only for the services.
    execute format('grant select, insert on %I.%I to api_service, worker_service', t.s, t.n);
    execute format('revoke all on %I.%I from anon, authenticated', t.s, t.n);
  end loop;
end $$;
grant select on ledger.promo_grant_expiries to reporting_readonly;
create policy reporting_read on ledger.promo_grant_expiries for select to reporting_readonly using (true);
