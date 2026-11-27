package postgres

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/discovery"
	"dashuri/backend/internal/modules/reels"
	"dashuri/backend/internal/modules/reelsrank"
	"dashuri/backend/internal/platform/db"
)

// ReelsRepo implements reels.Repository on the `reels` schema (EXPERIMENT).
// It only reads identity, hosting, safety and calls tables.
type ReelsRepo struct {
	Pool *pgxpool.Pool
	Tx   db.TxManager
}

var _ reels.Repository = ReelsRepo{}

// rlCreatorCols selects creator facts for creator id expression c, viewer $1.
func rlCreatorCols(c string) string {
	return fmt.Sprintf(`
	  %[1]s, p.display_name,
	  (select ph.storage_path from identity.profile_photos ph where ph.user_id = %[1]s and ph.status = 'approved'
	    order by ph.position, ph.created_at limit 1),
	  cp.bio,
	  coalesce(h.state = 'approved', false), coalesce(h.kyc_state = 'approved', false),
	  case when h.state is distinct from 'approved' then ''
	       when %[2]s then 'busy'
	       when h.is_available and h.last_heartbeat_at > now() - make_interval(secs => %[3]d) then 'online'
	       else 'offline' end,
	  coalesce(h.rate_per_minute, 0),
	  exists (select 1 from reels.follows f where f.follower_id = $1::uuid and f.creator_id = %[1]s)`,
		c, idInLiveCall(c), discovery.HeartbeatWindowSeconds)
}

func rlCreatorJoins(c string) string {
	return fmt.Sprintf(`
	  join identity.accounts ca on ca.id = %[1]s and ca.status in ('active','restricted')
	  join identity.profiles p on p.user_id = %[1]s
	  left join reels.creator_profiles cp on cp.user_id = %[1]s
	  left join hosting.hosts h on h.user_id = %[1]s`, c)
}

func scanCreator(dst *reels.CreatorRow) []any {
	return []any{&dst.UserID, &dst.DisplayName, &dst.PhotoPath, &dst.Bio, &dst.IsHost, &dst.KYCVerified,
		&dst.Availability, &dst.RatePerMin, &dst.FollowedByMe}
}

func (r ReelsRepo) Creator(ctx context.Context, viewerID, creatorID string) (reels.CreatorRow, error) {
	var c reels.CreatorRow
	err := r.Pool.QueryRow(ctx, `select `+rlCreatorCols("ca.id")+` from identity.accounts a0 `+
		rlCreatorJoins("a0.id")+` where a0.id = $2::uuid and not `+idBlockedEither("$1::uuid", "a0.id"),
		viewerID, creatorID).Scan(scanCreator(&c)...)
	if errors.Is(err, pgx.ErrNoRows) {
		return c, reels.ErrNotFound
	}
	return c, err
}

func (r ReelsRepo) CreatorCounts(ctx context.Context, creatorID string) (reels.CreatorCounts, error) {
	var c reels.CreatorCounts
	err := r.Pool.QueryRow(ctx, `select
	   (select count(*) from reels.follows where creator_id = $1),
	   (select count(*) from reels.follows where follower_id = $1),
	   (select count(*) from reels.videos where creator_id = $1 and status = 'published')`, creatorID).
		Scan(&c.Followers, &c.Following, &c.Reels)
	return c, err
}

func (r ReelsRepo) UpsertCreatorBio(ctx context.Context, userID string, bio *string) error {
	_, err := r.Pool.Exec(ctx, `insert into reels.creator_profiles (user_id, bio) values ($1, $2)
	   on conflict (user_id) do update set bio = excluded.bio`, userID, bio)
	return err
}

func (r ReelsRepo) ViewerLanguages(ctx context.Context, userID string) ([]string, error) {
	var langs []string
	err := r.Pool.QueryRow(ctx, `select coalesce((select languages from identity.profiles where user_id = $1), '{}')`, userID).Scan(&langs)
	return langs, err
}

func (r ReelsRepo) AnalyticsConsent(ctx context.Context, userID string) (bool, error) {
	var ok bool
	err := r.Pool.QueryRow(ctx, `select coalesce((select analytics from identity.consents where user_id = $1), false)`, userID).Scan(&ok)
	return ok, err
}

func (r ReelsRepo) Blocked(ctx context.Context, a, b string) (bool, error) {
	var x bool
	err := r.Pool.QueryRow(ctx, `select `+idBlockedEither("$1::uuid", "$2::uuid"), a, b).Scan(&x)
	return x, err
}

// ---------------------------------------------------------------- videos

const rlVideoCols = `v.id, v.creator_id, v.caption, v.language, v.declared_duration_ms, v.duration_ms, v.status,
	v.rejection_code, v.provider, v.provider_upload_id, v.provider_asset_id, v.playback_id, v.like_count,
	v.view_count, v.completed_count, v.share_count,
	exists (select 1 from reels.likes l where l.video_id = v.id and l.user_id = $1::uuid),
	v.published_at, v.created_at, v.updated_at, `

