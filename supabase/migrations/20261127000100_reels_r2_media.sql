-- Reels media on Cloudflare R2 (docs/reels/DASHURI_REELS_R2_MIGRATION.md).
--
-- R2 stores the files; Postgres keeps the facts and the canonical object
-- keys (never a permanent URL). The API turns keys into short-lived signed
-- URLs, so the media domain can change without rewriting rows.
--
-- Additive only: existing (Mux) rows keep working with these columns null.
-- reels.videos.provider already says where each reel's media lives
-- ('mux' or 'r2'), so both providers can serve during the transition.

alter table reels.videos
  add column width                 integer check (width between 1 and 8192),
  add column height                integer check (height between 1 and 8192),
  add column size_bytes            bigint  check (size_bytes > 0),
  add column video_storage_key     text    check (video_storage_key ~ '^reels/[0-9a-f-]{36}/[a-z0-9_./-]+$'),
  add column thumbnail_storage_key text    check (thumbnail_storage_key ~ '^reels/[0-9a-f-]{36}/[a-z0-9_./-]+$');

comment on column reels.videos.video_storage_key is
  'R2 object key of the playback file (reels/<id>/playback.mp4). Null for Mux reels.';
comment on column reels.videos.thumbnail_storage_key is
  'R2 object key of the poster image (reels/<id>/thumbnail.jpg). Null for Mux reels.';
comment on column reels.videos.size_bytes is
  'Size of the playback file after processing (bytes).';
