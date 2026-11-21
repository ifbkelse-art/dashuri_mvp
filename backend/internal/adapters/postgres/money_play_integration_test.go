//go:build integration

package postgres_test

import (
	"context"
	"sync"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/modules/purchases"
	"dashuri/backend/internal/testsupport/pgtest"
)

func TestPlayPurchaseCreditedOnceUnderConcurrency(t *testing.T) {
	api, admin := pgtest.Pools(t)
	m := newMoneyEnv(t, api, admin)
	user := pgtest.NewUser(t, admin, true)
	token := "tok" + pgtest.UUID()[:8]
	m.play.set(token, 0, map[string]any{"obfuscatedExternalAccountId": purchases.SHA256Hex(user)})

	var wg sync.WaitGroup
	results := make([]purchases.PurchaseVerification, 10)
	errs := make([]error, 10)
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			results[i], errs[i] = m.svc.VerifyGooglePlayPurchase(context.Background(), principal(user),
				purchases.VerifyGooglePlayRequest{ProductId: "diamonds_4000", PurchaseToken: token})
		}(i)
	}
	wg.Wait()
	for i := range results {
		if errs[i] != nil || results[i].Status != "credited" || results[i].DiamondsCredited != 4000 || results[i].PurchaseId != results[0].PurchaseId {
			t.Fatalf("verify %d: %+v %v", i, results[i], errs[i])
		}
	}
	if b := balance(t, api, user, ledger.UserDiamondPurchased); b != 4000 {
		t.Fatalf("balance %d, want 4000", b)
	}
	hash := purchases.SHA256Hex(token)
	if n := count(t, admin, `select count(*) from ledger.journal_entries where idempotency_key = $1`, "purchase_credit:"+hash); n != 1 {
		t.Fatalf("%d credit entries", n)
	}
	if n := count(t, admin, `select count(*) from commerce.purchases where purchase_token_hash = $1 and state = 'credited' and rail = 'google_play'`, hash); n != 1 {
		t.Fatalf("%d purchase rows", n)
	}
	if xp := count(t, admin, `select coalesce(sum(xp_delta),0) from ledger.xp_events where user_id = $1`, user); xp != 32000 {
		t.Fatalf("xp %d, want 8 × 4000", xp)
	}
	m.play.mu.Lock()
	acks := m.play.acks[token]
	m.play.mu.Unlock()
	if acks < 1 {
		t.Fatal("purchase was not acknowledged")
	}
}

func TestPlayTokenReusedByAnotherAccountRefused(t *testing.T) {
	api, admin := pgtest.Pools(t)
	m := newMoneyEnv(t, api, admin)
	a, b := pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true)
	token := "tok" + pgtest.UUID()[:8]
	m.play.set(token, 0, nil)
	ctx := context.Background()
	if _, err := m.svc.VerifyGooglePlayPurchase(ctx, principal(a), purchases.VerifyGooglePlayRequest{ProductId: "diamonds_4000", PurchaseToken: token}); err != nil {
		t.Fatal(err)
	}
	_, err := m.svc.VerifyGooglePlayPurchase(ctx, principal(b), purchases.VerifyGooglePlayRequest{ProductId: "diamonds_4000", PurchaseToken: token})
	if ruleCode(err) != "purchase_already_used_by_other_account" {
		t.Fatalf("want purchase_already_used_by_other_account, got %v", err)
	}
	if balance(t, api, b, ledger.UserDiamondPurchased) != 0 || balance(t, api, a, ledger.UserDiamondPurchased) != 4000 {
		t.Fatal("balances changed")
	}
	// Obfuscated account id bound to another user is refused before crediting.
	tok2 := "tok" + pgtest.UUID()[:8]
	m.play.set(tok2, 0, map[string]any{"obfuscatedExternalAccountId": purchases.SHA256Hex(a)})
	_, err = m.svc.VerifyGooglePlayPurchase(ctx, principal(b), purchases.VerifyGooglePlayRequest{ProductId: "diamonds_4000", PurchaseToken: tok2})
	if ruleCode(err) != "purchase_already_used_by_other_account" {
		t.Fatalf("obfuscated mismatch: %v", err)
	}
	// Unknown product and invalid token.
	if _, err := m.svc.VerifyGooglePlayPurchase(ctx, principal(b), purchases.VerifyGooglePlayRequest{ProductId: "nope", PurchaseToken: tok2}); ruleCode(err) != "product_unknown" {
		t.Fatalf("unknown product: %v", err)
	}
	if _, err := m.svc.VerifyGooglePlayPurchase(ctx, principal(b), purchases.VerifyGooglePlayRequest{ProductId: "diamonds_4000", PurchaseToken: "unknown-token"}); ruleCode(err) != "purchase_token_invalid" {
		t.Fatalf("invalid token: %v", err)
	}
	// No credentials → 503 play_not_configured.
	d := m.deps
	d.Play = nil
	if _, err := purchases.NewService(d).VerifyGooglePlayPurchase(ctx, principal(b), purchases.VerifyGooglePlayRequest{ProductId: "diamonds_4000", PurchaseToken: tok2}); ruleCode(err) != "play_not_configured" {
		t.Fatalf("no play: %v", err)
	}
}