func rlVideoSelect(where string) string {
	return `select ` + rlVideoCols + rlCreatorCols("v.creator_id") + ` from reels.videos v ` +
		rlCreatorJoins("v.creator_id") + ` ` + where
}

func scanVideo(row pgx.Row) (reels.VideoRow, error) {
	var v reels.VideoRow
	dst := []any{&v.ID, &v.CreatorID, &v.Caption, &v.Language, &v.DeclaredMs, &v.DurationMs, &v.Status,
		&v.RejectionCode, &v.Provider, &v.ProviderUploadID, &v.ProviderAssetID, &v.PlaybackID, &v.LikeCount,
		&v.ViewCount, &v.CompletedCount, &v.ShareCount, &v.LikedByMe, &v.PublishedAt, &v.CreatedAt, &v.UpdatedAt}
	dst = append(dst, scanCreator(&v.Creator)...)
	err := row.Scan(dst...)
	if errors.Is(err, pgx.ErrNoRows) {
		return v, reels.ErrNotFound
	}
	return v, err
}

func (r ReelsRepo) videos(ctx context.Context, sql string, args ...any) ([]reels.VideoRow, error) {
	rows, err := r.Pool.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []reels.VideoRow{}
	for rows.Next() {
		v, err := scanVideo(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, v)
	}
	return out, rows.Err()
}

func (r ReelsRepo) CreateVideo(ctx context.Context, v reels.NewVideo) error {
	return r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		// Serialise per creator so the daily limit cannot be raced.
		if _, err := tx.Exec(ctx, `select pg_advisory_xact_lock(hashtextextended('reels-upload:' || $1::text, 0))`, v.CreatorID); err != nil {
			return err
		}
		var n int
		if err := tx.QueryRow(ctx, `select count(*) from reels.videos where creator_id = $1 and created_at >= $2`,
			v.CreatorID, v.DayStartUTC).Scan(&n); err != nil {
			return err
		}
		if n >= v.DailyLimit {
			return reels.ErrUploadLimit
		}
		if _, err := tx.Exec(ctx, `insert into reels.creator_profiles (user_id) values ($1) on conflict do nothing`, v.CreatorID); err != nil {
			return err
		}
		_, err := tx.Exec(ctx, `insert into reels.videos (id, creator_id, caption, language, declared_duration_ms, provider, provider_upload_id)
		   values ($1, $2, $3, $4, $5, $6, $7)`, v.ID, v.CreatorID, v.Caption, v.Language, v.DeclaredMs, v.Provider, v.UploadID)
		return err
	})
}

func (r ReelsRepo) Video(ctx context.Context, viewerID, videoID string) (reels.VideoRow, error) {
	return scanVideo(r.Pool.QueryRow(ctx, rlVideoSelect(`where v.id = $2::uuid`), viewerID, videoID))
}

const rlNilViewer = "00000000-0000-0000-0000-000000000000"

func (r ReelsRepo) VideoByUpload(ctx context.Context, uploadID string) (reels.VideoRow, error) {
	return scanVideo(r.Pool.QueryRow(ctx, rlVideoSelect(`where v.provider_upload_id = $2`), rlNilViewer, uploadID))
}

func (r ReelsRepo) VideoByAsset(ctx context.Context, assetID string) (reels.VideoRow, error) {
	return scanVideo(r.Pool.QueryRow(ctx, rlVideoSelect(`where v.provider_asset_id = $2`), rlNilViewer, assetID))
}

func (r ReelsRepo) MarkProcessing(ctx context.Context, videoID, assetID string) error {
	tag, err := r.Pool.Exec(ctx, `update reels.videos set provider_asset_id = coalesce(provider_asset_id, $2),
	     status = case when status = 'awaiting_upload' then 'processing' else status end
	   where id = $1`, videoID, assetID)
	if err == nil && tag.RowsAffected() == 0 {
		return reels.ErrNotFound
	}
	return err
}

// MarkReady moves processing → pending_moderation (or failed when the real
// duration is outside the allowed range). Idempotent; returns the status.
func (r ReelsRepo) MarkReady(ctx context.Context, videoID string, a reels.AssetInfo, minMs, maxMs int) (string, error) {
	var status string
	err := r.Pool.QueryRow(ctx, `update reels.videos set
	     duration_ms = $2::int, aspect_ratio = nullif($3::text, ''), playback_id = nullif($4::text, ''),
	     width = nullif($7::int, 0), height = nullif($8::int, 0), size_bytes = nullif($9::bigint, 0),
	     video_storage_key = nullif($10::text, ''), thumbnail_storage_key = nullif($11::text, ''),
	     status = case when status not in ('awaiting_upload','processing') then status
	                   when $2::int < $5::int or $2::int > $6::int then 'failed' else 'pending_moderation' end,
	     rejection_code = case when status in ('awaiting_upload','processing') and ($2::int < $5::int or $2::int > $6::int)
	                   then 'duration_out_of_range' else rejection_code end
	   where id = $1 returning status`, videoID, max(1, min(a.DurationMs, 61000)), a.AspectRatio, a.PlaybackID, minMs, maxMs,
		a.Width, a.Height, a.SizeBytes, a.VideoKey, a.ThumbnailKey).Scan(&status)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", reels.ErrNotFound
	}
	return status, err
}

