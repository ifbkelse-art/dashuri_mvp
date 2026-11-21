-- MVP foundation (2026-11-21). See docs/mvp/MVP_DECISIONS_AND_CONTRACT.md.
--   * Coarse location: curated city list; profiles reference a city id only.
--     Coordinates are never stored (founder decision F4).
--   * Profile gender (private), community-rules acceptance.
--   * Diamond package prices; Cashfree as a second, server-verified rail (F1).
--   * Chat read markers; call-history indexes; manual KYC provider.

-- ---------------------------------------------------------------- location
create table identity.cities (
  id         text primary key check (id ~ '^[a-z0-9_]{2,40}$'),
  name       text not null,
  state      text not null,
  latitude   numeric(8,5) not null check (latitude between -90 and 90),
  longitude  numeric(8,5) not null check (longitude between -180 and 180),
  active     boolean not null default true
);

insert into identity.cities (id, name, state, latitude, longitude) values
  ('mumbai','Mumbai','Maharashtra',19.07600,72.87770),
  ('delhi','Delhi','Delhi',28.70410,77.10250),
  ('bengaluru','Bengaluru','Karnataka',12.97160,77.59460),
  ('hyderabad','Hyderabad','Telangana',17.38500,78.48670),
  ('ahmedabad','Ahmedabad','Gujarat',23.02250,72.57140),
  ('chennai','Chennai','Tamil Nadu',13.08270,80.27070),
  ('kolkata','Kolkata','West Bengal',22.57260,88.36390),
  ('pune','Pune','Maharashtra',18.52040,73.85670),
  ('jaipur','Jaipur','Rajasthan',26.91240,75.78730),
  ('surat','Surat','Gujarat',21.17020,72.83110),
  ('lucknow','Lucknow','Uttar Pradesh',26.84670,80.94620),
  ('kanpur','Kanpur','Uttar Pradesh',26.44990,80.33190),
  ('nagpur','Nagpur','Maharashtra',21.14580,79.08820),
  ('indore','Indore','Madhya Pradesh',22.71960,75.85770),
  ('bhopal','Bhopal','Madhya Pradesh',23.25990,77.41260),
  ('visakhapatnam','Visakhapatnam','Andhra Pradesh',17.68680,83.21850),
  ('patna','Patna','Bihar',25.59410,85.13760),
  ('vadodara','Vadodara','Gujarat',22.30720,73.18120),
  ('ludhiana','Ludhiana','Punjab',30.90100,75.85730),
  ('agra','Agra','Uttar Pradesh',27.17670,78.00810),
  ('nashik','Nashik','Maharashtra',19.99750,73.78980),
  ('rajkot','Rajkot','Gujarat',22.30390,70.80220),
  ('varanasi','Varanasi','Uttar Pradesh',25.31760,82.97390),
  ('srinagar','Srinagar','Jammu and Kashmir',34.08370,74.79730),
  ('amritsar','Amritsar','Punjab',31.63400,74.87230),
  ('chandigarh','Chandigarh','Chandigarh',30.73330,76.77940),
  ('coimbatore','Coimbatore','Tamil Nadu',11.01680,76.95580),
  ('madurai','Madurai','Tamil Nadu',9.92520,78.11980),
  ('kochi','Kochi','Kerala',9.93120,76.26730),
  ('thiruvananthapuram','Thiruvananthapuram','Kerala',8.52410,76.93660),
  ('kozhikode','Kozhikode','Kerala',11.25880,75.78040),
  ('mysuru','Mysuru','Karnataka',12.29580,76.63940),
  ('mangaluru','Mangaluru','Karnataka',12.91410,74.85600),
  ('vijayawada','Vijayawada','Andhra Pradesh',16.50620,80.64800),
  ('guwahati','Guwahati','Assam',26.14450,91.73620),
  ('bhubaneswar','Bhubaneswar','Odisha',20.29610,85.82450),
  ('ranchi','Ranchi','Jharkhand',23.34410,85.30960),
  ('raipur','Raipur','Chhattisgarh',21.25140,81.62960),
  ('dehradun','Dehradun','Uttarakhand',30.31650,78.03220),
  ('goa','Goa (Panaji)','Goa',15.49090,73.82780),
  ('noida','Noida','Uttar Pradesh',28.53550,77.39100),
  ('gurugram','Gurugram','Haryana',28.45950,77.02660),
  ('jodhpur','Jodhpur','Rajasthan',26.23890,73.02430),
  ('udaipur','Udaipur','Rajasthan',24.58540,73.71250),
  ('tiruchirappalli','Tiruchirappalli','Tamil Nadu',10.79050,78.70470),
  ('aurangabad','Chhatrapati Sambhajinagar','Maharashtra',19.87620,75.34330),
  ('jabalpur','Jabalpur','Madhya Pradesh',23.18150,79.98640),
  ('gwalior','Gwalior','Madhya Pradesh',26.21830,78.18280),
  ('meerut','Meerut','Uttar Pradesh',28.98450,77.70640),
  ('siliguri','Siliguri','West Bengal',26.72710,88.39530);

