package postgres

import (
	"context"
	"errors"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"dashuri/backend/internal/modules/hosts"
)

// Arrival photos and online sessions (migration 20261126000100) on
// HostsRepo. Sessions are opened and closed by the hosting.hosts trigger;
// this code only reads them.

var _ hosts.ArrivalRepository = HostsRepo{}

func (r HostsRepo) OpenSession(ctx context.Context, hostID string) (hosts.OnlineSession, error) {
	var s hosts.OnlineSession
	err := r.Pool.QueryRow(ctx, `select id, host_id, started_at, ended_at from hosting.online_sessions
		where host_id = $1 and ended_at is null`, hostID).Scan(&s.ID, &s.HostID, &s.StartedAt, &s.EndedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return s, hosts.ErrNotOnline
	}
	return s, err
}

func (r HostsRepo) CreateArrivalPhoto(ctx context.Context, hostID, photoID, path string, uploadExpires time.Time, sign func(string) (string, error)) (string, string, error) {
	var sessionID, url string
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		var available bool
		if err := tx.QueryRow(ctx, `select is_available from hosting.hosts where user_id = $1 and state = 'approved' for update`, hostID).
			Scan(&available); err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return hosts.ErrNotOnline
			}
			return err
		}
		if !available {
			return hosts.ErrNotOnline
		}
		err := tx.QueryRow(ctx, `select id from hosting.online_sessions where host_id = $1 and ended_at is null`, hostID).Scan(&sessionID)
		if errors.Is(err, pgx.ErrNoRows) {
			return hosts.ErrNotOnline
		}
		if err != nil {
			return err
		}
		// A new photo replaces the session's current one (never reused).
		if _, err := tx.Exec(ctx, `
			update hosting.arrival_photos set status = 'removed', decision_reason = 'replaced', decided_by = $2::text,
			       ended_at = now(), decided_at = now(), purge_after = now() + interval '24 hours'
			 where session_id = $1 and status in ('awaiting_upload','pending_review','approved')`, sessionID, hostID); err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `
			insert into hosting.arrival_photos (id, host_id, session_id, content_type, storage_path, upload_expires_at)
			values ($1, $2, $3, 'image/jpeg', $4, $5)`, photoID, hostID, sessionID, path, uploadExpires); err != nil {
			return err
		}
		url, err = sign(path)
		return err
	})
	return sessionID, url, err
}

const arrivalSelect = `
	select p.id, p.host_id, p.session_id, p.status, p.storage_path, p.content_type, p.byte_size, p.width, p.height,
	       p.moderation_source, p.decision_reason, p.upload_expires_at, p.captured_at, p.created_at,
	       (s.ended_at is null), coalesce(pr.display_name, '')
	  from hosting.arrival_photos p
	  join hosting.online_sessions s on s.id = p.session_id
	  left join identity.profiles pr on pr.user_id = p.host_id`

func scanArrival(row pgx.Row) (hosts.ArrivalPhoto, error) {
	var p hosts.ArrivalPhoto
	err := row.Scan(&p.ID, &p.HostID, &p.SessionID, &p.Status, &p.StoragePath, &p.ContentType, &p.ByteSize, &p.Width, &p.Height,
		&p.ModerationSource, &p.DecisionReason, &p.UploadExpiresAt, &p.CapturedAt, &p.CreatedAt, &p.SessionOpen, &p.HostName)
	if errors.Is(err, pgx.ErrNoRows) {
		return p, hosts.ErrArrivalNotFound
	}
	return p, err
}

func (r HostsRepo) ArrivalPhoto(ctx context.Context, photoID string) (hosts.ArrivalPhoto, error) {
	return scanArrival(r.Pool.QueryRow(ctx, arrivalSelect+` where p.id = $1`, photoID))
}

