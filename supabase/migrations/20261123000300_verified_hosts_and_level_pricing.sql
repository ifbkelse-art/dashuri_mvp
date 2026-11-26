-- Verified Host status and level-based Diamond pricing (founder spec, 2026-11-23).
--
-- Two separate concepts:
--   * Hosting approval (existing): application + manual KYC (age and identity).
--     hosting.hosts.state = 'approved' means the account may host at all.
--   * Verified Host (new): a premium, admin-reviewed status. Only an ACTIVE
--     Verified Host may charge more than 3,000 Diamonds/minute.
--
-- Pricing (economy rule set 2026-11-23-verified-pricing):
--   minimum 500 D/min for every host; maximum = level x 1,000 (levels 1-10);
--   above 3,000 requires verification_status = 'verified'. Integer only.
-- The Go API is the authoritative validator. This migration adds a
-- defence-in-depth CHECK for the verification part (the level part depends on
-- ledger XP and is enforced in the API at every write and before every call).
--
-- Private verification evidence (face video, ID document images) lives in the
-- private Storage bucket 'host-verification-evidence'. The database keeps only
-- object paths and metadata; there are no biometric templates or embeddings.

-- ---------------------------------------------------------------- host status
alter table hosting.hosts
  add column verification_status text not null default 'not_applied'
    check (verification_status in ('not_applied','submitted','under_review','info_required',
                                   'verified','rejected','suspended','revoked')),
  add column verified_at timestamptz,
  add column verification_changed_at timestamptz;

-- ---------------------------------------------------------------- applications
create table hosting.verification_applications (
  id                 uuid primary key default gen_random_uuid(),
  host_id            uuid not null references hosting.hosts (user_id),
  status             text not null check (status in ('submitted','under_review','info_required',
                                                     'approved','rejected','suspended','revoked')),
  submitted_at       timestamptz not null,
  resubmitted_at     timestamptz,
  reviewer_id        uuid references identity.accounts (id),
  review_started_at  timestamptz,
  info_request       text check (char_length(info_request) <= 1000),
  decided_by         uuid references identity.accounts (id),
  decided_at         timestamptz,
  decision_reason    text check (char_length(decision_reason) <= 1000),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  check (reviewer_id is null or reviewer_id <> host_id),
  check (decided_by is null or decided_by <> host_id)
);
-- One open (non-final) application per host.
create unique index one_open_verification_application on hosting.verification_applications (host_id)
  where status in ('submitted','under_review','info_required','approved','suspended');
create index verification_queue on hosting.verification_applications (status, submitted_at);
create trigger verification_applications_touch before update on hosting.verification_applications
  for each row execute function platform.touch_updated_at();

-- ---------------------------------------------------------------- private evidence
create table hosting.verification_evidence (
  id              uuid primary key default gen_random_uuid(),
  host_id         uuid not null references hosting.hosts (user_id),
  application_id  uuid references hosting.verification_applications (id),   -- null until submitted
  kind            text not null check (kind in ('face_video','id_document_front','id_document_back')),
  content_type    text not null check (content_type in ('video/mp4','video/quicktime','image/jpeg','image/png')),
  storage_path    text not null unique,                                     -- inside the private bucket
  created_at      timestamptz not null default now(),
  purged_at       timestamptz
);
create index on hosting.verification_evidence (application_id);
create index on hosting.verification_evidence (host_id, created_at desc);

insert into storage.buckets (id, name, public) values
  ('host-verification-evidence', 'host-verification-evidence', false)
on conflict (id) do nothing;

-- ---------------------------------------------------------------- rule set
insert into economy.rule_sets (version, rules, effective_from) values (
  '2026-11-23-verified-pricing',
  jsonb_build_object(
    'beans_per_diamonds', jsonb_build_object('beans', 10000, 'diamonds', 16670),
    'paise_per_bean', jsonb_build_object('numerator', 1, 'denominator', 2),
    'rate_per_minute', jsonb_build_object('min', 500, 'max', 10000, 'level_step', 1000,
            'verified_threshold', 3000, 'rule', 'max = level x 1000; above 3000 requires active Verified Host',
            'status', 'founder_2026_11_23'),
    'xp', jsonb_build_object('diamond_weight', 8, 'bean_weight', 1,
            'thresholds', jsonb_build_array(0,32000,100000,250000,600000,1500000,3500000,8000000,18000000,40000000),
            'thresholds_status', 'proposal_unresolved'),
    'bean_hold_days', 7, 'min_withdrawal_paise', 50000, 'promo_diamond_ttl_days', 30,
    'min_start_balance_seconds', 60, 'low_balance_warning_seconds', 30,
    'free_call', jsonb_build_object('seconds', 60, 'host_comp_paise', 1000, 'max_per_host_per_day', 20),
    'interruption_threshold_seconds', 10, 'interruption_threshold_status', 'technical_assumption',
    'spend_order', 'promotional_first', 'spend_order_status', 'unresolved'
  ),
  '2026-11-23T00:00:00Z'
);

-- ---------------------------------------------------------------- cap existing prices
-- No host is verified yet, so every stored price must be within
-- [500, min(level x 1000, 3000)]. Live calls keep their snapshotted rate
-- (calls.calls.rate_per_minute); only the price for new calls changes.
with lv as (
  select h.user_id, h.rate_per_minute as old_rate,
         greatest(500, least(3000, 1000 * (
           select count(*) from unnest(array[0,32000,100000,250000,600000,1500000,3500000,8000000,18000000,40000000]::bigint[]) t
            where t <= coalesce((select ux.lifetime_xp from ledger.user_xp ux where ux.user_id = h.user_id), 0)))) as max_rate
    from hosting.hosts h
), capped as (
  update hosting.hosts h set rate_per_minute = lv.max_rate
    from lv where lv.user_id = h.user_id and h.rate_per_minute > lv.max_rate
  returning h.user_id, lv.old_rate, lv.max_rate
)
insert into audit.events (actor, action, target, details)
select 'system:migration', 'host.rate_capped', user_id::text,
       jsonb_build_object('from', old_rate, 'to', max_rate, 'reason', 'pricing_rules_2026_11_23')
  from capped;

alter table hosting.hosts
  add constraint rate_above_threshold_requires_verified
  check (rate_per_minute <= 3000 or verification_status = 'verified');

-- ---------------------------------------------------------------- access control
do $$
declare t record;
begin
  for t in select * from (values ('hosting','verification_applications'), ('hosting','verification_evidence')) as v(s, n)
  loop
    execute format('alter table %I.%I enable row level security', t.s, t.n);
    execute format('alter table %I.%I force row level security', t.s, t.n);
    execute format('create policy service_all on %I.%I for all to api_service, worker_service using (true) with check (true)', t.s, t.n);
    execute format('grant select, insert, update on %I.%I to api_service, worker_service', t.s, t.n);
    execute format('revoke all on %I.%I from anon, authenticated', t.s, t.n);
  end loop;
end $$;