func (r ReelsRepo) MarkFailed(ctx context.Context, videoID, code string) error {
	_, err := r.Pool.Exec(ctx, `update reels.videos set status = 'failed', rejection_code = $2
	   where id = $1 and status in ('awaiting_upload','processing','pending_moderation')`, videoID, code)
	return err
}

func (r ReelsRepo) DeleteVideo(ctx context.Context, creatorID, videoID string, hold time.Time) error {
	tag, err := r.Pool.Exec(ctx, `update reels.videos v set status = 'deleted', deleted_at = now(),
	     evidence_hold_until = case when exists (select 1 from reels.reports rp where rp.video_id = v.id)
	                                  or exists (select 1 from reels.moderation_cases mc where mc.video_id = v.id and mc.status = 'open')
	                                  or v.status in ('rejected','removed')
	                                then greatest(coalesce(v.evidence_hold_until, $3), $3) else v.evidence_hold_until end
	   where v.id = $1 and v.creator_id = $2 and v.status <> 'deleted'`, videoID, creatorID, hold)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return reels.ErrNotFound
	}
	_, err = r.Pool.Exec(ctx, `update reels.moderation_cases set status = 'decided', decided_at = now()
	   where video_id = $1 and status = 'open' and source <> 'report'`, videoID)
	return err
}

func (r ReelsRepo) StaleVideos(ctx context.Context, status string, olderThan time.Time, limit int) ([]reels.VideoRow, error) {
	return r.videos(ctx, rlVideoSelect(`where v.status = $2 and v.updated_at <= $3 order by v.updated_at limit $4`),
		rlNilViewer, status, olderThan, limit)
}

func (r ReelsRepo) ClaimProcessing(ctx context.Context, providers []string, now time.Time, lease time.Duration, limit int) ([]reels.ProcessingClaim, error) {
	if len(providers) == 0 || limit <= 0 {
		return nil, nil
	}
	rows, err := r.Pool.Query(ctx, `
		with due as (
		  select id from reels.videos
		   where status = 'processing' and provider = any($1)
		     and (processing_lease_until is null or processing_lease_until <= $2)
		     and (processing_next_attempt_at is null or processing_next_attempt_at <= $2)
		   order by processing_next_attempt_at nulls first, updated_at, id
		   for update skip locked
		   limit $4)
		update reels.videos v set processing_lease_until = $2 + $3::interval,
		       processing_attempts = v.processing_attempts + 1,
		       processing_started_at = coalesce(v.processing_started_at, $2)
		  from due where v.id = due.id
		returning v.id::text, v.processing_attempts, v.processing_started_at`,
		providers, now, lease.String(), limit)
	if err != nil {
		return nil, err
	}
	type claim struct {
		attempts int
		started  time.Time
	}
	byID := map[string]claim{}
	var ids []string
	for rows.Next() {
		var id string
		var c claim
		if err := rows.Scan(&id, &c.attempts, &c.started); err != nil {
			rows.Close()
			return nil, err
		}
		byID[id] = c
		ids = append(ids, id)
	}
	rows.Close()
	if err := rows.Err(); err != nil || len(ids) == 0 {
		return nil, err
	}
	vs, err := r.videos(ctx, rlVideoSelect(`where v.id = any($2::uuid[]) order by v.updated_at`), rlNilViewer, ids)
	if err != nil {
		return nil, err
	}
	out := make([]reels.ProcessingClaim, 0, len(vs))
	for _, v := range vs {
		c := byID[v.ID]
		out = append(out, reels.ProcessingClaim{Video: v, Attempts: c.attempts, StartedAt: c.started})
	}
	return out, nil
}

func (r ReelsRepo) ReleaseProcessing(ctx context.Context, videoID string, nextAttempt *time.Time, uncount bool) error {
	_, err := r.Pool.Exec(ctx, `update reels.videos set processing_lease_until = null, processing_next_attempt_at = $2,
	       processing_attempts = greatest(processing_attempts - case when $3 then 1 else 0 end, 0)
	 where id = $1 and status = 'processing'`, videoID, nextAttempt, uncount)
	return err
}

