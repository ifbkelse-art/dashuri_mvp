package postgres

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/moderation"
	"dashuri/backend/internal/platform/db"
)

// ModerationRepo implements moderation.Repository.
type ModerationRepo struct {
	Pool *pgxpool.Pool
	Tx   db.TxManager
}

var _ moderation.Repository = ModerationRepo{}

func (r ModerationRepo) CallInfo(ctx context.Context, callID string) (moderation.CallInfo, error) {
	var c moderation.CallInfo
	err := r.Pool.QueryRow(ctx, `select id, caller_id, receiver_id, phase, connected_at, moderation_window_ends_at, ended_at
		from calls.calls where id = $1`, callID).
		Scan(&c.ID, &c.CallerID, &c.ReceiverID, &c.Phase, &c.ConnectedAt, &c.ModerationWindowEndsAt, &c.EndedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return c, moderation.ErrNotFound
	}
	return c, err
}

func clamp01(v float64) float64 { return min(max(v, 0), 1) }

func (r ModerationRepo) RecordFrameCheck(ctx context.Context, f moderation.FrameCheck) (int64, error) {
	var id int64
	err := r.Pool.QueryRow(ctx, `insert into moderation.frame_checks (call_id, user_id, checked_at, vendor, nudity, sexual, flagged, action)
		values ($1, $2, $3, $4, $5, $6, $7, $8) returning id`,
		f.CallID, f.UserID, f.At, f.Score.Vendor, clamp01(f.Score.Explicit()), clamp01(f.Score.SexualActivity), f.Flagged, f.Action).Scan(&id)
	return id, err
}

func (r ModerationRepo) OpenAutomatedCase(ctx context.Context, c moderation.AutomatedCase) (string, bool, error) {
	var id string
	created := false
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		err := tx.QueryRow(ctx, `insert into safety.reports (reporter_id, target_user_id, category, call_id, details, priority, source, automated_reason)
			values (null, $1, $2, $3, left($4, 1000), $5, 'automated', $6)
			on conflict (call_id, target_user_id, automated_reason) where source = 'automated' do nothing
			returning id`, c.TargetUserID, c.Category, c.CallID, c.Details, c.Priority, c.Reason).Scan(&id)
		if errors.Is(err, pgx.ErrNoRows) {
			return tx.QueryRow(ctx, `select id from safety.reports where source = 'automated' and call_id = $1
				and target_user_id = $2 and automated_reason = $3`, c.CallID, c.TargetUserID, c.Reason).Scan(&id)
		}
		if err != nil {
			return err
		}
		created = true
		if _, err := tx.Exec(ctx, `insert into moderation.evidence (report_id, call_id, kind, storage_ref, retain_until)
			values ($1, $2, 'metadata', $3, $4)`, id, c.CallID, c.EvidenceRef, c.RetainUntil); err != nil {
			return err
		}
		return callsAudit(ctx, tx, "system:moderation", "moderation.case_opened", id,
			map[string]any{"call_id": c.CallID, "reason": c.Reason, "priority": c.Priority})
	})
	return id, created, err
}

func (r ModerationRepo) Queue(ctx context.Context, after *moderation.QueueCursor, limit int) ([]moderation.ModerationCase, []moderation.QueueCursor, error) {
	q := `select r.id, r.status, r.category, r.target_user_id, r.created_at, r.priority,
		  (select count(*) from moderation.evidence e where e.report_id = r.id)::int
		from safety.reports r where r.status in ('open','in_review')`
	args := []any{limit}
	if after != nil {
		q += ` and (r.priority, r.created_at, r.id) > ($2, $3, $4::uuid)`
		args = append(args, after.Priority, after.CreatedAt, after.ID)
	}
	q += ` order by r.priority, r.created_at, r.id limit $1`
	rows, err := r.Pool.Query(ctx, q, args...)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()
	var items []moderation.ModerationCase
	var keys []moderation.QueueCursor
	for rows.Next() {
		var m moderation.ModerationCase
		var pr int
		if err := rows.Scan(&m.ReportId, &m.Status, &m.Category, &m.TargetUserId, &m.CreatedAt, &pr, &m.EvidenceCount); err != nil {
			return nil, nil, err
		}
		items = append(items, m)
		keys = append(keys, moderation.QueueCursor{Priority: pr, CreatedAt: m.CreatedAt, ID: m.ReportId})
	}
	return items, keys, rows.Err()
}

