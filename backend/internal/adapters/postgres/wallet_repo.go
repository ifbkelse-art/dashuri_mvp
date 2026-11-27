package postgres

import (
	"context"
	"slices"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/modules/wallet"
	"dashuri/backend/internal/platform/db"
)

// WalletRepo implements wallet.Repository (read model over the ledger).
type WalletRepo struct{ Pool *pgxpool.Pool }

var _ wallet.Repository = WalletRepo{}

func (r WalletRepo) Balances(ctx context.Context, userID string) (wallet.Balances, error) {
	out := wallet.Balances{ByKind: map[string]int64{}}
	rows, err := r.Pool.Query(ctx, `
		select a.kind, coalesce(b.balance, 0)
		  from ledger.accounts a left join ledger.balances b on b.account_id = a.id
		 where a.owner_user_id = $1`, userID)
	if err != nil {
		return out, err
	}
	defer rows.Close()
	for rows.Next() {
		var k string
		var v int64
		if err := rows.Scan(&k, &v); err != nil {
			return out, err
		}
		out.ByKind[k] = v
	}
	if err := rows.Err(); err != nil {
		return out, err
	}
	out.Reserved, err = ActiveReservations(ctx, r.Pool, userID)
	return out, err
}

func (r WalletRepo) Entries(ctx context.Context, userID, cursor string, limit int) ([]wallet.EntryRow, string, error) {
	cur, err := DecodeCursor(cursor)
	if err != nil {
		return nil, "", wallet.ErrBadCursor
	}
	args := []any{userID, limit + 1}
	cond := ""
	if cur != nil {
		if !isUUIDString(cur.ID) {
			return nil, "", wallet.ErrBadCursor
		}
		cond = `and (je.occurred_at, je.id) < ($3, $4::uuid)`
		args = append(args, cur.At, cur.ID)
	}
	rows, err := r.Pool.Query(ctx, `
		select je.id::text, je.entry_type, coalesce(je.reference, ''), je.occurred_at, p.currency,
		       sum(p.amount)::bigint,
		       coalesce(sum(p.amount) filter (where a.kind = 'bean_available'), 0)::bigint
		  from ledger.accounts a
		  join ledger.postings p on p.account_id = a.id
		  join ledger.journal_entries je on je.id = p.entry_id
		 where a.owner_user_id = $1 `+cond+`
		 group by je.id, je.entry_type, je.reference, je.occurred_at, p.currency
		 order by je.occurred_at desc, je.id desc, p.currency
		 limit $2`, args...)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()
	var out []wallet.EntryRow
	for rows.Next() {
		var e wallet.EntryRow
		if err := rows.Scan(&e.EntryID, &e.EntryType, &e.Reference, &e.OccurredAt, &e.Currency, &e.Net, &e.Available); err != nil {
			return nil, "", err
		}
		out = append(out, e)
	}
	if err := rows.Err(); err != nil {
		return nil, "", err
	}
	next := ""
	if len(out) > limit {
		extra := out[limit]
		out = out[:limit]
		// Keep an entry with postings in two currencies on one page.
		for len(out) > 1 && out[len(out)-1].EntryID == extra.EntryID {
			out = out[:len(out)-1]
		}
		last := out[len(out)-1]
		next = EncodeCursor(last.OccurredAt, last.EntryID)
	}
	return out, next, nil
}

func isUUIDString(s string) bool {
	if len(s) != 36 {
		return false
	}
	for i, c := range s {
		switch i {
		case 8, 13, 18, 23:
			if c != '-' {
				return false
			}
		default:
			if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f' || c >= 'A' && c <= 'F') {
				return false
			}
		}
	}
	return true
}

// ExpirePromoGrants posts ledger.PromoExpiry for promotional grants older
// than cutoff (promo_diamond_ttl_days). Spend order is promotional-first and
// oldest-first, so what is left of an old grant is the promotional balance
// minus the younger, unexpired grants, capped at the grant. A user with a
// live call (active reservation) is skipped and retried on the next run.
// Each grant is processed once (ledger.promo_grant_expiries + entry key).
func ExpirePromoGrants(ctx context.Context, pool *pgxpool.Pool, tm db.TxManager, cutoff, at time.Time, limit int) (grants int, expired int64, err error) {
	grants, expired, _, err = ExpirePromoGrantsFor(ctx, pool, tm, cutoff, at, limit)
	return grants, expired, err
}

// ExpirePromoGrantsFor is ExpirePromoGrants that also returns the users whose
// promotional balance actually dropped (deduplicated), for wallet hints.
func ExpirePromoGrantsFor(ctx context.Context, pool *pgxpool.Pool, tm db.TxManager, cutoff, at time.Time, limit int) (grants int, expired int64, users []string, err error) {
	rows, err := pool.Query(ctx, `
		select je.id::text, a.owner_user_id::text, p.amount, je.occurred_at
		  from ledger.journal_entries je
		  join ledger.postings p on p.entry_id = je.id
		  join ledger.accounts a on a.id = p.account_id and a.kind = 'diamond_promotional'
		 where je.entry_type = 'promo_grant' and p.amount > 0 and je.occurred_at < $1
		   and not exists (select 1 from ledger.promo_grant_expiries x where x.grant_entry_id = je.id)
		 order by je.occurred_at limit $2`, cutoff, limit)
	if err != nil {
		return 0, 0, nil, err
	}
	type grant struct {
		id, user string
		amount   int64
		at       time.Time
	}
	var gs []grant
	for rows.Next() {
		var g grant
		if err := rows.Scan(&g.id, &g.user, &g.amount, &g.at); err != nil {
			rows.Close()
			return 0, 0, nil, err
		}
		gs = append(gs, g)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return 0, 0, nil, err
	}
	for _, g := range gs {
		var removed int64
		err := tm.WithTx(ctx, pgx.ReadCommitted, func(tx pgx.Tx) error {
			removed = 0
			bal, err := LockUserBalances(ctx, tx, g.user, ledger.UserDiamondPromotional)
			if err != nil {
				return err
			}
			reserved, err := ActiveReservations(ctx, tx, g.user)
			if err != nil || reserved > 0 {
				return err
			}
			var younger int64
			if err := tx.QueryRow(ctx, `
				select coalesce(sum(p.amount), 0)::bigint
				  from ledger.journal_entries je
				  join ledger.postings p on p.entry_id = je.id
				  join ledger.accounts a on a.id = p.account_id and a.kind = 'diamond_promotional' and a.owner_user_id = $1
				 where je.entry_type = 'promo_grant' and p.amount > 0 and je.id <> $2::uuid
				   and (je.occurred_at, je.id) > ($3, $2::uuid)
				   and not exists (select 1 from ledger.promo_grant_expiries x where x.grant_entry_id = je.id)`,
				g.user, g.id, g.at).Scan(&younger); err != nil {
				return err
			}
			removed = max(min(g.amount, bal[ledger.UserDiamondPromotional]-younger), 0)
			var entryID *string
			if removed > 0 {
				id, _, err := PostEntry(ctx, tx, ledger.PromoExpiry(g.user, g.id, removed, at))
				if err != nil {
					return err
				}
				entryID = &id
			}
			_, err = tx.Exec(ctx, `insert into ledger.promo_grant_expiries (grant_entry_id, user_id, expired, entry_id)
				values ($1, $2, $3, $4) on conflict do nothing`, g.id, g.user, removed, entryID)
			return err
		})
		if err != nil {
			return grants, expired, users, err
		}
		grants++
		expired += removed
		if removed > 0 && !slices.Contains(users, g.user) {
			users = append(users, g.user)
		}
	}
	return grants, expired, users, nil
}
