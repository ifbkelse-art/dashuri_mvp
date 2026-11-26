//go:build integration

package admin_test

import (
	"context"
	"testing"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/admin"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

// The console read model runs as api_service, exactly as in production, so a
// missing grant on any table it reads fails here.
func TestConsoleViewsOnPostgres(t *testing.T) {
	api, adm := pgtest.Pools(t)
	ctx := context.Background()
	svc := admin.NewService(admin.Deps{Console: postgres.AdminConsoleRepo{Pool: api}})
	exec := func(sql string, args ...any) {
		t.Helper()
		if _, err := adm.Exec(ctx, sql, args...); err != nil {
			t.Fatal(err)
		}
	}

	staff := pgtest.NewUser(t, adm, true, "customer", "admin")
	identitytest.Profile(t, adm, staff, "Founder", nil, nil)
	applicant := pgtest.NewUser(t, adm, true)
	identitytest.Profile(t, adm, applicant, "Divya", nil, nil)
	exec(`insert into hosting.hosts (user_id, state) values ($1, 'kyc_pending')`, applicant)
	approved := pgtest.NewUser(t, adm, true, "customer", "host")
	identitytest.Host(t, adm, approved, 500, false)

	// Staff identity.
	me, err := svc.StaffMe(ctx, auth.Principal{UserID: staff, Roles: []auth.Role{auth.RoleCustomer, auth.RoleAdmin}})
	if err != nil || me.DisplayName == nil || *me.DisplayName != "Founder" {
		t.Fatalf("me %+v %v", me, err)
	}

	// Host applications: only hosts still waiting for activation.
	apps, err := svc.HostApplications(ctx, 50)
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, a := range apps.Items {
		if a.UserId == approved {
			t.Fatal("approved hosts must not be listed")
		}
		if a.UserId == applicant {
			found = true
			if a.DisplayName == nil || *a.DisplayName != "Divya" || a.State != "kyc_pending" || a.DeclaredDateOfBirth == nil {
				t.Fatalf("%+v", a)
			}
		}
	}
	if !found {
		t.Fatal("pending applicant missing")
	}

	// Appeals: an open appeal against a suspension, with its enforcement.
	var enf string
	if err := adm.QueryRow(ctx, `insert into safety.enforcement_actions (user_id, action, reason, decided_by)
		values ($1, 'suspend', 'rude in chat', $2) returning id`, applicant, staff).Scan(&enf); err != nil {
		t.Fatal(err)
	}
	exec(`insert into safety.appeals (enforcement_id, user_id, statement) values ($1, $2, 'please reconsider')`, enf, applicant)
	open, err := svc.Appeals(ctx, "", 50)
	if err != nil {
		t.Fatal(err)
	}
	gotAppeal := false
	for _, a := range open.Items {
		if a.UserId == applicant {
			gotAppeal = a.Statement == "please reconsider" && a.Enforcement.Action == "suspend" && a.Status == "open"
		}
	}
	if !gotAppeal {
		t.Fatalf("appeal missing or wrong: %+v", open.Items)
	}
	if up, _ := svc.Appeals(ctx, "upheld", 50); len(up.Items) != 0 {
		for _, a := range up.Items {
			if a.UserId == applicant {
				t.Fatal("status filter ignored")
			}
		}
	}

	// Ledger adjustments: a proposal by the staff member is marked as theirs.
	var acct int64
	if err := adm.QueryRow(ctx, `insert into ledger.accounts (owner_user_id, kind, currency, non_negative)
		values ($1, 'diamond_promotional', 'DIAMOND', true)
		on conflict (owner_user_id, kind) do update set kind = excluded.kind returning id`, applicant).Scan(&acct); err != nil {
		t.Fatal(err)
	}
	exec(`insert into ledger.adjustment_proposals (account_id, amount, reason, proposed_by) values ($1, 500, 'test grant', $2)`, acct, staff)
	adj, err := svc.Adjustments(ctx, auth.Principal{UserID: staff}, "", 50)
	if err != nil {
		t.Fatal(err)
	}
	gotAdj := false
	for _, a := range adj.Items {
		if a.OwnerUserId != nil && *a.OwnerUserId == applicant {
			gotAdj = a.ProposedByMe && a.Amount == 500 && a.OwnerDisplayName != nil && *a.OwnerDisplayName == "Divya"
		}
	}
	if !gotAdj {
		t.Fatalf("adjustment missing or wrong: %+v", adj.Items)
	}

	// Audit: newest first, names resolved, only the reason exposed.
	if err := postgres.InsertAudit(ctx, api, staff, "host.kyc_rejected", applicant, map[string]any{"reason": "blurry ID", "secret": "x"}); err != nil {
		t.Fatal(err)
	}
	audit, err := svc.AuditEvents(ctx, 5)
	if err != nil || len(audit.Items) == 0 {
		t.Fatalf("audit %+v %v", audit, err)
	}
	top := audit.Items[0]
	if top.Action != "host.kyc_rejected" || top.ActorName == nil || *top.ActorName != "Founder" ||
		top.TargetName == nil || *top.TargetName != "Divya" || top.Reason == nil || *top.Reason != "blurry ID" {
		t.Fatalf("%+v", top)
	}

	// Names.
	names, err := svc.UserNames(ctx, applicant+","+staff)
	if err != nil || len(names.Items) != 2 {
		t.Fatalf("names %+v %v", names, err)
	}
}
