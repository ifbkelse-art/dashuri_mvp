package postgres

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/admin"
)

// AdminConsoleRepo is the read model behind the admin web console views.
// Read-only: every decision goes through the owning module.
type AdminConsoleRepo struct {
	Pool *pgxpool.Pool
}

var _ admin.ConsoleRepository = AdminConsoleRepo{}

func (r AdminConsoleRepo) DisplayNames(ctx context.Context, ids []string) (map[string]string, error) {
	out := map[string]string{}
	if len(ids) == 0 {
		return out, nil
	}
	rows, err := r.Pool.Query(ctx,
		`select user_id::text, display_name from identity.profiles where user_id = any($1::uuid[])`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var id, name string
		if err := rows.Scan(&id, &name); err != nil {
			return nil, err
		}
		out[id] = name
	}
	return out, rows.Err()
}

// HostApplications: hosts waiting for basic activation, oldest first.
func (r AdminConsoleRepo) HostApplications(ctx context.Context, limit int) ([]admin.HostApplication, error) {
	rows, err := r.Pool.Query(ctx, `
		select h.user_id::text, p.display_name, c.name, h.state, h.kyc_state,
		       a.date_of_birth::text, h.created_at
		  from hosting.hosts h
		  join identity.accounts a on a.id = h.user_id
		  left join identity.profiles p on p.user_id = h.user_id
		  left join identity.cities c on c.id = p.city_id
		 where h.state in ('applied', 'kyc_pending')
		 order by h.created_at, h.user_id
		 limit $1`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []admin.HostApplication
	for rows.Next() {
		var a admin.HostApplication
		if err := rows.Scan(&a.UserId, &a.DisplayName, &a.City, &a.State, &a.KycState, &a.DeclaredDateOfBirth, &a.AppliedAt); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// Appeals: newest open first (or every status with "all").
func (r AdminConsoleRepo) Appeals(ctx context.Context, status string, limit int) ([]admin.AppealItem, error) {
	rows, err := r.Pool.Query(ctx, `
		select ap.id::text, ap.user_id::text, p.display_name, ap.statement, ap.status, ap.created_at,
		       e.action, e.reason, e.created_at
		  from safety.appeals ap
		  join safety.enforcement_actions e on e.id = ap.enforcement_id
		  left join identity.profiles p on p.user_id = ap.user_id
		 where ($1 = 'all' or ap.status = $1)
		 order by ap.created_at, ap.id
		 limit $2`, status, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []admin.AppealItem
	for rows.Next() {
		var a admin.AppealItem
		if err := rows.Scan(&a.AppealId, &a.UserId, &a.DisplayName, &a.Statement, &a.Status, &a.CreatedAt,
			&a.Enforcement.Action, &a.Enforcement.Reason, &a.Enforcement.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// Adjustments: ledger adjustment proposals, oldest first.
func (r AdminConsoleRepo) Adjustments(ctx context.Context, status string, limit int) ([]admin.AdjustmentItem, error) {
	rows, err := r.Pool.Query(ctx, `
		select ap.id::text, a.owner_user_id::text, op.display_name, a.kind, a.currency, ap.amount, ap.reason,
		       ap.proposed_by::text, pp.display_name, ap.status, ap.created_at
		  from ledger.adjustment_proposals ap
		  join ledger.accounts a on a.id = ap.account_id
		  left join identity.profiles op on op.user_id = a.owner_user_id
		  left join identity.profiles pp on pp.user_id = ap.proposed_by
		 where ($1 = 'all' or ap.status = $1)
		 order by ap.created_at, ap.id
		 limit $2`, status, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []admin.AdjustmentItem
	for rows.Next() {
		var a admin.AdjustmentItem
		if err := rows.Scan(&a.ProposalId, &a.OwnerUserId, &a.OwnerDisplayName, &a.AccountKind, &a.Currency, &a.Amount,
			&a.Reason, &a.ProposedBy, &a.ProposedByName, &a.Status, &a.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// AuditEvents: newest first. Only the reason is exposed from the details,
// so ids, amounts or other fields stored there do not leak into the list.
func (r AdminConsoleRepo) AuditEvents(ctx context.Context, limit int) ([]admin.AuditItem, error) {
	rows, err := r.Pool.Query(ctx, `
		select e.at, e.actor, ap.display_name, e.action, e.target, tp.display_name,
		       nullif(coalesce(e.details->>'reason', e.details->>'decision_reason'), '')
		  from audit.events e
		  left join identity.profiles ap on ap.user_id::text = e.actor
		  left join identity.profiles tp on tp.user_id::text = e.target
		 order by e.id desc
		 limit $1`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []admin.AuditItem
	for rows.Next() {
		var a admin.AuditItem
		if err := rows.Scan(&a.At, &a.Actor, &a.ActorName, &a.Action, &a.Target, &a.TargetName, &a.Reason); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}