func (r HostsRepo) CurrentArrivalPhoto(ctx context.Context, hostID string) (*hosts.ArrivalPhoto, error) {
	p, err := scanArrival(r.Pool.QueryRow(ctx, arrivalSelect+`
		 where p.host_id = $1 and s.ended_at is null and p.status in ('awaiting_upload','pending_review','approved')
		 order by p.created_at desc limit 1`, hostID))
	if errors.Is(err, hosts.ErrArrivalNotFound) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r HostsRepo) DecideArrivalPhoto(ctx context.Context, photoID string, decide func(hosts.ArrivalPhoto) (hosts.ArrivalDecision, error)) (hosts.ArrivalPhoto, error) {
	var out hosts.ArrivalPhoto
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		cur, err := scanArrival(tx.QueryRow(ctx, arrivalSelect+` where p.id = $1 for update of p`, photoID))
		if err != nil {
			return err
		}
		d, err := decide(cur)
		if err != nil {
			return err
		}
		ended := d.Status == hosts.ArrivalRejected || d.Status == hosts.ArrivalRemoved || d.Status == hosts.ArrivalExpired
		var size, w, h *int
		if d.ByteSize > 0 {
			size, w, h = &d.ByteSize, &d.Width, &d.Height
		}
		var source, reason *string
		if d.ModerationSource != "" {
			source = &d.ModerationSource
		}
		if d.Reason != "" {
			reason = &d.Reason
		}
		if _, err := tx.Exec(ctx, `
			update hosting.arrival_photos set
			  status = $2,
			  byte_size = coalesce($3, byte_size), width = coalesce($4, width), height = coalesce($5, height),
			  moderation_source = coalesce($6, moderation_source), moderation_score = coalesce($7, moderation_score),
			  decision_reason = coalesce($8, decision_reason), decided_by = $9,
			  captured_at = case when status = 'awaiting_upload' then $10 else captured_at end,
			  decided_at = $10,
			  ended_at = case when $11 then $10 else ended_at end,
			  purge_after = coalesce($12, purge_after)
			 where id = $1`,
			photoID, d.Status, size, w, h, source, d.Score, reason, d.DecidedBy, d.At, ended, d.PurgeAfter); err != nil {
			return err
		}
		if !strings.HasPrefix(d.DecidedBy, "system:") {
			// Staff decisions and host removals are audited (no image data).
			if err := callsAudit(ctx, tx, d.DecidedBy, "arrival_photo."+d.Status, photoID,
				map[string]any{"host_id": cur.HostID, "from": cur.Status, "reason": d.Reason}); err != nil {
				return err
			}
		}
		out, err = scanArrival(tx.QueryRow(ctx, arrivalSelect+` where p.id = $1`, photoID))
		return err
	})
	return out, err
}

func (r HostsRepo) ArrivalReviewQueue(ctx context.Context, limit int) ([]hosts.ArrivalPhoto, error) {
	rows, err := r.Pool.Query(ctx, arrivalSelect+` where p.status = 'pending_review' order by p.created_at limit $1`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []hosts.ArrivalPhoto{}
	for rows.Next() {
		p, err := scanArrival(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

func (r HostsRepo) ExpireAbandonedArrivalUploads(ctx context.Context, now time.Time) (int64, error) {
	tag, err := r.Pool.Exec(ctx, `
		update hosting.arrival_photos set status = 'expired', ended_at = $1, purge_after = $1
		 where status = 'awaiting_upload' and upload_expires_at < $1`, now)
	return tag.RowsAffected(), err
}

func (r HostsRepo) ArrivalPhotosDueForPurge(ctx context.Context, now time.Time, limit int) ([]hosts.ArrivalPhoto, error) {
	rows, err := r.Pool.Query(ctx, arrivalSelect+`
		 where p.purged_at is null and p.purge_after is not null and p.purge_after <= $1
		   and p.status in ('expired','removed','rejected')
		   and not exists (select 1 from safety.reports rp where rp.arrival_photo_id = p.id and rp.status in ('open','in_review'))
		 order by p.purge_after limit $2`, now, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []hosts.ArrivalPhoto{}
	for rows.Next() {
		p, err := scanArrival(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

func (r HostsRepo) MarkArrivalPurged(ctx context.Context, photoID string, at time.Time) error {
	_, err := r.Pool.Exec(ctx, `update hosting.arrival_photos set purged_at = $2 where id = $1`, photoID, at)
	return err
}
