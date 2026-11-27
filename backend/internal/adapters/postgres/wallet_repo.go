package postgres

import (
	"context"
	"fmt"
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

// uuidText guards a text -> uuid cast so a non-uuid reference never errors.
const uuidText = `'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'`

// beanPosted is the host's Bean-affecting journal entries: per entry, the
// signed postings to each Bean account. Everything on the history screen is
// derived from this, so it reconciles to ledger.balances by construction.
const beanPosted = `
	select je.id, je.entry_type, coalesce(je.reference, '') as ref, je.occurred_at,
	       coalesce(sum(p.amount) filter (where a.kind = 'bean_held'), 0)::bigint as held_d,
	       coalesce(sum(p.amount) filter (where a.kind = 'bean_available'), 0)::bigint as avail_d,
	       coalesce(sum(p.amount) filter (where a.kind = 'bean_payout_pending'), 0)::bigint as pend_d
	  from ledger.accounts a
	  join ledger.postings p on p.account_id = a.id
	  join ledger.journal_entries je on je.id = p.entry_id
	 where a.owner_user_id = $1 and p.currency = 'BEAN'
	 group by je.id, je.entry_type, je.reference, je.occurred_at`

// BeanHistory pages the host's Bean entries newest first with a running
// balance (held + available) and the call / gift / release details.
func (r WalletRepo) BeanHistory(ctx context.Context, userID string, types []string, cursor string, limit int) ([]wallet.BeanRow, string, error) {
	cur, err := DecodeCursor(cursor)
	if err != nil {
		return nil, "", wallet.ErrBadCursor
	}
	args := []any{userID, limit + 1}
	where := "true"
	if types != nil {
		args = append(args, types)
		where += fmt.Sprintf(" and entry_type = any($%d)", len(args))
	}
	if cur != nil {
		if !isUUIDString(cur.ID) {
			return nil, "", wallet.ErrBadCursor
		}
		args = append(args, cur.At, cur.ID)
		where += fmt.Sprintf(" and (occurred_at, id) < ($%d, $%d::uuid)", len(args)-1, len(args))
	}
	rows, err := r.Pool.Query(ctx, `
		with posted as (`+beanPosted+`),
		run as (
			select *, sum(held_d + avail_d) over (order by occurred_at, id) as balance_after from posted
		),
		pg as (
			select *, case when ref ~ `+uuidText+` then ref::uuid end as ref_uuid
			  from run
			 where `+where+`
			 order by occurred_at desc, id desc
			 limit $2
		)
		select r.id::text, r.entry_type, r.occurred_at, r.held_d, r.avail_d, r.pend_d, r.balance_after::bigint,
		       coalesce(pp.display_name, ''), coalesce(c.id::text, t.call_id::text, c2.id::text, t2.call_id::text, ''),
		       coalesce(c.billed_seconds, c2.billed_seconds), coalesce(c.rate_per_minute, c2.rate_per_minute),
		       coalesce(t.gift_name, t2.gift_name, ''), coalesce(t.emoji, t2.emoji, ''),
		       coalesce(src.entry_type, ''), rl.occurred_at
		  from pg r
		  left join calls.calls c on r.entry_type = 'call_settlement' and c.id = r.ref_uuid
		  left join gifts.transactions t on r.entry_type = 'gift_send' and t.id = r.ref_uuid
		  left join ledger.journal_entries src on r.entry_type = 'bean_release' and src.id = r.ref_uuid
		  left join calls.calls c2 on src.entry_type = 'call_settlement'
		       and c2.id = case when src.reference ~ `+uuidText+` then src.reference::uuid end
		  left join gifts.transactions t2 on src.entry_type = 'gift_send'
		       and t2.id = case when src.reference ~ `+uuidText+` then src.reference::uuid end
		  left join identity.profiles pp on pp.user_id = coalesce(c.caller_id, t.sender_id, c2.caller_id, t2.sender_id)
		  left join lateral (
		        select rel.occurred_at from ledger.journal_entries rel
		         where rel.entry_type = 'bean_release' and rel.reference = r.id::text
		         order by rel.occurred_at limit 1) rl
		       on r.entry_type in ('call_settlement', 'gift_send', 'free_call_compensation')
		 order by r.occurred_at desc, r.id desc`, args...)
	if err != nil {
		return nil, "", err
	}
	defer rows.Close()
	var out []wallet.BeanRow
	for rows.Next() {
		var b wallet.BeanRow
		if err := rows.Scan(&b.EntryID, &b.EntryType, &b.OccurredAt, &b.HeldDelta, &b.AvailableDelta, &b.PendingDelta,
			&b.BalanceAfter, &b.PeerName, &b.CallID, &b.CallSeconds, &b.CallRate, &b.GiftName, &b.GiftEmoji,
			&b.SourceType, &b.ReleasedAt); err != nil {
			return nil, "", err
		}
		out = append(out, b)
	}
	if err := rows.Err(); err != nil {
		return nil, "", err
	}
	next := ""
	if len(out) > limit {
		out = out[:limit]
		last := out[len(out)-1]
		next = EncodeCursor(last.OccurredAt, last.EntryID)
	}
	return out, next, nil
}

// BeanTotals sums the host's Bean earnings by source and by recent window.
func (r WalletRepo) BeanTotals(ctx context.Context, userID string, todayStart, since7, since30 time.Time) (wallet.BeanTotals, error) {
	var t wallet.BeanTotals
	err := r.Pool.QueryRow(ctx, `
		with posted as (`+beanPosted+`)
		select
		  coalesce(sum(held_d) filter (where entry_type = 'call_settlement'), 0)::bigint,
		  coalesce(sum(held_d) filter (where entry_type = 'gift_send'), 0)::bigint,
		  coalesce(sum(held_d) filter (where entry_type = 'free_call_compensation'), 0)::bigint,
		  count(*) filter (where entry_type = 'call_settlement'),
		  count(*) filter (where entry_type = 'gift_send'),
		  coalesce(-sum(held_d + avail_d) filter (where entry_type = 'bean_clawback'), 0)::bigint,
		  coalesce(sum(held_d + avail_d) filter (where entry_type = 'adjustment'), 0)::bigint,
		  coalesce(-sum(pend_d) filter (where entry_type = 'payout_paid'), 0)::bigint,
		  coalesce(sum(held_d) filter (where entry_type in ('call_settlement','gift_send','free_call_compensation') and occurred_at >= $2), 0)::bigint,
		  coalesce(sum(held_d) filter (where entry_type in ('call_settlement','gift_send','free_call_compensation') and occurred_at >= $3), 0)::bigint,
		  coalesce(sum(held_d) filter (where entry_type in ('call_settlement','gift_send','free_call_compensation') and occurred_at >= $4), 0)::bigint
		from posted`, userID, todayStart, since7, since30).
		Scan(&t.FromCalls, &t.FromGifts, &t.FromFreeCalls, &t.CallCount, &t.GiftCount, &t.Reversed, &t.Adjustments,
			&t.PaidOut, &t.Today, &t.Last7Days, &t.Last30Days)
	return t, err
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
