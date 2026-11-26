package postgres

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/keyset"
	"dashuri/backend/internal/modules/safety"
)

// SafetyRepo implements safety.Repository on safety.* and audit.events.
type SafetyRepo struct{ Pool *pgxpool.Pool }

var _ safety.Repository = SafetyRepo{}

func (r SafetyRepo) UserExists(ctx context.Context, userID string) (bool, error) {
	var ok bool
	err := r.Pool.QueryRow(ctx, `select exists (select 1 from identity.accounts where id = $1)`, userID).Scan(&ok)
	return ok, err
}

func (r SafetyRepo) Call(ctx context.Context, callID string) (safety.CallInfo, error) {
	var c safety.CallInfo
	err := r.Pool.QueryRow(ctx, `select caller_id, receiver_id, phase, ended_at, created_at from calls.calls where id = $1`, callID).
		Scan(&c.CallerID, &c.ReceiverID, &c.Phase, &c.EndedAt, &c.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return c, safety.ErrNotFound
	}
	return c, err
}

func (r SafetyRepo) CreateReport(ctx context.Context, n safety.NewReport) (safety.ReportReceipt, error) {
	var rec safety.ReportReceipt
	err := idTx(ctx, r.Pool, func(tx pgx.Tx) error {
		if err := tx.QueryRow(ctx, `
			insert into safety.reports (reporter_id, target_user_id, category, call_id, details, priority)
			values ($1, $2, $3, $4, $5, $6) returning id, status`,
			n.ReporterID, nullIfEmptyTarget(n.TargetID), n.Category, n.CallID, n.Details, n.Priority).Scan(&rec.ReportId, &rec.Status); err != nil {
			return err
		}
		if n.ArrivalPhotoID != nil && n.TargetID != "" {
			// Linked only when the photo is the reported host's own; the
			// purge job keeps a reported photo while the report is open.
			if _, err := tx.Exec(ctx, `
				update safety.reports set arrival_photo_id = ap.id
				  from hosting.arrival_photos ap
				 where safety.reports.id = $1 and ap.id = $2::uuid and ap.host_id = $3::uuid`,
				rec.ReportId, *n.ArrivalPhotoID, n.TargetID); err != nil {
				return err
			}
		}
		return idAudit(ctx, tx, n.ReporterID, "safety.report_created", rec.ReportId, map[string]any{
			"category": n.Category, "priority": n.Priority, "with_call": n.CallID != nil,
		})
	})
	return rec, err
}

func (r SafetyRepo) Block(ctx context.Context, blockerID, blockedID string) (safety.BlockedUser, error) {
	var b safety.BlockedUser
	err := idTx(ctx, r.Pool, func(tx pgx.Tx) error {
		_, err := tx.Exec(ctx, `insert into safety.blocks (blocker_id, blocked_id) values ($1, $2) on conflict do nothing`, blockerID, blockedID)
		if IsForeignKeyViolation(err) {
			return safety.ErrNotFound
		}
		if err != nil {
			return err
		}
		return tx.QueryRow(ctx, `
			select b.blocked_id, coalesce(p.display_name, ''), b.created_at
			  from safety.blocks b left join identity.profiles p on p.user_id = b.blocked_id
			 where b.blocker_id = $1 and b.blocked_id = $2`, blockerID, blockedID).Scan(&b.UserId, &b.DisplayName, &b.BlockedAt)
	})
	return b, err
}

func (r SafetyRepo) Unblock(ctx context.Context, blockerID, blockedID string) error {
	_, err := r.Pool.Exec(ctx, `delete from safety.blocks where blocker_id = $1 and blocked_id = $2`, blockerID, blockedID)
	return err
}

func idAfter(after *keyset.Cursor) (*time.Time, string) {
	if after == nil {
		return nil, "ffffffff-ffff-ffff-ffff-ffffffffffff"
	}
	return &after.At, after.ID
}

func (r SafetyRepo) ListBlocks(ctx context.Context, blockerID string, after *safety.Cursor, limit int) ([]safety.BlockedUser, error) {
	at, id := idAfter(after)
	rows, err := r.Pool.Query(ctx, `
		select b.blocked_id, coalesce(p.display_name, ''), b.created_at
		  from safety.blocks b left join identity.profiles p on p.user_id = b.blocked_id
		 where b.blocker_id = $1 and ($2::timestamptz is null or (b.created_at, b.blocked_id) < ($2::timestamptz, $3::uuid))
		 order by b.created_at desc, b.blocked_id desc limit $4`, blockerID, at, id, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []safety.BlockedUser
	for rows.Next() {
		var b safety.BlockedUser
		if err := rows.Scan(&b.UserId, &b.DisplayName, &b.BlockedAt); err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

func (r SafetyRepo) ListEnforcement(ctx context.Context, userID string, after *safety.Cursor, limit int) ([]safety.EnforcementNotice, error) {
	at, id := idAfter(after)
	rows, err := r.Pool.Query(ctx, `
		select e.id, e.action, e.reason, e.created_at, e.appealable, e.expires_at, ap.status
		  from safety.enforcement_actions e left join safety.appeals ap on ap.enforcement_id = e.id
		 where e.user_id = $1 and ($2::timestamptz is null or (e.created_at, e.id) < ($2::timestamptz, $3::uuid))
		 order by e.created_at desc, e.id desc limit $4`, userID, at, id, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []safety.EnforcementNotice
	for rows.Next() {
		var e safety.EnforcementNotice
		if err := rows.Scan(&e.Id, &e.Action, &e.Reason, &e.CreatedAt, &e.Appealable, &e.ExpiresAt, &e.AppealStatus); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

func (r SafetyRepo) CreateAppeal(ctx context.Context, userID, enforcementID, statement string) (safety.AppealReceipt, error) {
	var rec safety.AppealReceipt
	err := idTx(ctx, r.Pool, func(tx pgx.Tx) error {
		var appealable bool
		err := tx.QueryRow(ctx, `select appealable from safety.enforcement_actions where id = $1 and user_id = $2 for update`, enforcementID, userID).Scan(&appealable)
		if errors.Is(err, pgx.ErrNoRows) {
			return safety.ErrNotFound
		}
		if err != nil {
			return err
		}
		if !appealable {
			return safety.ErrNotAppealable
		}
		err = tx.QueryRow(ctx, `
			insert into safety.appeals (enforcement_id, user_id, statement) values ($1, $2, $3)
			on conflict (enforcement_id) do nothing returning id, status`, enforcementID, userID, statement).Scan(&rec.AppealId, &rec.Status)
		if errors.Is(err, pgx.ErrNoRows) {
			return safety.ErrAppealExists
		}
		if err != nil {
			return err
		}
		return idAudit(ctx, tx, userID, "safety.appeal_submitted", rec.AppealId, map[string]any{"enforcement_id": enforcementID})
	})
	return rec, err
}

// nullIfEmptyTarget stores grievances (no target user) as NULL.
func nullIfEmptyTarget(id string) *string {
	if id == "" {
		return nil
	}
	return &id
}
