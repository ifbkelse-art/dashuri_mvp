-- Reels media processing: claims, attempts and backoff (2026-11-27).
--
-- reels-process-media picked every 'processing' row on each run without
-- claiming it, so two overlapping worker executions transcoded the same reel
-- twice, and a reel failing transiently was retried on every run (head-of-
-- line blocking newer uploads for up to 2 h). Give-up was measured from
-- updated_at, which any write bumps (touch trigger).
--
-- Additive only. A worker claims a row with FOR UPDATE SKIP LOCKED and sets
-- a lease; transient failures release it with a backoff. Moderation is not
-- affected: a processed reel still goes to pending_moderation.

alter table reels.videos
  add column processing_attempts        integer not null default 0 check (processing_attempts >= 0),
  add column processing_started_at      timestamptz,  -- first claim; give-up is measured from here
  add column processing_lease_until     timestamptz,  -- a worker owns the row until then
  add column processing_next_attempt_at timestamptz;  -- backoff after a transient failure

create index reels_videos_processing_due on reels.videos (processing_next_attempt_at nulls first, updated_at)
  where status = 'processing';
