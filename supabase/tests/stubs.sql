-- Minimal stand-ins for Supabase-managed objects, used ONLY by
-- scripts/validate-migrations.sh on a plain local Postgres.
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create schema realtime;
create table realtime.messages (id bigserial primary key, topic text, extension text, payload jsonb);
create function realtime.topic() returns text language sql stable as
  $$ select current_setting('realtime.topic', true) $$;
create schema storage;
create table storage.buckets (id text primary key, name text, public boolean);
create schema extensions;
