//go:build integration

package jobs_test

import (
	"context"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/jobs"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/testsupport/pgtest"
	"dashuri/backend/internal/wiring"
)

func TestExecuteAccountDeletions(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	env := wiring.Env{Pool: api, Tx: db.TxManager{Pool: api}}

	clean := pgtest.NewUser(t, admin, true)
	withBeans := pgtest.NewUser(t, admin, true, "customer", "host")
	for _, u := range []string{clean, withBeans} {
		if _, err := admin.Exec(ctx, `insert into identity.profiles (user_id, display_name, bio) values ($1, 'Asha', 'hello')`, u); err != nil {
			t.Fatal(err)
		}
		if _, err := admin.Exec(ctx, `insert into identity.data_requests (user_id, kind, status, scheduled_for) values ($1, 'deletion', 'received', now() - interval '1 minute')`, u); err != nil {
			t.Fatal(err)
		}
	}
	// Give the host Beans through a real, balanced entry.
	if _, _, err := (postgres.LedgerStore{Pool: api}).Post(ctx, ledger.FreeCallCompensation(pgtest.UUID(), withBeans, 2000, "2026-11-17-founder", time.Now())); err != nil {
		t.Fatal(err)
	}

	if err := jobs.ExecuteAccountDeletions(ctx, env); err != nil {
		t.Fatal(err)
	}
	var status, name string
	_ = admin.QueryRow(ctx, `select a.status, p.display_name from identity.accounts a join identity.profiles p on p.user_id = a.id where a.id = $1`, clean).Scan(&status, &name)
	if status != "deleted" || name != "Deleted user" {
		t.Fatalf("clean account: status=%s name=%s", status, name)
	}
	var reqStatus string
	_ = admin.QueryRow(ctx, `select a.status, r.status from identity.accounts a join identity.data_requests r on r.user_id = a.id where a.id = $1`, withBeans).Scan(&status, &reqStatus)
	if status != "active" || reqStatus != "rejected" {
		t.Fatalf("account with Beans: status=%s request=%s", status, reqStatus)
	}
	// Re-running is a no-op.
	if err := jobs.ExecuteAccountDeletions(ctx, env); err != nil {
		t.Fatal(err)
	}
}
