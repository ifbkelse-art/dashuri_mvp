package postgres

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sort"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/modules/ledger"
)

// PostEntry posts one journal entry inside the caller's transaction. It is
// the only function in the code base that writes ledger postings.
//
//  1. Validates the entry (balanced per currency, keyed, currencies match).
//  2. Inserts the entry; a duplicate idempotency key returns the first entry
//     with replayed=true and posts nothing.
//  3. Resolves (and provisions) accounts, then locks their balance rows in
//     ascending account id order to avoid deadlocks.
//  4. Inserts postings; the trigger updates the projection and the
//     non-negative CHECK aborts the transaction on overspend.
func PostEntry(ctx context.Context, tx pgx.Tx, e ledger.Entry) (entryID string, replayed bool, err error) {
	if err := e.Validate(); err != nil {
		return "", false, err
	}
	meta, err := json.Marshal(e.Metadata)
	if err != nil {
		return "", false, err
	}
	if e.Metadata == nil {
		meta = []byte("{}")
	}
	var rule *string
	if e.RuleSetVersion != "" {
		rule = &e.RuleSetVersion
	}
	err = tx.QueryRow(ctx, `
		insert into ledger.journal_entries (entry_type, idempotency_key, rule_set_version, reference, occurred_at, metadata)
		values ($1, $2, $3, $4, $5, $6)
		on conflict (idempotency_key) do nothing
		returning id`, string(e.Type), e.IdempotencyKey, rule, e.Reference, e.OccurredAt, meta).Scan(&entryID)
	if errors.Is(err, pgx.ErrNoRows) {
		err = tx.QueryRow(ctx, `select id from ledger.journal_entries where idempotency_key = $1`, e.IdempotencyKey).Scan(&entryID)
		return entryID, true, err
	}
	if err != nil {
		return "", false, err
	}

	ids := make([]int64, len(e.Postings))
	for i, p := range e.Postings {
		id, err := AccountID(ctx, tx, p.Account, p.Currency)
		if err != nil {
			return "", false, err
		}
		ids[i] = id
	}
	if err := lockAccounts(ctx, tx, ids); err != nil {
		return "", false, err
	}
	for i, p := range e.Postings {
		if _, err := tx.Exec(ctx, `insert into ledger.postings (entry_id, account_id, currency, amount) values ($1, $2, $3, $4)`,
			entryID, ids[i], string(p.Currency), p.Amount); err != nil {
			if IsCheckViolation(err) {
				return "", false, ErrInsufficientBalance
			}
			return "", false, err
		}
	}
	return entryID, false, nil
}

// ErrInsufficientBalance means a user bucket would have gone negative.
var ErrInsufficientBalance = errors.New("ledger: insufficient balance")

// AccountID returns the ledger account id, creating user accounts on demand.
func AccountID(ctx context.Context, q Querier, a ledger.AccountRef, c ledger.Currency) (int64, error) {
	var id int64
	if a.UserID == "" {
		err := q.QueryRow(ctx, `select id from ledger.accounts where owner_user_id is null and kind = $1`, string(a.Kind)).Scan(&id)
		if err != nil {
			return 0, fmt.Errorf("ledger: system account %s: %w", a.Kind, err)
		}
		return id, nil
	}
	err := q.QueryRow(ctx, `
		with ins as (
		  insert into ledger.accounts (owner_user_id, kind, currency, non_negative)
		  values ($1, $2, $3, true)
		  on conflict (owner_user_id, kind) do nothing
		  returning id
		)
		select id from ins
		union all
		select id from ledger.accounts where owner_user_id = $1 and kind = $2
		limit 1`, a.UserID, string(a.Kind), string(c)).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		// A concurrent transaction created the account after this
		// statement's snapshot (ON CONFLICT waited for it); a new statement
		// sees the committed row.
		err = q.QueryRow(ctx, `select id from ledger.accounts where owner_user_id = $1 and kind = $2`, a.UserID, string(a.Kind)).Scan(&id)
	}
	return id, err
}

// lockAccounts ensures projection rows exist and locks them in ascending order.
func lockAccounts(ctx context.Context, tx pgx.Tx, ids []int64) error {
	uniq := map[int64]struct{}{}
	for _, id := range ids {
		uniq[id] = struct{}{}
	}
	sorted := make([]int64, 0, len(uniq))
	for id := range uniq {
		sorted = append(sorted, id)
	}
	sort.Slice(sorted, func(i, j int) bool { return sorted[i] < sorted[j] })
	if _, err := tx.Exec(ctx, `
		insert into ledger.balances (account_id, balance, non_negative)
		select a.id, 0, a.non_negative from ledger.accounts a where a.id = any($1)
		on conflict (account_id) do nothing`, sorted); err != nil {
		return err
	}
	_, err := tx.Exec(ctx, `select 1 from ledger.balances where account_id = any($1) order by account_id for update`, sorted)
	return err
}

// LockUserBalances locks the given user's buckets (ascending id) and returns
// their balances by kind. Use before reading a balance you will spend from.
func LockUserBalances(ctx context.Context, tx pgx.Tx, userID string, kinds ...ledger.AccountKind) (map[ledger.AccountKind]int64, error) {
	ids := make([]int64, 0, len(kinds))
	byID := map[int64]ledger.AccountKind{}
	for _, k := range kinds {
		cur := ledger.Diamond
		if k == ledger.UserBeanHeld || k == ledger.UserBeanAvailable || k == ledger.UserBeanPayoutPending {
			cur = ledger.Bean
		}
		id, err := AccountID(ctx, tx, ledger.User(userID, k), cur)
		if err != nil {
			return nil, err
		}
		ids = append(ids, id)
		byID[id] = k
	}
	if err := lockAccounts(ctx, tx, ids); err != nil {
		return nil, err
	}
	rows, err := tx.Query(ctx, `select account_id, balance from ledger.balances where account_id = any($1)`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[ledger.AccountKind]int64{}
	for rows.Next() {
		var id, bal int64
		if err := rows.Scan(&id, &bal); err != nil {
			return nil, err
		}
		out[byID[id]] = bal
	}
	return out, rows.Err()
}

// ActiveReservations returns the Diamonds reserved for the user's live call.
func ActiveReservations(ctx context.Context, q Querier, userID string) (int64, error) {
	var n int64
	err := q.QueryRow(ctx, `select coalesce(sum(amount), 0) from ledger.diamond_reservations where user_id = $1 and status = 'active'`, userID).Scan(&n)
	return n, err
}

// LedgerStore adapts PostEntry to ledger.Store for callers that do not need
// to share a transaction.
type LedgerStore struct{ Pool *pgxpool.Pool }

var _ ledger.Store = LedgerStore{}

func (s LedgerStore) Post(ctx context.Context, e ledger.Entry) (id string, replayed bool, err error) {
	err = pgx.BeginTxFunc(ctx, s.Pool, pgx.TxOptions{}, func(tx pgx.Tx) error {
		id, replayed, err = PostEntry(ctx, tx, e)
		return err
	})
	return id, replayed, err
}

func (s LedgerStore) Balance(ctx context.Context, a ledger.AccountRef, c ledger.Currency) (int64, error) {
	var bal int64
	err := s.Pool.QueryRow(ctx, `
		select coalesce(b.balance, 0)
		  from ledger.accounts a left join ledger.balances b on b.account_id = a.id
		 where a.owner_user_id is not distinct from nullif($1, '')::uuid and a.kind = $2`, a.UserID, string(a.Kind)).Scan(&bal)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, nil
	}
	return bal, err
}