func TestPlayPendingPurchaseNotCreditedUntilRTDN(t *testing.T) {
	api, admin := pgtest.Pools(t)
	m := newMoneyEnv(t, api, admin)
	user := pgtest.NewUser(t, admin, true)
	token := "tok" + pgtest.UUID()[:8]
	m.play.set(token, 2, nil)
	ctx := context.Background()
	res, err := m.svc.VerifyGooglePlayPurchase(ctx, principal(user), purchases.VerifyGooglePlayRequest{ProductId: "diamonds_12500", PurchaseToken: token})
	if err != nil || res.Status != "pending" || res.DiamondsCredited != 0 {
		t.Fatalf("%+v %v", res, err)
	}
	if b := balance(t, api, user, ledger.UserDiamondPurchased); b != 0 {
		t.Fatalf("pending purchase credited: %d", b)
	}
	// Payment completes; RTDN ONE_TIME_PRODUCT_PURCHASED credits it.
	m.play.set(token, 0, nil)
	msg := pgtest.UUID()
	if err := m.rtdn(t, msg, map[string]any{"oneTimeProductNotification": map[string]any{"notificationType": 1, "purchaseToken": token, "sku": "diamonds_12500"}}); err != nil {
		t.Fatal(err)
	}
	if err := m.rtdn(t, msg, map[string]any{"oneTimeProductNotification": map[string]any{"notificationType": 1, "purchaseToken": token, "sku": "diamonds_12500"}}); err != nil {
		t.Fatal(err)
	}
	if b := balance(t, api, user, ledger.UserDiamondPurchased); b != 12500 {
		t.Fatalf("late credit balance %d", b)
	}
	if n := count(t, admin, `select count(*) from commerce.play_notifications where message_id = $1`, msg); n != 1 {
		t.Fatalf("notification rows %d", n)
	}
	// A bad OIDC token is refused.
	if err := m.svc.GooglePlayNotification(ctx, []byte(`{}`), map[string]string{"Authorization": "Bearer x.y.z"}); ruleCode(err) != "unauthenticated" {
		t.Fatalf("bad push token: %v", err)
	}
}

