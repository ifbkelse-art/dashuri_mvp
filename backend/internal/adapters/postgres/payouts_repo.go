package postgres

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/modules/payouts"
	"dashuri/backend/internal/platform/db"
)

// PayoutsRepo implements payouts.Repository.
type PayoutsRepo struct {
	Pool *pgxpool.Pool
	Tx   db.TxManager
}

var _ payouts.Repository = PayoutsRepo{}

func (r PayoutsRepo) Eligibility(ctx context.Context, hostID string) (payouts.Eligibility, error) {
	var e payouts.Eligibility
	err := r.Pool.QueryRow(ctx, `
		select coalesce(h.state = 'approved', false), coalesce(h.kyc_state = 'approved', false),
		       exists (select 1 from payouts.beneficiaries b where b.host_id = $1 and b.name_verified)
		  from (select 1) one left join hosting.hosts h on h.user_id = $1`, hostID).
		Scan(&e.HostApproved, &e.KYCApproved, &e.PayoutVerified)
	return e, err
}

func (r PayoutsRepo) RequestWithdrawal(ctx context.Context, hostID string, beans, paise int64, entry func(string) ledger.Entry) (payouts.Withdrawal, error) {
	var w payouts.Withdrawal
	err := r.Tx.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
		bal, err := LockUserBalances(ctx, tx, hostID, ledger.UserBeanAvailable)
		if err != nil {
			return err
		}
		if bal[ledger.UserBeanAvailable] < beans {
			return payouts.ErrInsufficient
		}
		var id string
		if err := tx.QueryRow(ctx, `select gen_random_uuid()::text`).Scan(&id); err != nil {
			return err
		}
		entryID, _, err := PostEntry(ctx, tx, entry(id))
		if errors.Is(err, ErrInsufficientBalance) {
			return payouts.ErrInsufficient
		}
		if err != nil {
			return err
		}
		if err := tx.QueryRow(ctx, `
			insert into payouts.withdrawals (id, host_id, beans, amount_paise, status, request_entry_id)
			values ($1, $2, $3, $4, 'requested', $5)
			returning id::text, beans, amount_paise, status, requested_at, paid_at`, id, hostID, beans, paise, entryID).
			Scan(&w.Id, &w.Beans, &w.AmountPaise, &w.Status, &w.RequestedAt, &w.PaidAt); err != nil {
			return err
		}
		return InsertAudit(ctx, tx, hostID, "payouts.withdrawal_requested", id, map[string]any{"beans": beans, "amount_paise": paise})
	})
	return w, err
}

func (r PayoutsRepo) ListWithdrawals(ctx context.Context, hostID, cursor string, limit int) ([]payouts.Withdrawal, string, error) {
	cur, err := DecodeCursor(cursor)
	if err != nil || (cur != nil && !isUUIDString(cur.ID)) {
		return nil, "", payouts.ErrBadCursor
	}
	args := []any{hostID, limit + 1}
	cond := ""
	if cur != nil {
		cond = `and (requested_at, id) < ($3, $4::uuid)`
		args = append(args, cur.At, cur.ID)
	}
	rows, err := r.Pool.Query(ctx, `
		select id::text, beans, amount_paise, status, requested_at, paid_at from payouts.withdrawals
		 where host_id = $1 `+cond+` order by requested_at desc, id desc limit $2`, args...)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()
	var out []payouts.Withdrawal
	for rows.Next() {
		var w payouts.Withdrawal
		if err := rows.Scan(&w.Id, &w.Beans, &w.AmountPaise, &w.Status, &w.RequestedAt, &w.PaidAt); err != nil {
			return nil, "", err
		}
		out = append(out, w)
	}
	if err := rows.Err(); err != nil {
		return nil, "", err
	}
	next := ""
	if len(out) > limit {
		out = out[:limit]
		last := out[len(out)-1]
		next = EncodeCursor(last.RequestedAt, last.Id)
	}
	return out, next, nil
}