func (r ReelsRepo) PurgeCandidates(ctx context.Context, now time.Time, limit int) ([]reels.VideoRow, error) {
	// Account joins are not required here (deleted accounts must be purged too).
	rows, err := r.Pool.Query(ctx, `select id, provider, provider_asset_id from reels.videos
	   where media_purged_at is null and status in ('deleted','rejected','removed','failed')
	     and (evidence_hold_until is null or evidence_hold_until <= $1)
	     and (status in ('deleted','failed') or evidence_hold_until is not null)
	     and not exists (select 1 from reels.appeals ap where ap.video_id = reels.videos.id and ap.status = 'open')
	   order by updated_at limit $2`, now, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []reels.VideoRow
	for rows.Next() {
		var v reels.VideoRow
		if err := rows.Scan(&v.ID, &v.Provider, &v.ProviderAssetID); err != nil {
			return nil, err
		}
		out = append(out, v)
	}
	return out, rows.Err()
}

func (r ReelsRepo) MarkPurged(ctx context.Context, videoID string) error {
	_, err := r.Pool.Exec(ctx, `update reels.videos set media_purged_at = now(), playback_id = null where id = $1`, videoID)
	return err
}

// CleanupDeletedAccounts deletes Reels content of accounts in status
// 'deleted': videos → deleted (media purged by reels-purge-media), likes and
// follows removed, bio cleared. Reports and decisions are kept (audit).
func (r ReelsRepo) CleanupDeletedAccounts(ctx context.Context, limit int) (int, error) {
	n := 0
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		rows, err := tx.Query(ctx, `select a.id from identity.accounts a where a.status = 'deleted' and (
		     exists (select 1 from reels.videos v where v.creator_id = a.id and v.status <> 'deleted')
		  or exists (select 1 from reels.likes l where l.user_id = a.id)
		  or exists (select 1 from reels.follows f where f.follower_id = a.id or f.creator_id = a.id)
		  or exists (select 1 from reels.creator_profiles cp where cp.user_id = a.id and cp.bio is not null))
		  limit $1`, limit)
		if err != nil {
			return err
		}
		var ids []string
		for rows.Next() {
			var id string
			if err := rows.Scan(&id); err != nil {
				rows.Close()
				return err
			}
			ids = append(ids, id)
		}
		rows.Close()
		for _, id := range ids {
			for _, s := range []string{
				`update reels.videos set like_count = greatest(like_count - 1, 0)
				   where id in (select video_id from reels.likes where user_id = $1)`,
				`delete from reels.likes where user_id = $1`,
				`delete from reels.follows where follower_id = $1 or creator_id = $1`,
				`update reels.creator_profiles set bio = null where user_id = $1`,
				`update reels.videos set status = 'deleted', deleted_at = now(), caption = ''
				   where creator_id = $1 and status <> 'deleted'`,
				`update reels.moderation_cases set status = 'decided', decided_at = now()
				   where status = 'open' and video_id in (select id from reels.videos where creator_id = $1)`,
			} {
				if _, err := tx.Exec(ctx, s, id); err != nil {
					return err
				}
			}
			if _, err := tx.Exec(ctx, `insert into audit.events (actor, action, target, details)
			    values ('system:reels-account-cleanup', 'reels.account_content_deleted', $1, '{}'::jsonb)`, id); err != nil {
				return err
			}
			n++
		}
		return nil
	})
	return n, err
}

func (r ReelsRepo) HasApprovedReel(ctx context.Context, creatorID string) (bool, error) {
	var ok bool
	err := r.Pool.QueryRow(ctx, `select exists (select 1 from reels.moderation_decisions d
	   join reels.videos v on v.id = d.video_id
	   where v.creator_id = $1 and d.source = 'moderator' and d.decision in ('approve','restore'))`, creatorID).Scan(&ok)
	return ok, err
}

// ---------------------------------------------------------------- feeds

const rlVisibleToViewer = `v.status = 'published' and not exists (select 1 from safety.blocks bl
	   where (bl.blocker_id = $1::uuid and bl.blocked_id = v.creator_id) or (bl.blocker_id = v.creator_id and bl.blocked_id = $1::uuid))
	 and not exists (select 1 from reels.reports rr where rr.video_id = v.id and rr.reporter_id = $1::uuid)`

