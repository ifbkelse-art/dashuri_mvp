//go:build integration

package jobs_test

import (
	"context"
	"sync"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/jobs"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/clock"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/testsupport/pgtest"
	"dashuri/backend/internal/wiring"
)

// hints records realtime publishes.
type hints struct {
	mu  sync.Mutex
	evs []string
}

func (h *hints) Publish(_ context.Context, ch, ev string, _ any) error {
	h.mu.Lock()
	h.evs = append(h.evs, ch+" "+ev)
	h.mu.Unlock()
	return nil
}

func (h *hints) walletHints(user string) int {
	h.mu.Lock()
	defer h.mu.Unlock()
	n := 0
	for _, e := range h.evs {
		if e == "user:"+user+" wallet.updated" {
			n++
		}
	}
	return n
}

func jobEnv(api *hints, pool wiring.Env) wiring.Env {
	pool.Realtime = api
	pool.Rules = economy.Founder()
	pool.Clock = clock.System{}
	return pool
}

// Regression (2026-11-27): the release-bean-holds job moved Beans from
// "on hold" to "available" without a wallet.updated hint, so an open host
// wallet kept showing them as held.
func TestReleaseBeanHoldsSendsWalletHints(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	rec := &hints{}
	env := jobEnv(rec, wiring.Env{Pool: api, Tx: db.TxManager{Pool: api}})
	store := postgres.LedgerStore{Pool: api}

	due := pgtest.NewUser(t, admin, true, "customer", "host")
	notYet := pgtest.NewUser(t, admin, true, "customer", "host")
	old := time.Now().Add(-env.Rules.BeanHoldPeriod - time.Hour)
	for _, e := range []ledger.Entry{
		ledger.FreeCallCompensation(pgtest.UUID(), due, 2000, "2026-11-17-founder", old),
		ledger.FreeCallCompensation(pgtest.UUID(), due, 1000, "2026-11-17-founder", old),
		ledger.FreeCallCompensation(pgtest.UUID(), notYet, 2000, "2026-11-17-founder", time.Now()),
	} {
		if _, _, err := store.Post(ctx, e); err != nil {
			t.Fatal(err)
		}
	}

	if err := jobs.ReleaseBeanHolds(ctx, env); err != nil {
		t.Fatal(err)
	}
	if b, _ := store.Balance(ctx, ledger.User(due, ledger.UserBeanAvailable), ledger.Bean); b != 3000 {
		t.Fatalf("released %d, want 3000", b)
	}
	// Two releases for one host → one hint.
	if n := rec.walletHints(due); n != 1 {
		t.Fatalf("due host got %d wallet hints, want 1: %v", n, rec.evs)
	}
	if n := rec.walletHints(notYet); n != 0 {
		t.Fatalf("host still on hold got %d hints", n)
	}
	// A rerun releases nothing for this host and sends nothing more.
	if err := jobs.ReleaseBeanHolds(ctx, env); err != nil {
		t.Fatal(err)
	}
	if n := rec.walletHints(due); n != 1 {
		t.Fatalf("rerun re-announced: %d", n)
	}
}

// Regression (2026-11-27): expire-promo-diamonds removed bonus Diamonds
// without a wallet.updated hint.
func TestExpirePromoDiamondsSendsWalletHints(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	rec := &hints{}
	env := jobEnv(rec, wiring.Env{Pool: api, Tx: db.TxManager{Pool: api}})
	store := postgres.LedgerStore{Pool: api}

	expiring := pgtest.NewUser(t, admin, true)
	fresh := pgtest.NewUser(t, admin, true)
	grant := func(user string, at time.Time) ledger.Entry {
		return ledger.Entry{Type: ledger.EntryPromoGrant, IdempotencyKey: "promo_grant:test:" + pgtest.UUID(),
			RuleSetVersion: "2026-11-17-founder", Reference: user, OccurredAt: at,
			Postings: []ledger.Posting{
				{Account: ledger.System(ledger.SystemDiamondIssuedPromo), Currency: ledger.Diamond, Amount: -500},
				{Account: ledger.User(user, ledger.UserDiamondPromotional), Currency: ledger.Diamond, Amount: 500},
			}}
	}
	for _, e := range []ledger.Entry{
		grant(expiring, time.Now().Add(-env.Rules.PromoDiamondTTL-time.Hour)),
		grant(fresh, time.Now()),
	} {
		if _, _, err := store.Post(ctx, e); err != nil {
			t.Fatal(err)
		}
	}

	if err := jobs.ExpirePromoDiamonds(ctx, env); err != nil {
		t.Fatal(err)
	}
	if b, _ := store.Balance(ctx, ledger.User(expiring, ledger.UserDiamondPromotional), ledger.Diamond); b != 0 {
		t.Fatalf("promo balance %d after expiry, want 0", b)
	}
	if n := rec.walletHints(expiring); n != 1 {
		t.Fatalf("expired user got %d hints, want 1: %v", n, rec.evs)
	}
	if n := rec.walletHints(fresh); n != 0 {
		t.Fatalf("unexpired user got %d hints", n)
	}
	if err := jobs.ExpirePromoDiamonds(ctx, env); err != nil {
		t.Fatal(err)
	}
	if n := rec.walletHints(expiring); n != 1 {
		t.Fatalf("rerun re-announced: %d", n)
	}
}