// statusRank orders account statuses so enforcement never downgrades.
var statusRank = map[string]int{"active": 0, "restricted": 1, "suspended": 2, "banned": 3, "deleted": 4}

var statusForAction = map[string]string{
	"restrict_calls": "restricted", "suspend": "suspended", "ban": "banned", "escalate_legal": "suspended",
}

func (r ModerationRepo) DecideReport(ctx context.Context, d moderation.ReportDecision) (moderation.ModerationDecision, error) {
	var out moderation.ModerationDecision
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		var status, target string
		var reporter *string
		err := tx.QueryRow(ctx, `select status, target_user_id, reporter_id::text from safety.reports where id = $1 for update`, d.ReportID).Scan(&status, &target, &reporter)
		if errors.Is(err, pgx.ErrNoRows) {
			return moderation.ErrNotFound
		}
		if err != nil {
			return err
		}
		if status != "open" && status != "in_review" {
			return moderation.ErrAlreadyDecided
		}
		if target == d.ModeratorID || (reporter != nil && *reporter == d.ModeratorID) {
			return moderation.ErrSelfDecision
		}
		if d.Action != "dismiss" && !d.ModeratorIsAdmin {
			var staff bool
			if err := tx.QueryRow(ctx, `select roles && array['moderator','admin','finance']::text[] from identity.accounts where id = $1`, target).Scan(&staff); err != nil {
				return err
			}
			if staff {
				return moderation.ErrStaffTarget
			}
		}
		out.TargetUserID = target
		var enforcementID *string
		newReport := "decided"
		if d.Action == "dismiss" {
			newReport = "dismissed"
		} else {
			var eid string
			if err := tx.QueryRow(ctx, `insert into safety.enforcement_actions (user_id, action, reason, report_id, decided_by)
				values ($1, $2, $3, $4, $5) returning id`, target, d.Action, d.Reason, d.ReportID, d.ModeratorID).Scan(&eid); err != nil {
				return err
			}
			enforcementID = &eid
			if next, ok := statusForAction[d.Action]; ok {
				out.Enforced = true
				var cur string
				if err := tx.QueryRow(ctx, `select status from identity.accounts where id = $1 for update`, target).Scan(&cur); err != nil {
					return err
				}
				if statusRank[next] > statusRank[cur] {
					if _, err := tx.Exec(ctx, `update identity.accounts set status = $2 where id = $1`, target, next); err != nil {
						return err
					}
				}
				if _, err := tx.Exec(ctx, `update hosting.hosts set is_available = false where user_id = $1`, target); err != nil {
					return err
				}
			}
		}
		if _, err := tx.Exec(ctx, `update safety.reports set status = $2 where id = $1`, d.ReportID, newReport); err != nil {
			return err
		}
		if err := tx.QueryRow(ctx, `insert into moderation.decisions (report_id, action, reason, enforcement_id, decided_by, created_at)
			values ($1, $2, $3, $4, $5, $6) returning id`, d.ReportID, d.Action, d.Reason, enforcementID, d.ModeratorID, d.At).Scan(&out.DecisionId); err != nil {
			return err
		}
		out.Action, out.Status = d.Action, newReport
		return callsAudit(ctx, tx, d.ModeratorID, "moderation.report_decided", d.ReportID,
			map[string]any{"action": d.Action, "target_user_id": target, "decision_id": out.DecisionId})
	})
	return out, err
}

