//go:build integration

package postgres_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/jobs"
	"dashuri/backend/internal/modules/admin"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/modules/payouts"
	"dashuri/backend/internal/modules/wallet"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/clock"
	"dashuri/backend/internal/platform/config"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/testsupport/pgtest"
	"dashuri/backend/internal/wiring"
)

func TestWithdrawalRefusedWhileDisabledAndNoBeansMove(t *testing.T) {
	api, adm := pgtest.Pools(t)
	ctx := context.Background()
	host := pgtest.NewUser(t, adm, true, "customer", "host")
	store := postgres.LedgerStore{Pool: api}
	comp := ledger.FreeCallCompensation(pgtest.UUID(), host, 250000, "2026-11-17-founder", time.Now())
	compID, _, err := store.Post(ctx, comp)
	if err != nil {
		t.Fatal(err)
	}
	if _, _, err := store.Post(ctx, ledger.BeanRelease(host, compID, 250000, time.Now())); err != nil {
		t.Fatal(err)
	}
	repo := postgres.PayoutsRepo{Pool: api, Tx: db.TxManager{Pool: api}}
	p := auth.Principal{UserID: host, Roles: []auth.Role{auth.RoleCustomer, auth.RoleHost}, Status: "active"}

	disabled := payouts.NewService(payouts.Deps{Rules: economy.Founder(), Repo: repo, Enabled: false})
	if _, err := disabled.RequestWithdrawal(ctx, p, payouts.WithdrawalRequest{Beans: 100000}); ruleCode(err) != "payouts_not_enabled" {
		t.Fatalf("want payouts_not_enabled, got %v", err)
	}
	if b := balance(t, api, host, ledger.UserBeanAvailable); b != 250000 {
		t.Fatalf("beans moved while disabled: %d", b)
	}
	if b := balance(t, api, host, ledger.UserBeanPayoutPending); b != 0 {
		t.Fatalf("pending %d", b)
	}

	// Enabled path (future): eligibility, then exactly the available amount moves.
	enabled := payouts.NewService(payouts.Deps{Rules: economy.Founder(), Repo: repo, Enabled: true})
	if _, err := enabled.RequestWithdrawal(ctx, p, payouts.WithdrawalRequest{Beans: 100000}); ruleCode(err) != "kyc_required" {
		t.Fatalf("want kyc_required, got %v", err)
	}
	if _, err := adm.Exec(ctx, `insert into hosting.hosts (user_id, state, kyc_state) values ($1, 'approved', 'approved')`, host); err != nil {
		t.Fatal(err)
	}
	if _, err := enabled.RequestWithdrawal(ctx, p, payouts.WithdrawalRequest{Beans: 100000}); ruleCode(err) != "payout_method_missing" {
		t.Fatalf("want payout_method_missing, got %v", err)
	}
	if _, err := adm.Exec(ctx, `insert into payouts.beneficiaries (host_id, provider, beneficiary_ref, name_verified) values ($1, 'test', 'ref', true)`, host); err != nil {
		t.Fatal(err)
	}
	if _, err := enabled.RequestWithdrawal(ctx, p, payouts.WithdrawalRequest{Beans: 99999}); ruleCode(err) != "below_minimum_withdrawal" {
		t.Fatalf("want below_minimum_withdrawal, got %v", err)
	}
	w, err := enabled.RequestWithdrawal(ctx, p, payouts.WithdrawalRequest{Beans: 200000})
	if err != nil || w.Status != "requested" || w.AmountPaise != 100000 {
		t.Fatalf("%+v %v", w, err)
	}
	if _, err := enabled.RequestWithdrawal(ctx, p, payouts.WithdrawalRequest{Beans: 100000}); ruleCode(err) != "insufficient_available_beans" {
		t.Fatalf("want insufficient_available_beans, got %v", err)
	}
	if a, pp := balance(t, api, host, ledger.UserBeanAvailable), balance(t, api, host, ledger.UserBeanPayoutPending); a != 50000 || pp != 200000 {
		t.Fatalf("available=%d pending=%d", a, pp)
	}
	list, err := disabled.ListWithdrawals(ctx, p, payouts.PageRequest{Limit: 10})
	if err != nil || len(list.Items) != 1 || list.Items[0].Id != w.Id {
		t.Fatalf("%+v %v", list, err)
	}
}

