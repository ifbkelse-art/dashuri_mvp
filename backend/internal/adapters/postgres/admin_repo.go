package postgres

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/admin"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/platform/httpx"
)

// InsertAudit appends one audit.events row (actor = user id, system:<job>
// or provider:<name>). The request id is taken from the context.
func InsertAudit(ctx context.Context, q Querier, actor, action, target string, details map[string]any) error {
	if details == nil {
		details = map[string]any{}
	}
	b, err := json.Marshal(details)
	if err != nil {
		return err
	}
	_, err = q.Exec(ctx, `insert into audit.events (actor, action, target, request_id, details) values ($1, $2, $3, $4, $5)`,
		actor, action, nullIfEmpty(target), nullIfEmpty(httpx.RequestID(ctx)), b)
	return err
}

func jsonValid(b []byte) bool { return json.Valid(b) }

// AdminRepo implements admin.Repository.
type AdminRepo struct {
	Pool *pgxpool.Pool
	Tx   db.TxManager
}

var _ admin.Repository = AdminRepo{}

// Reconcile recomputes every account from postings and compares it with the
// projection, finds entries that do not balance per currency (or have fewer
// than two postings), and totals user liabilities. One repeatable-read
// snapshot so the numbers are mutually consistent.
func (r AdminRepo) Reconcile(ctx context.Context) (admin.Reconciliation, error) {
	var rc admin.Reconciliation
	err := r.Tx.WithTx(ctx, pgx.RepeatableRead, func(tx pgx.Tx) error {
		rc = admin.Reconciliation{}
		if err := tx.QueryRow(ctx, `select now()`).Scan(&rc.AsOf); err != nil {
			return err
		}
		rows, err := tx.Query(ctx, `
			select a.id, coalesce(a.owner_user_id::text, ''), a.kind, coalesce(b.balance, 0), coalesce(p.total, 0)
			  from ledger.accounts a
			  left join ledger.balances b on b.account_id = a.id
			  left join (select account_id, sum(amount)::bigint as total from ledger.postings group by account_id) p
			         on p.account_id = a.id
			 where coalesce(b.balance, 0) <> coalesce(p.total, 0)
			 order by a.id`)
		if err != nil {
			return err
		}
		for rows.Next() {
			var d admin.AccountDrift
			if err := rows.Scan(&d.AccountID, &d.Owner, &d.Kind, &d.ProjectedValue, &d.PostedValue); err != nil {
				rows.Close()
				return err
			}
			rc.Drifts = append(rc.Drifts, d)
		}
		rows.Close()
		if err := rows.Err(); err != nil {
			return err
		}
		if err := tx.QueryRow(ctx, `
			select count(*) from (
			  select entry_id from ledger.postings group by entry_id, currency having sum(amount) <> 0
			  union
			  select je.id from ledger.journal_entries je
			   where (select count(*) from ledger.postings p where p.entry_id = je.id) < 2
			) x`).Scan(&rc.UnbalancedEntries); err != nil {
			return err
		}
		return tx.QueryRow(ctx, `
			select coalesce(sum(b.balance) filter (where a.kind = 'diamond_purchased'), 0)::bigint,
			       coalesce(sum(b.balance) filter (where a.kind = 'diamond_promotional'), 0)::bigint,
			       coalesce(sum(b.balance) filter (where a.kind in ('bean_held','bean_available','bean_payout_pending')), 0)::bigint
			  from ledger.accounts a join ledger.balances b on b.account_id = a.id
			 where a.owner_user_id is not null`).Scan(&rc.PurchasedDiamonds, &rc.PromotionalDiamonds, &rc.HostBeans)
	})
	return rc, err
}