func (r ModerationRepo) DecideAppeal(ctx context.Context, d moderation.AppealDecision) (moderation.ModerationDecision, error) {
	var out moderation.ModerationDecision
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		var status, userID, enforcementID, action string
		var originalReviewer *string
		err := tx.QueryRow(ctx, `select a.status, a.user_id, a.enforcement_id, e.action, e.decided_by
			from safety.appeals a join safety.enforcement_actions e on e.id = a.enforcement_id
			where a.id = $1 for update of a`, d.AppealID).Scan(&status, &userID, &enforcementID, &action, &originalReviewer)
		if errors.Is(err, pgx.ErrNoRows) {
			return moderation.ErrNotFound
		}
		if err != nil {
			return err
		}
		if status != "open" {
			return moderation.ErrAlreadyDecided
		}
		if userID == d.ModeratorID {
			return moderation.ErrSelfDecision
		}
		if originalReviewer != nil && *originalReviewer == d.ModeratorID {
			return moderation.ErrSameReviewer
		}
		if _, err := tx.Exec(ctx, `update safety.appeals set status = $2, decided_by = $3, decided_at = $4 where id = $1`,
			d.AppealID, d.Outcome, d.ModeratorID, d.At); err != nil {
			return err
		}
		if d.Outcome == "overturned" {
			if _, err := tx.Exec(ctx, `update safety.enforcement_actions set expires_at = $2 where id = $1`, enforcementID, d.At); err != nil {
				return err
			}
			if _, ok := statusForAction[action]; ok {
				// Restore the account unless another unexpired enforcement still applies.
				if _, err := tx.Exec(ctx, `update identity.accounts set status = 'active'
					where id = $1 and status in ('restricted','suspended','banned')
					  and not exists (select 1 from safety.enforcement_actions x
					                   where x.user_id = $1 and x.id <> $2
					                     and x.action in ('restrict_calls','suspend','ban','escalate_legal')
					                     and (x.expires_at is null or x.expires_at > $3))`, userID, enforcementID, d.At); err != nil {
					return err
				}
			}
		}
		if err := tx.QueryRow(ctx, `insert into moderation.decisions (appeal_id, action, reason, enforcement_id, decided_by, created_at)
			values ($1, $2, $3, $4, $5, $6) returning id`, d.AppealID, d.Outcome, d.Reason, enforcementID, d.ModeratorID, d.At).Scan(&out.DecisionId); err != nil {
			return err
		}
		out.Action, out.Status = d.Outcome, d.Outcome
		return callsAudit(ctx, tx, d.ModeratorID, "moderation.appeal_decided", d.AppealID,
			map[string]any{"outcome": d.Outcome, "user_id": userID, "decision_id": out.DecisionId})
	})
	return out, err
}

func (r ModerationRepo) FrameWindowCalls(ctx context.Context, now time.Time) ([]moderation.CallFrames, error) {
	rows, err := r.Pool.Query(ctx, `
		select c.id, c.caller_id, c.receiver_id, c.connected_at, c.moderation_window_ends_at, c.ended_at,
		       coalesce(array_agg(f.user_id::text order by f.checked_at) filter (where f.id is not null), '{}'),
		       coalesce(array_agg(f.checked_at order by f.checked_at) filter (where f.id is not null), '{}')
		  from calls.calls c
		  left join moderation.frame_checks f on f.call_id = c.id
		 where c.moderation_window_ends_at is not null and c.connected_at is not null
		   and c.moderation_window_ends_at > $1::timestamptz - interval '15 minutes'
		   and c.connected_at <= $1::timestamptz - interval '60 seconds'
		 group by c.id
		 limit 1000`, now)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []moderation.CallFrames
	for rows.Next() {
		var c moderation.CallFrames
		var users []string
		var times []time.Time
		if err := rows.Scan(&c.CallID, &c.CallerID, &c.ReceiverID, &c.ConnectedAt, &c.WindowEndsAt, &c.EndedAt, &users, &times); err != nil {
			return nil, err
		}
		c.Frames = map[string][]time.Time{}
		for i, u := range users {
			c.Frames[u] = append(c.Frames[u], times[i])
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// LiveCallIDs lists the user's live calls (any non-terminal phase).
func (r ModerationRepo) LiveCallIDs(ctx context.Context, userID string) ([]string, error) {
	rows, err := r.Pool.Query(ctx, `select id::text from calls.calls
		where (caller_id = $1 or receiver_id = $1)
		  and phase in ('requested','ringing','accepted','connecting','active','paused')`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// LastFrameAt returns the latest frame check time for (call, user).
func (r ModerationRepo) LastFrameAt(ctx context.Context, callID, userID string) (*time.Time, error) {
	var t *time.Time
	err := r.Pool.QueryRow(ctx, `select max(checked_at) from moderation.frame_checks where call_id = $1 and user_id = $2`, callID, userID).Scan(&t)
	return t, err
}
