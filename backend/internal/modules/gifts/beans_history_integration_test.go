//go:build integration

package gifts_test

// Host Beans history against a real ledger: every movement type, then the
// promises the screen makes: the list reconciles to the balances to the
// Bean, pages never skip or repeat a line, filters partition the list, and
// the wording names the customer, the call and the gift.

import (
	"context"
	"strings"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/modules/wallet"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

func TestHostBeansHistoryReconcilesToBalances(t *testing.T) {
	e := setup(t)
	store := postgres.LedgerStore{Pool: e.api}
	svc := wallet.NewService(wallet.Deps{Repo: postgres.WalletRepo{Pool: e.api}})
	now := time.Now()
	post := func(en ledger.Entry) string {
		t.Helper()
		id, _, err := store.Post(e.ctx, en)
		if err != nil {
			t.Fatalf("post %s: %v", en.Type, err)
		}
		return id
	}

	// 1. An ended call, settled 3 hours ago (2 min 05 s at 500/min).
	callID := identitytest.Call(t, e.admin, e.customer, e.host, "ended", 125, 3*time.Hour)
	hostBeans, err := e.rules.BeansForDiamonds(1000)
	if err != nil {
		t.Fatal(err)
	}
	settleEntry := post(mustSettlement(t, ledger.CallCharge{CallID: callID, CustomerID: e.customer, HostID: e.host,
		FromPurchased: 1000, HostBeans: hostBeans, RuleSetVersion: e.rules.Version, At: now.Add(-3 * time.Hour)}))
	// 2. A Free Call Card credit.
	post(ledger.FreeCallCompensation(pgtest.UUID(), e.host, 2000, e.rules.Version, now.Add(-150*time.Minute)))
	// 3. The call's Beans are released from hold.
	post(ledger.BeanRelease(e.host, settleEntry, hostBeans, now.Add(-2*time.Hour)))
	// 4. A withdrawal that is paid, one that fails, one still pending.
	paid, failed, pending := pgtest.UUID(), pgtest.UUID(), pgtest.UUID()
	post(ledger.WithdrawalRequested(e.host, paid, 400, now.Add(-100*time.Minute)))
	post(ledger.PayoutSettled(e.host, paid, 400, true, now.Add(-90*time.Minute)))
	post(ledger.WithdrawalRequested(e.host, failed, 50, now.Add(-80*time.Minute)))
	post(ledger.PayoutSettled(e.host, failed, 50, false, now.Add(-70*time.Minute)))
	post(ledger.WithdrawalRequested(e.host, pending, 40, now.Add(-60*time.Minute)))
	// 5. Two gifts during a live call (real service path), then a clawback.
	if _, err := e.send(e.pc, e.call, "rose", e.host, pgtest.UUID()); err != nil {
		t.Fatal(err)
	}
	if _, err := e.send(e.pc, e.call, "teddy", e.host, pgtest.UUID()); err != nil {
		t.Fatal(err)
	}
	post(ledger.BeanClawback(e.host, pgtest.UUID(), 100, time.Now().Add(time.Second)))

	// Another host's entries must never leak into this history.
	pgtestHost(t, e)

	p := e.ph
	all := listAll(t, svc, p, "", 100)
	if len(all) != 11 {
		for _, it := range all {
			t.Logf("%s %-12s %6d  bal %6d  %s", it.OccurredAt.Format("15:04:05"), it.Type, it.Beans, it.Balance, it.Title)
		}
		t.Fatalf("want 11 history lines, got %d", len(all))
	}

	// Promise 1: the list reconciles to the balances to the Bean.
	held, avail, pend := e.balance(e.host, "bean_held"), e.balance(e.host, "bean_available"), e.balance(e.host, "bean_payout_pending")
	var sum int64
	for _, it := range all {
		sum += it.Beans
	}
	if sum != held+avail {
		t.Fatalf("sum of lines %d != held+available %d", sum, held+avail)
	}
	if all[0].Balance != held+avail {
		t.Fatalf("newest balance_after %d != balance %d", all[0].Balance, held+avail)
	}
	// ... and every running balance is the cumulative sum, oldest first.
	var run int64
	for i := len(all) - 1; i >= 0; i-- {
		run += all[i].Beans
		if all[i].Balance != run {
			t.Fatalf("line %q: balance_after %d, cumulative %d", all[i].Title, all[i].Balance, run)
		}
	}

	// Promise 2: pagination never skips or repeats a line.
	var paged []string
	cursor := ""
	for pages := 0; pages < 20; pages++ {
		pg, err := svc.ListBeanHistory(e.ctx, p, wallet.PageRequest{Cursor: cursor, Limit: 5}, "")
		if err != nil {
			t.Fatal(err)
		}
		for _, it := range pg.Items {
			paged = append(paged, it.ID)
		}
		if pg.NextCursor == nil {
			break
		}
		cursor = *pg.NextCursor
	}
	if len(paged) != len(all) {
		t.Fatalf("paged %d lines, want %d", len(paged), len(all))
	}
	for i := range all {
		if paged[i] != all[i].ID {
			t.Fatalf("page order differs at %d", i)
		}
	}

	// Promise 3: filters partition the list.
	counts := map[string]int{}
	for _, f := range []string{"calls", "gifts", "released", "withdrawals", "other"} {
		counts[f] = len(listAll(t, svc, p, f, 100))
	}
	if counts["calls"] != 2 || counts["gifts"] != 2 || counts["released"] != 1 || counts["withdrawals"] != 5 || counts["other"] != 1 {
		t.Fatalf("filter counts %+v", counts)
	}
	if total := counts["calls"] + counts["gifts"] + counts["released"] + counts["withdrawals"] + counts["other"]; total != len(all) {
		t.Fatalf("filters cover %d of %d lines", total, len(all))
	}
	if _, err := svc.ListBeanHistory(e.ctx, p, wallet.PageRequest{Limit: 5}, "bogus"); err == nil {
		t.Fatal("an unknown filter must be refused")
	}

	// Promise 4: the wording names the customer, the call and the gift.
	byType := map[string][]wallet.BeanHistoryItem{}
	for _, it := range all {
		byType[it.Type] = append(byType[it.Type], it)
	}
	call := byType["call"][0]
	if call.Title != "Call with Asha" || call.Subtitle == nil || *call.Subtitle != "2 min 05 s · 500 Diamonds/min" || call.Beans != hostBeans {
		t.Fatalf("call line: %+v", call)
	}
	if call.Status == nil || *call.Status != "released" || call.ReleasedAt == nil {
		t.Fatalf("a released call must say so: %+v", call)
	}
	wantGift := map[string]bool{"🌹 Rose from Asha": false, "🧸 Teddy Bear from Asha": false}
	for _, g := range byType["gift"] {
		if _, ok := wantGift[g.Title]; !ok {
			t.Fatalf("unexpected gift line %q", g.Title)
		}
		wantGift[g.Title] = true
		if g.Status == nil || *g.Status != "on_hold" || g.ReleasesAt == nil || !g.ReleasesAt.After(time.Now().Add(6*24*time.Hour)) {
			t.Fatalf("a fresh gift is on hold for 7 days: %+v", g)
		}
		if g.CallID == nil || *g.CallID != e.call {
			t.Fatalf("gift line must point at its call: %+v", g)
		}
	}
	for title, seen := range wantGift {
		if !seen {
			t.Fatalf("missing gift line %q", title)
		}
	}
	rel := byType["release"][0]
	if rel.Beans != 0 || rel.MovedBeans == nil || *rel.MovedBeans != hostBeans || rel.Subtitle == nil || !strings.HasPrefix(*rel.Subtitle, "Call with Asha") {
		t.Fatalf("release line: %+v", rel)
	}
	if pd := byType["payout_paid"][0]; pd.Beans != 0 || pd.MovedBeans == nil || *pd.MovedBeans != 400 {
		t.Fatalf("paid line: %+v", pd)
	}
	if f := byType["payout_failed"][0]; f.Beans != 50 {
		t.Fatalf("a failed withdrawal returns its Beans: %+v", f)
	}
	if c := byType["reversal"][0]; c.Beans != -100 || c.Title != "Earnings reversed" {
		t.Fatalf("clawback line: %+v", c)
	}

	// Promise 5: the summary adds up.
	s, err := svc.GetBeanSummary(e.ctx, p)
	if err != nil {
		t.Fatal(err)
	}
	if s.Balance != held+avail || s.OnHold != held || s.Available != avail || s.PendingPayout != pend {
		t.Fatalf("summary balances %+v vs held %d avail %d pending %d", s, held, avail, pend)
	}
	if s.LifetimeEarned != s.FromCalls+s.FromGifts+s.FromFreeCalls || s.CallCount != 1 || s.GiftCount != 2 {
		t.Fatalf("summary earned: %+v", s)
	}
	if s.FromCalls != hostBeans || s.FromFreeCalls != 2000 {
		t.Fatalf("summary by source: %+v", s)
	}
	// Everything earned is either still here, on its way out, paid, or reversed.
	if got := s.Balance + s.PendingPayout + s.PaidOut; got != s.LifetimeEarned-s.Reversed+s.Adjustments {
		t.Fatalf("earned %d - reversed %d + adjustments %d != balance %d + pending %d + paid %d",
			s.LifetimeEarned, s.Reversed, s.Adjustments, s.Balance, s.PendingPayout, s.PaidOut)
	}
	if s.PaidOut != 400 || s.Reversed != 100 || s.PendingPayout != 40 {
		t.Fatalf("summary movements: %+v", s)
	}
	if s.EarnedToday > s.Earned7Days || s.Earned7Days > s.Earned30Days || s.Earned30Days > s.LifetimeEarned {
		t.Fatalf("recent windows must nest: %+v", s)
	}
	e.ledgerBalanced()
}

func mustSettlement(t *testing.T, c ledger.CallCharge) ledger.Entry {
	t.Helper()
	en, err := ledger.CallSettlement(c)
	if err != nil {
		t.Fatal(err)
	}
	return en
}

// pgtestHost makes a second host with Beans of its own.
func pgtestHost(t *testing.T, e *env) string {
	t.Helper()
	h := pgtest.NewUser(t, e.admin, true, "customer", "host")
	identitytest.Beans(t, e.admin, h, 5555)
	return h
}

func listAll(t *testing.T, svc *wallet.Service, p auth.Principal, filter string, limit int) []wallet.BeanHistoryItem {
	t.Helper()
	pg, err := svc.ListBeanHistory(context.Background(), p, wallet.PageRequest{Limit: limit}, filter)
	if err != nil {
		t.Fatal(err)
	}
	return pg.Items
}