-- ---------------------------------------------------------------- identity
alter table identity.profiles
  add column gender  text check (gender in ('man','woman','non_binary','prefer_not_to_say')),
  add column city_id text references identity.cities (id);

alter table identity.accounts
  add column rules_accepted_version text,
  add column rules_accepted_at      timestamptz;

-- ---------------------------------------------------------------- packages
alter table economy.diamond_packages
  add column price_paise  bigint check (price_paise > 0),
  add column label        text,
  add column badge        text,
  add column provisional  boolean not null default true;

-- Simulation prices (design D-14: NOT final). Prices include GST.
insert into economy.diamond_packages (product_id, diamonds, active, sort_order, price_paise, label, badge, provisional) values
  ('diamonds_4000',    4000,   true, 1,   9900, 'Starter', null,           true),
  ('diamonds_12500',   12500,  true, 2,  29900, 'Small',   null,           true),
  ('diamonds_26000',   26000,  true, 3,  59900, 'Medium',  null,           true),
  ('diamonds_54000',   54000,  true, 4, 119900, 'Popular', 'Most popular', true),
  ('diamonds_140000',  140000, true, 5, 299900, 'Large',   null,           true),
  ('diamonds_290000',  290000, true, 6, 599900, 'Premium', 'Best value',   true)
on conflict (product_id) do nothing;

-- ---------------------------------------------------------------- commerce
alter table commerce.purchases
  add column rail text not null default 'google_play' check (rail in ('google_play','cashfree'));

-- Cashfree PG orders. Amount always comes from economy.diamond_packages.
create table commerce.cashfree_orders (
  order_id            text primary key check (order_id ~ '^dsh_[a-zA-Z0-9_-]{8,45}$'),
  user_id             uuid not null references identity.accounts (id),
  product_id          text not null references economy.diamond_packages (product_id),
  amount_paise        bigint not null check (amount_paise > 0),
  diamonds            bigint not null check (diamonds > 0),
  payment_session_id  text,
  cf_order_id         text unique,
  environment         text not null check (environment in ('sandbox','production')),
  state               text not null default 'created' check (state in ('created','pending','credited','failed','expired')),
  purchase_id         uuid unique references commerce.purchases (id),
  failure_reason      text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  expires_at          timestamptz not null
);
create index on commerce.cashfree_orders (user_id, created_at desc);
create index on commerce.cashfree_orders (state) where state in ('created','pending');
create trigger cashfree_orders_touch before update on commerce.cashfree_orders
  for each row execute function platform.touch_updated_at();

-- Webhook deliveries (dedupe by sha256 of the signed payload).
create table commerce.cashfree_webhooks (
  delivery_hash  text primary key,
  order_id       text,
  event_type     text not null,
  received_at    timestamptz not null default now(),
  payload        jsonb not null
);

-- ---------------------------------------------------------------- chat
create table chat.read_markers (
  conversation_id  uuid not null references chat.conversations (id),
  user_id          uuid not null references identity.accounts (id),
  last_read_at     timestamptz not null,
  primary key (conversation_id, user_id)
);
create index on chat.conversations (user_a, updated_at desc);
create index on chat.conversations (user_b, updated_at desc);

-- ---------------------------------------------------------------- calls
create index calls_by_caller on calls.calls (caller_id, created_at desc);
create index calls_by_receiver on calls.calls (receiver_id, created_at desc);
alter table calls.calls
  add column moderation_window_ends_at timestamptz,
  add column last_event_at timestamptz;

-- ---------------------------------------------------------------- hosting
alter table hosting.kyc_sessions
  add column provider     text not null default 'manual',
  add column decided_by   uuid references identity.accounts (id),
  add column reason       text;

-- ---------------------------------------------------------------- moderation
-- Frames received per participant during the first 3 minutes (S7). Used to
-- detect a participant who stopped sending frames (queue review).
create index on moderation.frame_checks (call_id, user_id, checked_at);

-- ---------------------------------------------------------------- access control for new tables
do $$
declare t record;
begin
  for t in select * from (values
      ('identity','cities'), ('commerce','cashfree_orders'), ('commerce','cashfree_webhooks'),
      ('chat','read_markers')) as v(s, n)
  loop
    execute format('alter table %I.%I enable row level security', t.s, t.n);
    execute format('alter table %I.%I force row level security', t.s, t.n);
    execute format('create policy service_all on %I.%I for all to api_service, worker_service using (true) with check (true)', t.s, t.n);
    execute format('grant select, insert, update, delete on %I.%I to api_service, worker_service', t.s, t.n);
    execute format('revoke all on %I.%I from anon, authenticated', t.s, t.n);
  end loop;
end $$;

grant select on commerce.cashfree_orders, commerce.cashfree_webhooks to reporting_readonly;
create policy reporting_read on commerce.cashfree_orders for select to reporting_readonly using (true);
create policy reporting_read on commerce.cashfree_webhooks for select to reporting_readonly using (true);
