//go:build integration

package postgres_test

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/testsupport/pgtest"
)

func TestPostEntryExactlyOnceUnderConcurrency(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	user := pgtest.NewUser(t, admin, true)
	store := postgres.LedgerStore{Pool: api}
	e := ledger.PurchaseCredit(user, pgtest.UUID(), "tok-"+user, 4000, "2026-11-17-founder", time.Now())

	var wg sync.WaitGroup
	var mu sync.Mutex
	fresh := 0
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, replayed, err := store.Post(ctx, e)
			if err != nil && !postgres.IsUniqueViolation(err) {
				t.Errorf("post: %v", err)
				return
			}
			if err == nil && !replayed {
				mu.Lock()
				fresh++
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	if fresh != 1 {
		t.Fatalf("want exactly one fresh posting, got %d", fresh)
	}
	bal, err := store.Balance(ctx, ledger.User(user, ledger.UserDiamondPurchased), ledger.Diamond)
	if err != nil || bal != 4000 {
		t.Fatalf("balance = %d, %v; want 4000", bal, err)
	}
}

func TestOverspendRejectedAndRolledBack(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	customer := pgtest.NewUser(t, admin, true)
	host := pgtest.NewUser(t, admin, true, "customer", "host")
	store := postgres.LedgerStore{Pool: api}
	if _, _, err := store.Post(ctx, ledger.PurchaseCredit(customer, pgtest.UUID(), "t-"+customer, 1000, "2026-11-17-founder", time.Now())); err != nil {
		t.Fatal(err)
	}
	entry, err := ledger.CallSettlement(ledger.CallCharge{CallID: pgtest.UUID(), CustomerID: customer, HostID: host,
		FromPurchased: 5000, HostBeans: 2999, RuleSetVersion: "2026-11-17-founder", At: time.Now()})
	if err != nil {
		t.Fatal(err)
	}
	err = pgx.BeginTxFunc(ctx, api, pgx.TxOptions{}, func(tx pgx.Tx) error {
		_, _, err := postgres.PostEntry(ctx, tx, entry)
		return err
	})
	if !errors.Is(err, postgres.ErrInsufficientBalance) {
		t.Fatalf("want ErrInsufficientBalance, got %v", err)
	}
	bal, _ := store.Balance(ctx, ledger.User(customer, ledger.UserDiamondPurchased), ledger.Diamond)
	beans, _ := store.Balance(ctx, ledger.User(host, ledger.UserBeanHeld), ledger.Bean)
	if bal != 1000 || beans != 0 {
		t.Fatalf("state changed after failed settlement: diamonds=%d beans=%d", bal, beans)
	}
}

func TestRoleSourceProvisionsAndRefusesSuspended(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	id := pgtest.UUID()
	if _, err := admin.Exec(ctx, `insert into auth.users (id) values ($1)`, id); err != nil {
		t.Fatal(err)
	}
	rs := postgres.RoleSource{Pool: api}
	a, err := rs.Account(ctx, id)
	if err != nil || len(a.Roles) != 1 || a.Roles[0] != "customer" || a.Status != "active" {
		t.Fatalf("provision: %+v %v", a, err)
	}
	if _, err := admin.Exec(ctx, `update identity.accounts set status = 'suspended' where id = $1`, id); err != nil {
		t.Fatal(err)
	}
	// The loader reports the status; auth.Middleware refuses it except on
	// the appeal routes (security review finding 7).
	if a, err := rs.Account(ctx, id); err != nil || a.Status != "suspended" {
		t.Fatalf("suspended account: %+v %v", a, err)
	}
}

func TestIdempotencyStoreClaimsOnce(t *testing.T) {
	api, _ := pgtest.Pools(t)
	ctx := context.Background()
	s := postgres.IdempotencyStore{Pool: api}
	scope, key := "u:"+pgtest.UUID(), pgtest.UUID()
	if _, claimed, err := s.Begin(ctx, scope, key, "h1", time.Hour); err != nil || !claimed {
		t.Fatalf("first claim: %v %v", claimed, err)
	}
	rec, claimed, err := s.Begin(ctx, scope, key, "h1", time.Hour)
	if err != nil || claimed || rec.Completed {
		t.Fatalf("second claim should see in-progress: %+v %v %v", rec, claimed, err)
	}
	if err := s.Complete(ctx, scope, key, 201, []byte(`{"ok":true}`)); err != nil {
		t.Fatal(err)
	}
	rec, _, _ = s.Begin(ctx, scope, key, "h1", time.Hour)
	if !rec.Completed || rec.Status != 201 || string(rec.Body) != `{"ok":true}` {
		t.Fatalf("replay record wrong: %+v", rec)
	}
}

// Regression: a debit from a user bucket with sufficient balance must post
// (the first apply_posting trigger rejected every user debit).
func TestValidDebitSettlesCall(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	customer := pgtest.NewUser(t, admin, true)
	host := pgtest.NewUser(t, admin, true, "customer", "host")
	store := postgres.LedgerStore{Pool: api}
	if _, _, err := store.Post(ctx, ledger.PurchaseCredit(customer, pgtest.UUID(), "t-"+customer, 10000, "2026-11-17-founder", time.Now())); err != nil {
		t.Fatal(err)
	}
	entry, err := ledger.CallSettlement(ledger.CallCharge{CallID: pgtest.UUID(), CustomerID: customer, HostID: host,
		FromPurchased: 4333, HostBeans: 2599, RuleSetVersion: "2026-11-17-founder", At: time.Now()})
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := store.Post(ctx, entry); err != nil {
		t.Fatalf("valid settlement rejected: %v", err)
	}
	d, _ := store.Balance(ctx, ledger.User(customer, ledger.UserDiamondPurchased), ledger.Diamond)
	b, _ := store.Balance(ctx, ledger.User(host, ledger.UserBeanHeld), ledger.Bean)
	if d != 10000-4333 || b != 2599 {
		t.Fatalf("balances after settlement: diamonds=%d beans=%d", d, b)
	}
}
