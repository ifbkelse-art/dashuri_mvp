-- Accounts, profiles, age eligibility, consents, devices.
-- identity.accounts.id equals auth.users.id (Supabase Auth). Personal data is
-- minimised; phone numbers live only in auth.users.

create table identity.accounts (
  id                 uuid primary key references auth.users (id) on delete restrict,
  roles              text[]      not null default array['customer']::text[]
                       check (roles <@ array['customer','host','moderator','admin','finance']::text[]),
  status             text        not null default 'active' check (status in ('active','restricted','suspended','banned','deleted')),
  age_eligible       boolean     not null default false,
  age_method         text        check (age_method in ('self_declared','kyc_verified')),
  date_of_birth      date,       -- self-declared or KYC-verified; needed for the 18+ rule
  who_can_message    text        not null default 'everyone' check (who_can_message in ('everyone','past_call_partners')),
  deleted_at         timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create trigger accounts_touch before update on identity.accounts
  for each row execute function platform.touch_updated_at();

create table identity.profiles (
  user_id        uuid primary key references identity.accounts (id),
  display_name   text not null check (length(display_name) between 1 and 40),
  bio            text check (length(bio) <= 300),
  languages      text[] not null default '{}',
  updated_at     timestamptz not null default now()
);
create trigger profiles_touch before update on identity.profiles
  for each row execute function platform.touch_updated_at();

create table identity.profile_photos (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references identity.accounts (id),
  storage_path  text not null unique,
  status        text not null default 'pending_review' check (status in ('pending_review','approved','rejected')),
  position      smallint not null default 0,
  created_at    timestamptz not null default now()
);
create index on identity.profile_photos (user_id) where status = 'approved';

create table identity.consents (
  user_id     uuid primary key references identity.accounts (id),
  analytics   boolean not null default false,
  marketing   boolean not null default false,
  updated_at  timestamptz not null default now()
);

create table identity.data_requests (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references identity.accounts (id),
  kind          text not null check (kind in ('deletion','export')),
  status        text not null default 'received' check (status in ('received','processing','completed','rejected')),
  scheduled_for timestamptz,
  created_at    timestamptz not null default now(),
  completed_at  timestamptz
);

create table notify.devices (
  token       text primary key,
  user_id     uuid not null references identity.accounts (id),
  platform    text not null check (platform in ('android','ios')),
  updated_at  timestamptz not null default now()
);
create index on notify.devices (user_id);

create table notify.inbox (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references identity.accounts (id),
  kind        text not null,
  title       text not null,
  body        text not null,
  created_at  timestamptz not null default now(),
  read_at     timestamptz
);
create index on notify.inbox (user_id, created_at desc);