func (r ReelsRepo) FeedCandidates(ctx context.Context, viewerID string, asOf time.Time, limit int) ([]reelsrank.Candidate, error) {
	rows, err := r.Pool.Query(ctx, `
	  select v.id, v.creator_id, v.published_at, coalesce(v.language, ''), v.like_count, v.view_count, v.completed_count,
	         (select count(*) from reels.reports rp where rp.video_id = v.id),
	         exists (select 1 from reels.follows f where f.follower_id = $1::uuid and f.creator_id = v.creator_id),
	         exists (select 1 from reels.views vw where vw.video_id = v.id and vw.viewer_id = $1::uuid),
	         coalesce(h.state = 'approved', false),
	         coalesce(h.state = 'approved' and h.is_available and h.last_heartbeat_at > now() - make_interval(secs => `+fmt.Sprint(discovery.HeartbeatWindowSeconds)+`), false),
	         (select count(*) from reels.likes l join reels.videos v2 on v2.id = l.video_id
	           where l.user_id = $1::uuid and v2.creator_id = v.creator_id)
	    from reels.videos v
	    join identity.accounts ca on ca.id = v.creator_id and ca.status in ('active','restricted')
	    left join hosting.hosts h on h.user_id = v.creator_id
	   where `+rlVisibleToViewer+` and v.creator_id <> $1::uuid
	     and v.published_at <= $2 and v.published_at > $2 - interval '30 days'
	   order by v.published_at desc, v.id desc
	   limit $3`, viewerID, asOf, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []reelsrank.Candidate
	for rows.Next() {
		var c reelsrank.Candidate
		if err := rows.Scan(&c.VideoID, &c.CreatorID, &c.PublishedAt, &c.Language, &c.Likes, &c.Views, &c.Completions,
			&c.Reports, &c.Following, &c.SeenByViewer, &c.CreatorIsHost, &c.HostOnline, &c.CreatorLikedBy); err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

func (r ReelsRepo) FollowingFeed(ctx context.Context, viewerID string, after *reels.Keyset, limit int) ([]reels.VideoRow, error) {
	at, id := rlKeyset(after)
	return r.videos(ctx, rlVideoSelect(`where `+rlVisibleToViewer+`
	   and exists (select 1 from reels.follows f where f.follower_id = $1::uuid and f.creator_id = v.creator_id)
	   and ($2::timestamptz is null or (v.published_at, v.id) < ($2, $3::uuid))
	   order by v.published_at desc, v.id desc limit $4`), viewerID, at, id, limit)
}

func rlKeyset(k *reels.Keyset) (*time.Time, *string) {
	if k == nil {
		return nil, nil
	}
	return &k.At, &k.ID
}

func (r ReelsRepo) CreatorVideos(ctx context.Context, viewerID, creatorID string, includeUnpublished bool, after *reels.Keyset, limit int) ([]reels.VideoRow, error) {
	at, id := rlKeyset(after)
	return r.videos(ctx, rlVideoSelect(`where v.creator_id = $2::uuid
	   and (case when $3 then v.status <> 'deleted' else v.status = 'published' end)
	   and ($4::timestamptz is null or (v.created_at, v.id) < ($4, $5::uuid))
	   order by v.created_at desc, v.id desc limit $6`), viewerID, creatorID, includeUnpublished, at, id, limit)
}

func (r ReelsRepo) VideosByIDs(ctx context.Context, viewerID string, ids []string) ([]reels.VideoRow, error) {
	if len(ids) == 0 {
		return []reels.VideoRow{}, nil
	}
	return r.videos(ctx, rlVideoSelect(`where v.id = any($2::uuid[])`), viewerID, ids)
}

// ---------------------------------------------------------------- engagement

func (r ReelsRepo) Like(ctx context.Context, userID, videoID string) (int, error) {
	var n int
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `insert into reels.likes (user_id, video_id) values ($1, $2) on conflict do nothing`, userID, videoID)
		if err != nil {
			return err
		}
		q := `select like_count from reels.videos where id = $1`
		if tag.RowsAffected() == 1 {
			q = `update reels.videos set like_count = like_count + 1 where id = $1 returning like_count`
		}
		return tx.QueryRow(ctx, q, videoID).Scan(&n)
	})
	if IsForeignKeyViolation(err) || errors.Is(err, pgx.ErrNoRows) {
		return 0, reels.ErrNotFound
	}
	return n, err
}

func (r ReelsRepo) Unlike(ctx context.Context, userID, videoID string) (int, error) {
	var n int
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		tag, err := tx.Exec(ctx, `delete from reels.likes where user_id = $1 and video_id = $2`, userID, videoID)
		if err != nil {
			return err
		}
		q := `select like_count from reels.videos where id = $1`
		if tag.RowsAffected() == 1 {
			q = `update reels.videos set like_count = greatest(like_count - 1, 0) where id = $1 returning like_count`
		}
		return tx.QueryRow(ctx, q, videoID).Scan(&n)
	})
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, reels.ErrNotFound
	}
	return n, err
}

func (r ReelsRepo) Follow(ctx context.Context, followerID, creatorID string) error {
	_, err := r.Pool.Exec(ctx, `insert into reels.follows (follower_id, creator_id) values ($1, $2) on conflict do nothing`, followerID, creatorID)
	return err
}

func (r ReelsRepo) Unfollow(ctx context.Context, followerID, creatorID string) error {
	_, err := r.Pool.Exec(ctx, `delete from reels.follows where follower_id = $1 and creator_id = $2`, followerID, creatorID)
	return err
}

func (r ReelsRepo) CountShare(ctx context.Context, videoID string) error {
	_, err := r.Pool.Exec(ctx, `update reels.videos set share_count = share_count + 1 where id = $1`, videoID)
	return err
}

// RecordView upserts the (video, viewer, day) row; the first row of a day
// increments view_count, the first completion increments completed_count.
// Only published videos count; own views are not counted.
func (r ReelsRepo) RecordView(ctx context.Context, viewerID, videoID string, day time.Time, watchedMs int, completed bool) error {
	return r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		var creator string
		err := tx.QueryRow(ctx, `select creator_id from reels.videos where id = $1 and status = 'published'`, videoID).Scan(&creator)
		if errors.Is(err, pgx.ErrNoRows) {
			return reels.ErrNotFound
		}
		if err != nil || creator == viewerID {
			return err
		}
		var inserted, wasCompleted bool
		err = tx.QueryRow(ctx, `
		  with prev as (select completed from reels.views where video_id = $1 and viewer_id = $2 and day = $3::date)
		  insert into reels.views as w (video_id, viewer_id, day, watched_ms, completed)
		  values ($1, $2, $3::date, $4, $5)
		  on conflict (video_id, viewer_id, day) do update
		     set watched_ms = greatest(w.watched_ms, excluded.watched_ms),
		         completed = w.completed or excluded.completed, updated_at = now()
		  returning (xmax = 0), coalesce((select completed from prev), false)`,
			videoID, viewerID, day, watchedMs, completed).Scan(&inserted, &wasCompleted)
		if err != nil {
			return err
		}
		if inserted {
			if _, err := tx.Exec(ctx, `update reels.videos set view_count = view_count + 1 where id = $1`, videoID); err != nil {
				return err
			}
		}
		if completed && !wasCompleted {
			_, err = tx.Exec(ctx, `update reels.videos set completed_count = completed_count + 1 where id = $1`, videoID)
		}
		return err
	})
}

