//go:build integration

package hosts_test

import (
	"context"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/hosts"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/testsupport/callstest"
	"dashuri/backend/internal/testsupport/pgtest"
)

func TestHostLifecycleKycAndEarnings(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	repo := postgres.HostsRepo{Pool: api, Tx: db.TxManager{Pool: api}}
	svc := hosts.NewService(hosts.Deps{Rules: economy.Founder(), Repo: repo})
	u := pgtest.NewUser(t, admin, true)
	p := callstest.Principal(u)
	mod := callstest.Principal(pgtest.NewUser(t, admin, true, "customer", "moderator"), auth.RoleModerator)

	if st, _ := svc.GetHostStatus(ctx, p); st.State != "not_applied" {
		t.Fatalf("%+v", st)
	}
	if _, err := svc.ApplyAsHost(ctx, auth.Principal{UserID: u, Status: "active"}); callstest.Rule(err) != "not_age_eligible" {
		t.Fatalf("age gate: %v", err)
	}
	if st, err := svc.ApplyAsHost(ctx, p); err != nil || st.State != "applied" {
		t.Fatalf("%+v %v", st, err)
	}
	if _, err := svc.ApplyAsHost(ctx, p); callstest.Rule(err) != "already_applied" {
		t.Fatalf("reapply: %v", err)
	}
	if _, err := svc.SetAvailability(ctx, p, hosts.SetAvailabilityRequest{IsAvailable: true}); callstest.Rule(err) != "host_not_approved" {
		t.Fatalf("availability before approval: %v", err)
	}
	k1, err := svc.StartKyc(ctx, p)
	if err != nil {
		t.Fatal(err)
	}
	k2, _ := svc.StartKyc(ctx, p)
	if k1.SessionId != k2.SessionId {
		t.Fatal("a started session must be reused")
	}
	if st, _ := svc.GetHostStatus(ctx, p); st.State != "kyc_pending" || st.KycState != "in_progress" {
		t.Fatalf("%+v", st)
	}
	if _, err := svc.DecideKyc(ctx, mod, u, hosts.KycDecisionRequest{Decision: "approve", DateOfBirth: time.Now().AddDate(-17, 0, 0).Format("2006-01-02")}); callstest.Rule(err) != "not_age_eligible" {
		t.Fatalf("minor approved: %v", err)
	}
	st, err := svc.DecideKyc(ctx, mod, u, hosts.KycDecisionRequest{Decision: "approve", DateOfBirth: "1994-05-06", Reason: "id checked"})
	if err != nil || st.State != "approved" || st.KycState != "approved" {
		t.Fatalf("%+v %v", st, err)
	}
	var roles []string
	var method, dob string
	_ = api.QueryRow(ctx, `select roles, age_method, date_of_birth::text from identity.accounts where id = $1`, u).Scan(&roles, &method, &dob)
	if len(roles) != 2 || roles[1] != "host" || method != "kyc_verified" || dob != "1994-05-06" {
		t.Fatalf("account %v %s %s", roles, method, dob)
	}
	var audits int
	_ = admin.QueryRow(ctx, `select count(*) from audit.events where target = $1 and action = 'host.kyc_approved'`, u).Scan(&audits)
	if audits != 1 {
		t.Fatalf("audit %d", audits)
	}

	if st, err := svc.SetAvailability(ctx, p, hosts.SetAvailabilityRequest{IsAvailable: true}); err != nil || !st.IsAvailable {
		t.Fatalf("%+v %v", st, err)
	}
	if _, err := svc.SetRate(ctx, p, hosts.SetRateRequest{RatePerMinute: 12000}); callstest.Rule(err) != "rate_outside_level_limits" {
		t.Fatalf("rate cap: %v", err)
	}
	if st, err := svc.SetRate(ctx, p, hosts.SetRateRequest{RatePerMinute: 3000}); err != nil || st.RatePerMinute != 3000 {
		t.Fatalf("%+v %v", st, err)
	}
	if st, err := svc.SetFreeCallOptIn(ctx, p, hosts.SetFreeCallOptInRequest{OptIn: true}); err != nil || !st.FreeCallOptIn {
		t.Fatalf("%+v %v", st, err)
	}

	// Mark offline after 90 s without heartbeat.
	if _, err := admin.Exec(ctx, `update hosting.hosts set last_heartbeat_at = now() - interval '5 minutes' where user_id = $1`, u); err != nil {
		t.Fatal(err)
	}
	if _, err := repo.MarkOffline(ctx, time.Now().Add(-90*time.Second)); err != nil {
		t.Fatal(err)
	}
	if st, _ := svc.GetHostStatus(ctx, p); st.IsAvailable {
		t.Fatal("host still online without heartbeat")
	}

	// Beans held 8 days ago are released once; today's earnings count.
	store := postgres.LedgerStore{Pool: api}
	if _, _, err := store.Post(ctx, ledger.FreeCallCompensation(pgtest.UUID(), u, 2000, "2026-11-17-founder", time.Now().Add(-8*24*time.Hour))); err != nil {
		t.Fatal(err)
	}
	if _, _, err := store.Post(ctx, ledger.FreeCallCompensation(pgtest.UUID(), u, 2000, "2026-11-17-founder", time.Now())); err != nil {
		t.Fatal(err)
	}
	cutoff := time.Now().Add(-7 * 24 * time.Hour)
	if n, err := repo.ReleaseDueBeanHolds(ctx, cutoff, time.Now(), 500); err != nil || n < 1 {
		t.Fatalf("released %d %v", n, err)
	}
	if n, _ := repo.ReleaseDueBeanHolds(ctx, cutoff, time.Now(), 500); n != 0 {
		t.Fatalf("second run released %d", n)
	}
	hp := callstest.Principal(u, auth.RoleHost)
	e, err := svc.GetEarnings(ctx, hp)
	if err != nil || e.BeansAvailable != 2000 || e.BeansOnHold != 2000 || e.AvailableInrPaise != 1000 || e.TodayEarnedBeans != 2000 {
		t.Fatalf("%+v %v", e, err)
	}
}