func (r AdminRepo) ProposeAdjustment(ctx context.Context, acct ledger.AccountRef, amount int64, reason, by string) (string, error) {
	var id string
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		accountID, err := AccountID(ctx, tx, acct, ledger.CurrencyOf(acct.Kind))
		if IsForeignKeyViolation(err) {
			return admin.ErrUnknownAccount
		}
		if err != nil {
			return err
		}
		if err := tx.QueryRow(ctx, `
			insert into ledger.adjustment_proposals (account_id, amount, reason, proposed_by)
			values ($1, $2, $3, $4) returning id::text`, accountID, amount, reason, by).Scan(&id); err != nil {
			return err
		}
		return InsertAudit(ctx, tx, by, "ledger.adjustment_proposed", id, map[string]any{
			"account": acct.String(), "amount": amount, "reason": reason})
	})
	return id, err
}

func (r AdminRepo) DecideAdjustment(ctx context.Context, proposalID, by string, approve bool, build func(admin.Proposal) (ledger.Entry, error)) (admin.Proposal, error) {
	var p admin.Proposal
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		var owner, kind, entryID string
		err := tx.QueryRow(ctx, `
			select ap.id::text, ap.amount, ap.reason, ap.proposed_by::text, ap.status, coalesce(ap.entry_id::text, ''),
			       a.owner_user_id::text, a.kind
			  from ledger.adjustment_proposals ap join ledger.accounts a on a.id = ap.account_id
			 where ap.id = $1 for update of ap`, proposalID).
			Scan(&p.ID, &p.Amount, &p.Reason, &p.ProposedBy, &p.Status, &entryID, &owner, &kind)
		if errors.Is(err, pgx.ErrNoRows) {
			return admin.ErrProposalNotFound
		}
		if err != nil {
			return err
		}
		p.Account, p.EntryID = ledger.User(owner, ledger.AccountKind(kind)), entryID
		if p.Status != "awaiting_second_approval" {
			return admin.ErrProposalNotPending
		}
		if p.ProposedBy == by {
			return admin.ErrSameApprover
		}
		if !approve {
			if _, err := tx.Exec(ctx, `update ledger.adjustment_proposals set status = 'rejected', approved_by = $2 where id = $1`, p.ID, by); err != nil {
				return err
			}
			p.Status = "rejected"
			return InsertAudit(ctx, tx, by, "ledger.adjustment_rejected", p.ID, map[string]any{"account": p.Account.String(), "amount": p.Amount})
		}
		e, err := build(p)
		if err != nil {
			return err
		}
		id, _, err := PostEntry(ctx, tx, e)
		if errors.Is(err, ErrInsufficientBalance) {
			return admin.ErrOverdraw
		}
		if err != nil {
			return err
		}
		if _, err := tx.Exec(ctx, `update ledger.adjustment_proposals set status = 'posted', approved_by = $2, entry_id = $3 where id = $1`,
			p.ID, by, id); err != nil {
			return err
		}
		p.Status, p.EntryID = "posted", id
		return InsertAudit(ctx, tx, by, "ledger.adjustment_posted", p.ID, map[string]any{
			"account": p.Account.String(), "amount": p.Amount, "entry_id": id, "proposed_by": p.ProposedBy})
	})
	return p, err
}

func (r AdminRepo) ApprovePayoutCycle(ctx context.Context, cycleID, by string) (string, error) {
	status := ""
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		err := tx.QueryRow(ctx, `select status from payouts.cycles where id = $1 for update`, cycleID).Scan(&status)
		if errors.Is(err, pgx.ErrNoRows) {
			return admin.ErrCycleNotFound
		}
		if err != nil {
			return err
		}
		if status != "ready" {
			return admin.ErrCycleNotReady
		}
		if _, err := tx.Exec(ctx, `update payouts.cycles set status = 'approved', approved_by = $2, approved_at = now() where id = $1`, cycleID, by); err != nil {
			return err
		}
		status = "approved"
		return InsertAudit(ctx, tx, by, "payouts.cycle_approved", cycleID, nil)
	})
	return status, err
}

func (r AdminRepo) Audit(ctx context.Context, actor, action, target string, details map[string]any) error {
	return InsertAudit(ctx, r.Pool, actor, action, target, details)
}
