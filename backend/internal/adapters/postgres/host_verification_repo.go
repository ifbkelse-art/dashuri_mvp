package postgres

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"

	"dashuri/backend/internal/modules/hosts"
)

// Verified Host persistence (hosting.verification_applications,
// hosting.verification_evidence, hosting.hosts.verification_status).

const evidenceColumns = `id, host_id, application_id, kind, content_type, storage_path, created_at, purged_at`

func scanEvidence(row pgx.Row) (hosts.Evidence, error) {
	var e hosts.Evidence
	err := row.Scan(&e.ID, &e.HostID, &e.ApplicationID, &e.Kind, &e.ContentType, &e.StoragePath, &e.CreatedAt, &e.PurgedAt)
	return e, err
}

func queryEvidence(ctx context.Context, q Querier, sql string, args ...any) ([]hosts.Evidence, error) {
	rows, err := q.Query(ctx, sql, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []hosts.Evidence
	for rows.Next() {
		e, err := scanEvidence(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// loadVerification reads the state; lock=true locks the host row and the
// latest application (serialising with rate changes and call creation).
func loadVerification(ctx context.Context, q Querier, hostID string, lock bool) (hosts.VerificationState, error) {
	var st hosts.VerificationState
	forUpdate := ""
	if lock {
		forUpdate = " for update of h"
	}
	err := q.QueryRow(ctx, `select h.state, h.rate_per_minute, h.verification_status, h.verified_at, `+idLifetimeXP("h.user_id")+`
		from hosting.hosts h where h.user_id = $1`+forUpdate, hostID).
		Scan(&st.HostState, &st.Pricing.RatePerMinute, &st.Status, &st.VerifiedAt, &st.Pricing.LifetimeXP)
	if errors.Is(err, pgx.ErrNoRows) {
		return st, nil
	}
	if err != nil {
		return st, err
	}
	st.HostExists, st.Pricing.Exists = true, true
	st.Pricing.State, st.Pricing.VerificationStatus = st.HostState, st.Status
	var a hosts.Application
	appLock := ""
	if lock {
		appLock = " for update"
	}
	err = q.QueryRow(ctx, `select id, status, submitted_at, resubmitted_at, reviewer_id, review_started_at, info_request,
		       decided_by, decided_at, decision_reason
		  from hosting.verification_applications where host_id = $1
		 order by submitted_at desc, created_at desc limit 1`+appLock, hostID).
		Scan(&a.ID, &a.Status, &a.SubmittedAt, &a.ResubmittedAt, &a.ReviewerID, &a.ReviewStartedAt, &a.InfoRequest,
			&a.DecidedBy, &a.DecidedAt, &a.DecisionReason)
	switch {
	case errors.Is(err, pgx.ErrNoRows):
	case err != nil:
		return st, err
	default:
		st.Current = &a
		if st.Attached, err = queryEvidence(ctx, q, `select `+evidenceColumns+` from hosting.verification_evidence
			where application_id = $1 and purged_at is null order by created_at`, a.ID); err != nil {
			return st, err
		}
	}
	st.Pending, err = queryEvidence(ctx, q, `select `+evidenceColumns+` from hosting.verification_evidence
		where host_id = $1 and application_id is null and purged_at is null order by created_at`, hostID)
	return st, err
}

func (r HostsRepo) Verification(ctx context.Context, hostID string) (hosts.VerificationState, error) {
	return loadVerification(ctx, r.Pool, hostID, false)
}

func (r HostsRepo) ChangeVerification(ctx context.Context, hostID string, decide func(hosts.VerificationState) (hosts.VerificationChange, error)) (hosts.VerificationState, error) {
	var out hosts.VerificationState
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		st, err := loadVerification(ctx, tx, hostID, true)
		if err != nil {
			return err
		}
		ch, err := decide(st)
		if err != nil {
			return err
		}
		from := st.Status
		var appID string
		if ch.CreateApplication {
			if err := tx.QueryRow(ctx, `insert into hosting.verification_applications (host_id, status, submitted_at)
				values ($1, $2, $3) returning id`, hostID, ch.ApplicationStatus, ch.At).Scan(&appID); err != nil {
				return err
			}
		} else {
			if st.Current == nil {
				return hosts.ErrNoApplication
			}
			appID = st.Current.ID
			if _, err := tx.Exec(ctx, `update hosting.verification_applications set status = $2,
				resubmitted_at    = case when $3 = 'resubmitted' then $4 else resubmitted_at end,
				reviewer_id       = case when $3 = 'review_started' then $5::uuid else reviewer_id end,
				review_started_at = case when $3 = 'review_started' then $4 else review_started_at end,
				info_request      = case when $3 = 'info_requested' then nullif($6, '') else info_request end,
				decided_by        = case when $3 in ('approved','rejected','suspended','reinstated','revoked') then $5::uuid else decided_by end,
				decided_at        = case when $3 in ('approved','rejected','suspended','reinstated','revoked') then $4 else decided_at end,
				decision_reason   = case when $3 in ('approved','rejected','suspended','reinstated','revoked') then nullif($7, '') else decision_reason end
				where id = $1`, appID, ch.ApplicationStatus, ch.Action, ch.At, ch.ActorID, ch.InfoRequest, ch.Reason); err != nil {
				return err
			}
		}
		if len(ch.AttachEvidence) > 0 {
			tag, err := tx.Exec(ctx, `update hosting.verification_evidence set application_id = $2
				where host_id = $1 and application_id is null and purged_at is null and id = any($3::uuid[])`,
				hostID, appID, ch.AttachEvidence)
			if err != nil {
				return err
			}
			if int(tag.RowsAffected()) != len(ch.AttachEvidence) {
				return errors.New("hosts: evidence changed during submission")
			}
		}
		// Price cap first: the CHECK constraint refuses a non-verified status
		// while the stored rate is above 3,000.
		details := map[string]any{"application_id": appID, "from": from, "to": ch.HostStatus}
		if ch.CapRateTo != nil && *ch.CapRateTo < st.Pricing.RatePerMinute {
			if err := capHostRate(ctx, tx, hostID, st.Pricing.RatePerMinute, *ch.CapRateTo, ch.ActorID, "verification_"+ch.Action); err != nil {
				return err
			}
			details["rate_capped_from"], details["rate_capped_to"] = st.Pricing.RatePerMinute, *ch.CapRateTo
		}
		if _, err := tx.Exec(ctx, `update hosting.hosts set verification_status = $2, verification_changed_at = $3,
			verified_at = case when $2 = 'verified' then coalesce(case when verification_status = 'verified' then verified_at end, $3)
			                   else null end
			where user_id = $1`, hostID, ch.HostStatus, ch.At); err != nil {
			return err
		}
		if ch.Reason != "" {
			details["reason"] = ch.Reason
		}
		if ch.InfoRequest != "" {
			details["info_request"] = ch.InfoRequest
		}
		if len(ch.AttachEvidence) > 0 {
			details["evidence_ids"] = ch.AttachEvidence
		}
		if err := callsAudit(ctx, tx, ch.ActorID, "host.verification."+ch.Action, hostID, details); err != nil {
			return err
		}
		out, err = loadVerification(ctx, tx, hostID, false)
		return err
	})
	if IsUniqueViolation(err, "one_open_verification_application") {
		return out, hosts.ErrAlreadyApplied
	}
	return out, err
}

func (r HostsRepo) CreateEvidence(ctx context.Context, e hosts.Evidence) error {
	_, err := r.Pool.Exec(ctx, `insert into hosting.verification_evidence (id, host_id, kind, content_type, storage_path, created_at)
		values ($1, $2, $3, $4, $5, $6)`, e.ID, e.HostID, e.Kind, e.ContentType, e.StoragePath, e.CreatedAt)
	return err
}

func (r HostsRepo) Evidence(ctx context.Context, hostID, evidenceID string) (hosts.Evidence, error) {
	e, err := scanEvidence(r.Pool.QueryRow(ctx, `select `+evidenceColumns+` from hosting.verification_evidence
		where id = $1 and host_id = $2`, evidenceID, hostID))
	if errors.Is(err, pgx.ErrNoRows) {
		return e, hosts.ErrNotFound
	}
	return e, err
}

func (r HostsRepo) VerificationQueue(ctx context.Context, statuses []string, limit int) ([]hosts.QueueItem, error) {
	rows, err := r.Pool.Query(ctx, `
		select va.id, va.host_id, coalesce(p.display_name, ''), va.status, coalesce(va.resubmitted_at, va.submitted_at),
		       `+idLifetimeXP("va.host_id")+`
		  from hosting.verification_applications va
		  left join identity.profiles p on p.user_id = va.host_id
		 where va.status = any($1::text[])
		 order by coalesce(va.resubmitted_at, va.submitted_at), va.id
		 limit $2`, statuses, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []hosts.QueueItem
	for rows.Next() {
		var q hosts.QueueItem
		if err := rows.Scan(&q.ApplicationID, &q.HostID, &q.DisplayName, &q.Status, &q.SubmittedAt, &q.LifetimeXP); err != nil {
			return nil, err
		}
		out = append(out, q)
	}
	return out, rows.Err()
}

func (r HostsRepo) VerificationHistory(ctx context.Context, hostID string, limit int) ([]hosts.HistoryEvent, error) {
	rows, err := r.Pool.Query(ctx, `select at, actor, action, details from audit.events
		where target = $1 and (action like 'host.verification.%' or action in ('host.rate_capped','host.rate_changed'))
		  and action <> 'host.verification.viewed'
		order by at desc, id desc limit $2`, hostID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []hosts.HistoryEvent
	for rows.Next() {
		var h hosts.HistoryEvent
		var raw []byte
		if err := rows.Scan(&h.At, &h.Actor, &h.Action, &raw); err != nil {
			return nil, err
		}
		_ = json.Unmarshal(raw, &h.Details)
		out = append(out, h)
	}
	return out, rows.Err()
}

func (r HostsRepo) Audit(ctx context.Context, actor, action, target string, details map[string]any) error {
	return callsAudit(ctx, r.Pool, actor, action, target, details)
}

func (r HostsRepo) EvidenceDueForPurge(ctx context.Context, decidedBefore, orphanBefore time.Time, limit int) ([]hosts.Evidence, error) {
	return queryEvidence(ctx, r.Pool, `select `+evidenceColumns+` from hosting.verification_evidence e
		where e.purged_at is null and (
		  (e.application_id is null and e.created_at < $2)
		  or exists (select 1 from hosting.verification_applications va where va.id = e.application_id
		              and va.status in ('approved','rejected','revoked') and va.decided_at < $1)
		  or exists (select 1 from identity.accounts a where a.id = e.host_id and a.status = 'deleted'))
		order by e.created_at limit $3`, decidedBefore, orphanBefore, limit)
}

func (r HostsRepo) MarkEvidencePurged(ctx context.Context, evidenceID string, at time.Time) error {
	if _, err := r.Pool.Exec(ctx, `update hosting.verification_evidence set purged_at = $2 where id = $1 and purged_at is null`,
		evidenceID, at); err != nil {
		return err
	}
	return callsAudit(ctx, r.Pool, "system:purge-verification-evidence", "host.verification.evidence_purged", "",
		map[string]any{"evidence_id": evidenceID})
}
