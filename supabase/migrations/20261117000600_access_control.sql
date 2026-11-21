-- Grants, RLS, Realtime Authorization, Storage. Deny by default.

-- 1. Enable RLS on every table in domain schemas.
do $$
declare t record;
begin
  for t in select schemaname, tablename from pg_tables
            where schemaname in ('identity','economy','ledger','commerce','hosting','calls','freecall','chat',
                                 'safety','moderation','payouts','notify','platform','audit')
  loop
    execute format('alter table %I.%I enable row level security', t.schemaname, t.tablename);
    execute format('alter table %I.%I force row level security', t.schemaname, t.tablename);
    execute format('create policy service_all on %I.%I for all to api_service, worker_service using (true) with check (true)',
                   t.schemaname, t.tablename);
  end loop;
end $$;

-- 2. Service grants: DML, but append-only tables are INSERT/SELECT only.
grant select, insert, update, delete on all tables in schema identity, economy, commerce, hosting, calls,
  freecall, chat, safety, moderation, payouts, notify, platform to api_service, worker_service;
grant select, insert on all tables in schema ledger, audit to api_service, worker_service;
grant update on ledger.balances, ledger.diamond_reservations, ledger.adjustment_proposals to api_service, worker_service;
revoke update, delete on economy.rule_sets, calls.media_events, calls.settlements from api_service, worker_service;
grant usage on all sequences in schema ledger, moderation, audit to api_service, worker_service;
grant select on ledger.user_xp to api_service, worker_service;
grant execute on function calls.is_participant(text) to authenticated;

-- Finance reporting: read-only.
grant select on all tables in schema ledger, commerce, payouts, economy to reporting_readonly;
do $$
declare t record;
begin
  for t in select schemaname, tablename from pg_tables where schemaname in ('ledger','commerce','payouts','economy') loop
    execute format('create policy reporting_read on %I.%I for select to reporting_readonly using (true)', t.schemaname, t.tablename);
  end loop;
end $$;

-- 3. Clients (anon, authenticated) get NOTHING on domain schemas. The
--    public schema stays empty; PostgREST exposes no Dashuri data.
revoke all on all tables in schema identity, economy, ledger, commerce, hosting, calls, freecall, chat,
  safety, moderation, payouts, notify, platform, audit from anon, authenticated;

-- 4. Realtime Authorization: a signed-in user may RECEIVE broadcasts only on
--    `user:<own id>` and `call:<id>` for calls they are in. No client may send;
--    the Go API publishes with a server key.
alter table realtime.messages enable row level security;
create policy dashuri_receive_own_channels on realtime.messages
  for select to authenticated
  using (
    realtime.messages.extension = 'broadcast'
    and (
      realtime.topic() = 'user:' || (select auth.uid())::text
      or (realtime.topic() like 'call:%' and calls.is_participant(substring(realtime.topic() from 6)))
    )
  );

-- 5. Storage: private buckets. Uploads and reads use signed URLs issued by
--    the Go API, so no client policies are needed.
insert into storage.buckets (id, name, public) values
  ('profile-photos', 'profile-photos', false),
  ('moderation-evidence', 'moderation-evidence', false)
on conflict (id) do nothing;
