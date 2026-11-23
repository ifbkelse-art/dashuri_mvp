-- EXPERIMENT rollback for a LOCAL or STAGING database where
-- supabase/migrations/20261123000100_reels_experiment.sql was applied.
-- Never run against production (the migration was never applied there).
-- It removes only the separate `reels` schema; no existing table references it.
begin;
drop schema if exists reels cascade;
commit;
-- If the migration was recorded by the Supabase CLI, also remove its row:
-- delete from supabase_migrations.schema_migrations where version = '20261123000100';