func TestWalletSummaryEqualsLedger(t *testing.T) {
	api, adm := pgtest.Pools(t)
	ctx := context.Background()
	user := pgtest.NewUser(t, adm, true, "customer", "host")
	other := pgtest.NewUser(t, adm, true, "customer", "host")
	store := postgres.LedgerStore{Pool: api}
	now := time.Now()
	if _, _, err := store.Post(ctx, ledger.PurchaseCredit(user, pgtest.UUID(), "w-"+user, 54000, "2026-11-17-founder", now)); err != nil {
		t.Fatal(err)
	}
	settle, _ := ledger.CallSettlement(ledger.CallCharge{CallID: pgtest.UUID(), CustomerID: user, HostID: other, FromPurchased: 4333, HostBeans: 2599, RuleSetVersion: "2026-11-17-founder", At: now.Add(time.Second)})
	if _, _, err := store.Post(ctx, settle); err != nil {
		t.Fatal(err)
	}
	if _, _, err := store.Post(ctx, ledger.FreeCallCompensation(pgtest.UUID(), user, 2000, "2026-11-17-founder", now.Add(2*time.Second))); err != nil {
		t.Fatal(err)
	}
	if _, err := adm.Exec(ctx, `insert into ledger.diamond_reservations (user_id, call_id, amount) values ($1, $2, 8000)`, user, pgtest.UUID()); err != nil {
		t.Fatal(err)
	}
	svc := wallet.NewService(wallet.Deps{Repo: postgres.WalletRepo{Pool: api}})
	p := auth.Principal{UserID: user}
	s, err := svc.GetWalletSummary(ctx, p)
	if err != nil {
		t.Fatal(err)
	}
	purchased := balance(t, api, user, ledger.UserDiamondPurchased)
	if s.PurchasedDiamonds != purchased || purchased != 54000-4333 || s.ReservedDiamonds != 8000 ||
		s.AvailableDiamonds != purchased-8000 || s.BeansOnHold != balance(t, api, user, ledger.UserBeanHeld) || s.BeansOnHold != 2000 {
		t.Fatalf("summary %+v", s)
	}
	page1, err := svc.ListWalletEntries(ctx, p, wallet.PageRequest{Limit: 2})
	if err != nil || len(page1.Items) != 2 || page1.NextCursor == nil {
		t.Fatalf("%+v %v", page1, err)
	}
	if page1.Items[0].Kind != "free_call_compensation" || page1.Items[0].Amount != 2000 || page1.Items[1].Amount != -4333 || page1.Items[1].Description != "Video call" {
		t.Fatalf("page1 %+v", page1.Items)
	}
	page2, err := svc.ListWalletEntries(ctx, p, wallet.PageRequest{Limit: 2, Cursor: *page1.NextCursor})
	if err != nil || len(page2.Items) != 1 || page2.Items[0].Amount != 54000 || page2.NextCursor != nil {
		t.Fatalf("page2 %+v %v", page2, err)
	}
	var sum int64
	for _, e := range append(page1.Items, page2.Items...) {
		if e.Currency == "DIAMOND" {
			sum += e.Amount
		}
	}
	if sum != purchased {
		t.Fatalf("entries sum %d != balance %d", sum, purchased)
	}
}