func (r ReelsRepo) InsertEvents(ctx context.Context, userID string, evs []reels.Event) error {
	b := &pgx.Batch{}
	for _, e := range evs {
		// creator_id is derived from the video when present (never trusted).
		b.Queue(`insert into reels.feed_events (user_id, event, video_id, creator_id, value_ms, session_id)
		  select $1, $2, v.id, coalesce(v.creator_id, c.id), $5, $6
		    from (select 1) one
		    left join reels.videos v on v.id = $3::uuid
		    left join identity.accounts c on c.id = $4::uuid
		   where ($3::uuid is null or v.id is not null) and ($4::uuid is null or c.id is not null or v.id is not null)`,
			userID, e.Name, e.VideoID, e.CreatorID, e.ValueMs, e.SessionID)
	}
	return r.Pool.SendBatch(ctx, b).Close()
}

// ---------------------------------------------------------------- moderation

func scoresJSON(m map[string]float64) []byte {
	if m == nil {
		return nil
	}
	b, _ := json.Marshal(m)
	return b
}

// ApplyAutomated records the automated outcome for a pending_moderation
// video: approve → decision + published; reject → decision + rejected (with
// evidence hold); review → in_review + an open case.
func (r ReelsRepo) ApplyAutomated(ctx context.Context, videoID string, o reels.ModerationOutcome) (string, error) {
	var status string
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		if err := tx.QueryRow(ctx, `select status from reels.videos where id = $1 for update`, videoID).Scan(&status); err != nil {
			return err
		}
		if status != "pending_moderation" {
			return nil // already handled (job rerun)
		}
		switch o.Decision {
		case "approve", "reject":
			if _, err := tx.Exec(ctx, `insert into reels.moderation_decisions (video_id, decision, reason_code, note, source)
			   values ($1, $2, $3, $4, 'automated')`, videoID, o.Decision, o.ReasonCode, string(scoresJSON(o.Scores))); err != nil {
				return err
			}
			if o.Decision == "approve" {
				status = "published"
				_, err := tx.Exec(ctx, `update reels.videos set status = 'published', published_at = now(), rejection_code = null where id = $1`, videoID)
				return err
			}
			status = "rejected"
			_, err := tx.Exec(ctx, `update reels.videos set status = 'rejected', rejection_code = $2, evidence_hold_until = $3 where id = $1`,
				videoID, o.ReasonCode, o.EvidenceHold)
			return err
		default:
			status = "in_review"
			if _, err := tx.Exec(ctx, `insert into reels.moderation_cases (video_id, source, priority, automated_scores)
			   values ($1, $2, $3, $4) on conflict (video_id) where status = 'open' do nothing`,
				videoID, o.CaseSource, max(1, min(o.Priority, 5)), scoresJSON(o.Scores)); err != nil {
				return err
			}
			_, err := tx.Exec(ctx, `update reels.videos set status = 'in_review' where id = $1`, videoID)
			return err
		}
	})
	return status, err
}

var rlReportPriority = map[string]int{"minor_safety": 1, "nudity": 1, "sexual_content": 2, "violence": 2, "hate": 2,
	"harassment": 3, "privacy": 3, "copyright": 3, "spam_or_scam": 4, "other": 4}

// Report stores a report and opens (or escalates) a case. minor_safety and
// nudity, or hideThreshold distinct reporters, pull the video into review.
func (r ReelsRepo) Report(ctx context.Context, reporterID, videoID, category string, details *string, hideThreshold int) (bool, error) {
	hidden := false
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		var status string
		if err := tx.QueryRow(ctx, `select status from reels.videos where id = $1 for update`, videoID).Scan(&status); err != nil {
			return err
		}
		tag, err := tx.Exec(ctx, `insert into reels.reports (video_id, reporter_id, category, details) values ($1, $2, $3, $4)
		   on conflict (video_id, reporter_id) do nothing`, videoID, reporterID, category, details)
		if err != nil {
			return err
		}
		if tag.RowsAffected() == 0 {
			return reels.ErrAlreadyReported
		}
		prio := rlReportPriority[category]
		if prio == 0 {
			prio = 4
		}
		if _, err := tx.Exec(ctx, `insert into reels.moderation_cases (video_id, source, priority) values ($1, 'report', $2)
		   on conflict (video_id) where status = 'open' do update set priority = least(reels.moderation_cases.priority, excluded.priority)`,
			videoID, prio); err != nil {
			return err
		}
		var n int
		if err := tx.QueryRow(ctx, `select count(*) from reels.reports where video_id = $1`, videoID).Scan(&n); err != nil {
			return err
		}
		if status == "published" && (prio == 1 || n >= hideThreshold) {
			hidden = true
			_, err := tx.Exec(ctx, `update reels.videos set status = 'in_review' where id = $1`, videoID)
			return err
		}
		return nil
	})
	return hidden, err
}