func TestVoidedPurchaseReversesOnlyUnspent(t *testing.T) {
	api, admin := pgtest.Pools(t)
	m := newMoneyEnv(t, api, admin)
	ctx := context.Background()
	user := pgtest.NewUser(t, admin, true)
	host := pgtest.NewUser(t, admin, true, "customer", "host")
	token := "tok" + pgtest.UUID()[:8]
	m.play.set(token, 0, nil)
	res, err := m.svc.VerifyGooglePlayPurchase(ctx, principal(user), purchases.VerifyGooglePlayRequest{ProductId: "diamonds_4000", PurchaseToken: token})
	if err != nil {
		t.Fatal(err)
	}
	// Spend 3,000 of the 4,000 Diamonds on a call.
	settle, _ := ledger.CallSettlement(ledger.CallCharge{CallID: pgtest.UUID(), CustomerID: user, HostID: host, FromPurchased: 3000,
		HostBeans: 1799, RuleSetVersion: "2026-11-17-founder", At: time.Now()})
	if _, _, err := (postgres.LedgerStore{Pool: api}).Post(ctx, settle); err != nil {
		t.Fatal(err)
	}
	msg := pgtest.UUID()
	if err := m.rtdn(t, msg, map[string]any{"voidedPurchaseNotification": map[string]any{"purchaseToken": token, "orderId": "GPA." + token, "productType": 2, "refundType": 1}}); err != nil {
		t.Fatal(err)
	}
	if b := balance(t, api, user, ledger.UserDiamondPurchased); b != 0 {
		t.Fatalf("balance after reversal %d, want 0", b)
	}
	var removed, unrecovered int64
	var state string
	if err := admin.QueryRow(ctx, `select state, reversed_diamonds, unrecovered_diamonds from commerce.purchases where id = $1`, res.PurchaseId).
		Scan(&state, &removed, &unrecovered); err != nil {
		t.Fatal(err)
	}
	if state != "reversed" || removed != 1000 || unrecovered != 3000 {
		t.Fatalf("state=%s removed=%d unrecovered=%d", state, removed, unrecovered)
	}
	if xp := count(t, admin, `select coalesce(sum(xp_delta),0) from ledger.xp_events where user_id = $1`, user); xp != 0 {
		t.Fatalf("xp after reversal %d, want 0", xp)
	}
	// The Voided Purchases API reports the same purchase: no second reversal.
	m.play.mu.Lock()
	m.play.voided = []map[string]any{{"purchaseToken": token, "orderId": "GPA." + token, "voidedTimeMillis": "1763700000000"}}
	m.play.mu.Unlock()
	if n, err := m.svc.PollVoidedPurchases(ctx); err != nil || n != 0 {
		t.Fatalf("poll: %d %v", n, err)
	}
	if n := count(t, admin, `select count(*) from ledger.journal_entries where idempotency_key = $1`, "purchase_reversal:"+res.PurchaseId); n != 1 {
		t.Fatalf("reversal entries %d", n)
	}
	if n := count(t, admin, `select count(*) from audit.events where target = $1 and action = 'purchase.reversal_shortfall'`, res.PurchaseId); n != 1 {
		t.Fatalf("shortfall audit %d", n)
	}
}

func TestPollVoidedPurchasesReversesCreditedPurchase(t *testing.T) {
	api, admin := pgtest.Pools(t)
	m := newMoneyEnv(t, api, admin)
	ctx := context.Background()
	user := pgtest.NewUser(t, admin, true)
	token := "tok" + pgtest.UUID()[:8]
	m.play.set(token, 0, nil)
	if _, err := m.svc.VerifyGooglePlayPurchase(ctx, principal(user), purchases.VerifyGooglePlayRequest{ProductId: "diamonds_4000", PurchaseToken: token}); err != nil {
		t.Fatal(err)
	}
	m.play.mu.Lock()
	m.play.voided = []map[string]any{{"purchaseToken": token, "voidedTimeMillis": "1763700000000"}}
	m.play.mu.Unlock()
	if n, err := m.svc.PollVoidedPurchases(ctx); err != nil || n != 1 {
		t.Fatalf("poll: %d %v", n, err)
	}
	if b := balance(t, api, user, ledger.UserDiamondPurchased); b != 0 {
		t.Fatalf("balance %d", b)
	}
}