func TestReconciliationDetectsDriftAndAdjustmentsNeedTwoPeople(t *testing.T) {
	api, adm := pgtest.Pools(t)
	ctx := context.Background()
	alice := pgtest.NewUser(t, adm, true, "customer", "finance")
	bob := pgtest.NewUser(t, adm, true, "customer", "finance")
	user := pgtest.NewUser(t, adm, true)
	svc := admin.NewService(admin.Deps{Repo: postgres.AdminRepo{Pool: api, Tx: db.TxManager{Pool: api}}, Rules: economy.Founder()})
	pa, pb := auth.Principal{UserID: alice}, auth.Principal{UserID: bob}

	base, err := svc.GetReconciliation(ctx, pa)
	if err != nil {
		t.Fatal(err)
	}
	if base.Discrepancies != 0 {
		t.Fatalf("baseline discrepancies %+v", base)
	}

	prop, err := svc.ProposeAdjustment(ctx, pa, admin.AdjustmentRequest{Account: "user:" + user + ":diamond_purchased", Currency: "DIAMOND", Amount: 750, Reason: "support credit"})
	if err != nil || prop.Status != "awaiting_second_approval" {
		t.Fatalf("%+v %v", prop, err)
	}
	if _, err := svc.DecideAdjustment(ctx, pa, prop.ProposalId, true); ruleCode(err) != "second_approver_required" {
		t.Fatalf("self-approval: %v", err)
	}
	if b := balance(t, api, user, ledger.UserDiamondPurchased); b != 0 {
		t.Fatal("posted before second approval")
	}
	done, err := svc.DecideAdjustment(ctx, pb, prop.ProposalId, true)
	if err != nil || done.Status != "posted" || done.EntryId == nil {
		t.Fatalf("%+v %v", done, err)
	}
	if _, err := svc.DecideAdjustment(ctx, pb, prop.ProposalId, true); ruleCode(err) != "adjustment_not_pending" {
		t.Fatalf("double approve: %v", err)
	}
	if b := balance(t, api, user, ledger.UserDiamondPurchased); b != 750 {
		t.Fatalf("balance %d", b)
	}
	over, _ := svc.ProposeAdjustment(ctx, pa, admin.AdjustmentRequest{Account: user + ":diamond_purchased", Currency: "DIAMOND", Amount: -5000, Reason: "overdraw"})
	if _, err := svc.DecideAdjustment(ctx, pb, over.ProposalId, true); ruleCode(err) != "adjustment_would_overdraw" {
		t.Fatalf("overdraw: %v", err)
	}
	if rej, err := svc.DecideAdjustment(ctx, pb, over.ProposalId, false); err != nil || rej.Status != "rejected" {
		t.Fatalf("reject: %+v %v", rej, err)
	}
	if _, err := svc.ProposeAdjustment(ctx, pa, admin.AdjustmentRequest{Account: user + ":diamond_purchased", Currency: "BEAN", Amount: 5, Reason: "x"}); ruleCode(err) != "validation_failed" {
		t.Fatalf("currency mismatch: %v", err)
	}
	if n := count(t, adm, `select count(*) from audit.events where target = $1`, prop.ProposalId); n != 2 {
		t.Fatalf("audit events for proposal %d", n)
	}

	after, _ := svc.GetReconciliation(ctx, pa)
	if after.Discrepancies != 0 || after.CustomerDiamondLiability != base.CustomerDiamondLiability+750 {
		t.Fatalf("after adjustment %+v (base %+v)", after, base)
	}

	// Inject projection drift: detected by the endpoint and the job (non-zero exit).
	var acct int64
	if err := adm.QueryRow(ctx, `select id from ledger.accounts where owner_user_id = $1 and kind = 'diamond_purchased'`, user).Scan(&acct); err != nil {
		t.Fatal(err)
	}
	if _, err := adm.Exec(ctx, `update ledger.balances set balance = balance + 7 where account_id = $1`, acct); err != nil {
		t.Fatal(err)
	}
	defer adm.Exec(ctx, `update ledger.balances set balance = balance - 7 where account_id = $1`, acct)
	drift, _ := svc.GetReconciliation(ctx, pa)
	if drift.Discrepancies != 1 || len(drift.DriftedAccounts) != 1 || drift.DriftedAccounts[0].AccountID != acct ||
		drift.DriftedAccounts[0].ProjectedValue-drift.DriftedAccounts[0].PostedValue != 7 {
		t.Fatalf("drift %+v", drift)
	}
	env := wiring.Env{Config: config.Config{Env: "development"}, Pool: api, Tx: db.TxManager{Pool: api}, Rules: economy.Founder(), Clock: clock.System{}}
	if err := jobs.ReconcileLedger(ctx, env); !errors.Is(err, jobs.ErrLedgerDrift) {
		t.Fatalf("job: %v", err)
	}
	if n := count(t, adm, `select count(*) from audit.events where action = 'ledger.drift_detected'`); n < 1 {
		t.Fatal("drift not audited")
	}

	// Payout cycle approval is refused while payouts are disabled.
	if _, err := svc.ApprovePayoutCycle(ctx, pa, pgtest.UUID()); ruleCode(err) != "payouts_not_enabled" {
		t.Fatalf("cycle approve: %v", err)
	}
	// Promo expiry with no promotional grants is a correct no-op.
	if err := jobs.ExpirePromoDiamonds(ctx, env); err != nil {
		t.Fatal(err)
	}
}