func (r ReelsRepo) Appeal(ctx context.Context, creatorID, videoID, statement string) error {
	return r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		var owner, status string
		err := tx.QueryRow(ctx, `select creator_id, status from reels.videos where id = $1 for update`, videoID).Scan(&owner, &status)
		if errors.Is(err, pgx.ErrNoRows) {
			return reels.ErrNotFound
		}
		if err != nil {
			return err
		}
		if owner != creatorID {
			return reels.ErrNotOwner
		}
		if status != "rejected" && status != "removed" {
			return reels.ErrAppealNotAllowed
		}
		if _, err := tx.Exec(ctx, `insert into reels.appeals (video_id, creator_id, statement) values ($1, $2, $3)`, videoID, creatorID, statement); err != nil {
			if IsUniqueViolation(err) {
				return reels.ErrAlreadyAppealed
			}
			return err
		}
		_, err = tx.Exec(ctx, `insert into reels.moderation_cases (video_id, source, priority) values ($1, 'appeal', 3)
		   on conflict (video_id) where status = 'open' do nothing`, videoID)
		return err
	})
}

func (r ReelsRepo) Queue(ctx context.Context, after *reels.Keyset, limit int) ([]reels.QueueItem, error) {
	at, id := rlKeyset(after)
	rows, err := r.Pool.Query(ctx, `select mc.id, mc.source, mc.priority, mc.automated_scores, mc.created_at, mc.video_id,
	     (select count(*) from reels.reports rp where rp.video_id = mc.video_id),
	     (select ap.statement from reels.appeals ap where ap.video_id = mc.video_id and ap.status = 'open')
	   from reels.moderation_cases mc
	  where mc.status = 'open' and ($1::timestamptz is null or (mc.created_at, mc.id) > ($1, $2::uuid))
	  order by mc.created_at, mc.id limit $3`, at, id, limit)
	if err != nil {
		return nil, err
	}
	var items []reels.QueueItem
	var vids []string
	for rows.Next() {
		var it reels.QueueItem
		var scores []byte
		var vid string
		if err := rows.Scan(&it.CaseID, &it.Source, &it.Priority, &scores, &it.CreatedAt, &vid, &it.Reports, &it.Appeal); err != nil {
			rows.Close()
			return nil, err
		}
		if len(scores) > 0 {
			_ = json.Unmarshal(scores, &it.Scores)
		}
		it.Video.ID = vid
		items = append(items, it)
		vids = append(vids, vid)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	vs, err := r.VideosByIDs(ctx, rlNilViewer, vids)
	if err != nil {
		return nil, err
	}
	byID := map[string]reels.VideoRow{}
	for _, v := range vs {
		byID[v.ID] = v
	}
	out := items[:0]
	for _, it := range items {
		if v, ok := byID[it.Video.ID]; ok {
			it.Video = v
			out = append(out, it)
		}
	}
	return out, nil
}

// Decide applies a moderator decision. Allowed transitions:
//
//	approve: pending_moderation | in_review → published (also overturns an appeal: rejected/removed → published)
//	reject:  pending_moderation | in_review → rejected
//	remove:  published | in_review → removed
//	restore: rejected | removed → published (appeal overturned)
func (r ReelsRepo) Decide(ctx context.Context, moderatorID, videoID, decision, reasonCode string, note *string, now time.Time) (string, error) {
	var status string
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		var cur string
		err := tx.QueryRow(ctx, `select status from reels.videos where id = $1 for update`, videoID).Scan(&cur)
		if errors.Is(err, pgx.ErrNoRows) {
			return reels.ErrNotFound
		}
		if err != nil {
			return err
		}
		allowed := map[string][]string{
			"approve": {"pending_moderation", "in_review"},
			"reject":  {"pending_moderation", "in_review"},
			"remove":  {"published", "in_review"},
			"restore": {"rejected", "removed"},
		}[decision]
		ok := false
		for _, s := range allowed {
			ok = ok || s == cur
		}
		if !ok {
			return reels.ErrIllegalDecision
		}
		var caseID *string
		_ = tx.QueryRow(ctx, `select id from reels.moderation_cases where video_id = $1 and status = 'open'`, videoID).Scan(&caseID)
		if _, err := tx.Exec(ctx, `insert into reels.moderation_decisions (video_id, case_id, decision, reason_code, note, source, decided_by)
		   values ($1, $2, $3, $4, $5, 'moderator', $6)`, videoID, caseID, decision, reasonCode, note, moderatorID); err != nil {
			return err
		}
		hold := now.Add(reels.EvidenceHold)
		switch decision {
		case "approve", "restore":
			status = "published"
			_, err = tx.Exec(ctx, `update reels.videos set status = 'published', published_at = coalesce(published_at, now()),
			   rejection_code = null, evidence_hold_until = null where id = $1`, videoID)
		case "reject":
			status = "rejected"
			_, err = tx.Exec(ctx, `update reels.videos set status = 'rejected', rejection_code = $2, evidence_hold_until = $3 where id = $1`, videoID, reasonCode, hold)
		case "remove":
			status = "removed"
			_, err = tx.Exec(ctx, `update reels.videos set status = 'removed', rejection_code = $2, evidence_hold_until = $3 where id = $1`, videoID, reasonCode, hold)
		}
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update reels.moderation_cases set status = 'decided', decided_at = now() where video_id = $1 and status = 'open'`, videoID); err != nil {
			return err
		}
		appeal := map[string]string{"restore": "overturned", "approve": "overturned", "reject": "upheld", "remove": "upheld"}[decision]
		if _, err := tx.Exec(ctx, `update reels.appeals set status = $2, decided_by = $3, decided_at = now() where video_id = $1 and status = 'open'`,
			videoID, appeal, moderatorID); err != nil {
			return err
		}
		_, err = tx.Exec(ctx, `insert into audit.events (actor, action, target, details) values ($1::text, 'reels.moderation_decision', $2, jsonb_build_object('decision', $3::text, 'reason', $4::text))`,
			moderatorID, videoID, decision, reasonCode)
		return err
	})
	return status, err
}

// Analytics aggregates events and reel-attributed calls. Attribution: a call
// counts only if the caller clicked that host's reel call CTA within
// windowMin minutes before creating it, and had no ended paid call with that
// host in the 30 days before the click (existing relationships are not
// credited to Reels).
func (r ReelsRepo) Analytics(ctx context.Context, from, to time.Time, windowMin int) (reels.AnalyticsSummary, error) {
	a := reels.AnalyticsSummary{From: from, To: to, AttributionWindowMin: windowMin}
	err := r.Pool.QueryRow(ctx, `
	  with ev as (select event, count(*) n, coalesce(sum(value_ms) filter (where event = 'reel_watch_duration'), 0) ms
	                from reels.feed_events where created_at >= $1 and created_at < $2 group by event),
	  att as (
	    select distinct on (c.id) c.id, c.phase, c.billed_seconds, c.diamonds_charged
	      from calls.calls c
	      join reels.feed_events e on e.event = 'host_call_cta_clicked' and e.user_id = c.caller_id and e.creator_id = c.receiver_id
	       and c.created_at between e.created_at and e.created_at + make_interval(mins => $3)
	     where c.created_at >= $1 and c.created_at < $2 and not c.is_free_call
	       and not exists (select 1 from calls.calls p where p.caller_id = c.caller_id and p.receiver_id = c.receiver_id
	                        and p.phase = 'ended' and coalesce(p.billed_seconds, 0) > 0
	                        and p.ended_at < e.created_at and p.ended_at > e.created_at - interval '30 days')
	     order by c.id, e.created_at desc)
	  select
	    (select count(*) from reels.videos where published_at >= $1 and published_at < $2),
	    (select count(distinct creator_id) from reels.videos where published_at >= $1 and published_at < $2),
	    coalesce((select n from ev where event = 'reel_impression'), 0),
	    coalesce((select n from ev where event = 'reel_play_started'), 0),
	    coalesce((select n from ev where event = 'reel_play_completed'), 0),
	    coalesce((select ms from ev where event = 'reel_watch_duration'), 0),
	    (select count(*) from reels.likes where created_at >= $1 and created_at < $2),
	    (select count(*) from reels.follows where created_at >= $1 and created_at < $2),
	    coalesce((select n from ev where event = 'reel_shared'), 0),
	    (select count(*) from reels.reports where created_at >= $1 and created_at < $2),
	    coalesce((select n from ev where event = 'creator_profile_opened'), 0),
	    coalesce((select n from ev where event = 'host_call_cta_clicked'), 0),
	    (select count(*) from att),
	    (select count(*) from att where phase = 'ended' and coalesce(billed_seconds, 0) > 0),
	    coalesce((select sum(billed_seconds) from att), 0),
	    coalesce((select sum(diamonds_charged) from att), 0)`, from, to, windowMin).Scan(
		&a.Published, &a.ActiveCreators, &a.Impressions, &a.PlaysStarted, &a.PlaysCompleted, &a.WatchMs,
		&a.Likes, &a.Follows, &a.Shares, &a.Reports, &a.ProfileOpens, &a.CTAClicks,
		&a.AttributedCalls, &a.AttributedCompleted, &a.AttributedPaidSecs, &a.AttributedDiamonds)
	return a, err
}

func (r ReelsRepo) RecordWebhook(ctx context.Context, provider, hash, eventType string) (bool, error) {
	tag, err := r.Pool.Exec(ctx, `insert into reels.provider_webhooks (delivery_hash, provider, event_type) values ($1, $2, $3)
	   on conflict do nothing`, hash, provider, eventType)
	if err != nil {
		return false, err
	}
	return tag.RowsAffected() == 1, nil
}
