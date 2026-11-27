//go:build integration

package postgres_test

import (
	"context"
	"fmt"
	"strconv"
	"sync"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/cashfree"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/modules/purchases"
	"dashuri/backend/internal/testsupport/pgtest"
)

func userWithPhone(t *testing.T, m *moneyEnv) string {
	u := pgtest.NewUser(t, m.admin, true)
	if _, err := m.admin.Exec(context.Background(), `update auth.users set phone = '919876543210' where id = $1`, u); err != nil {
		t.Fatal(err)
	}
	return u
}

func signedWebhook(orderID, typ string) ([]byte, map[string]string) {
	body := []byte(fmt.Sprintf(`{"data":{"order":{"order_id":%q,"order_amount":1.00,"order_currency":"INR"},"payment":{"payment_status":"SUCCESS"}},"event_time":"2026-11-21T12:00:00+05:30","type":%q}`, orderID, typ))
	ts := strconv.FormatInt(time.Now().UnixMilli(), 10)
	return body, map[string]string{"X-Webhook-Signature": cashfree.Sign("cf-secret", ts, body), "X-Webhook-Timestamp": ts, "X-Webhook-Version": "2025-01-01"}
}

func TestCashfreeWebhookAndPollRaceCreditOnce(t *testing.T) {
	api, admin := pgtest.Pools(t)
	m := newMoneyEnv(t, api, admin)
	ctx := context.Background()
	user := userWithPhone(t, m)
	o, err := m.svc.CreateCashfreeOrder(ctx, principal(user), purchases.CreateCashfreeOrderRequest{ProductId: "diamonds_54000"})
	if err != nil {
		t.Fatal(err)
	}
	if o.AmountPaise != 119900 || o.Diamonds != 54000 || o.State != "created" || o.PaymentSessionId == "" || o.Environment != "sandbox" {
		t.Fatalf("order %+v", o)
	}
	// Not paid yet: polling does not credit.
	if got, err := m.svc.GetCashfreeOrder(ctx, principal(user), o.OrderId); err != nil || got.State != "created" {
		t.Fatalf("%+v %v", got, err)
	}
	// Another user cannot see it.
	if _, err := m.svc.GetCashfreeOrder(ctx, principal(pgtest.NewUser(t, admin, true)), o.OrderId); ruleCode(err) != "not_found" {
		t.Fatalf("non-owner: %v", err)
	}
	m.cf.set(o.OrderId, map[string]any{"order_status": "PAID"})

	var wg sync.WaitGroup
	var mu sync.Mutex
	var failures []error
	for i := 0; i < 6; i++ {
		wg.Add(2)
		go func() {
			defer wg.Done()
			body, h := signedWebhook(o.OrderId, "PAYMENT_SUCCESS_WEBHOOK")
			if err := m.svc.CashfreeWebhook(ctx, body, h); err != nil {
				mu.Lock()
				failures = append(failures, err)
				mu.Unlock()
			}
		}()
		go func() {
			defer wg.Done()
			if _, err := m.svc.GetCashfreeOrder(ctx, principal(user), o.OrderId); err != nil {
				mu.Lock()
				failures = append(failures, err)
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	if len(failures) > 0 {
		t.Fatalf("errors: %v", failures)
	}
	got, err := m.svc.GetCashfreeOrder(ctx, principal(user), o.OrderId)
	if err != nil || got.State != "credited" || got.DiamondsCredited != 54000 {
		t.Fatalf("%+v %v", got, err)
	}
	if b := balance(t, api, user, ledger.UserDiamondPurchased); b != 54000 {
		t.Fatalf("balance %d, want 54000 exactly once", b)
	}
	if n := count(t, admin, `select count(*) from ledger.journal_entries where idempotency_key = $1`, "purchase_credit:cashfree:"+o.OrderId); n != 1 {
		t.Fatalf("credit entries %d", n)
	}
	// Regression (2026-11-27): the purchase row records the order amount.
	if n := count(t, admin, `select count(*) from commerce.purchases p join commerce.cashfree_orders o on o.order_id = $1
		where p.purchase_token_hash = $2 and p.price_paise = o.amount_paise and p.price_source = 'gateway_order'`,
		o.OrderId, purchases.CashfreeTokenHash(o.OrderId)); n != 1 {
		t.Fatalf("cashfree price snapshot rows %d", n)
	}
	if n := count(t, admin, `select count(*) from commerce.purchases where purchase_token_hash = $1 and rail = 'cashfree' and state = 'credited'`,
		purchases.CashfreeTokenHash(o.OrderId)); n != 1 {
		t.Fatalf("purchase rows %d", n)
	}
	if xp := count(t, admin, `select coalesce(sum(xp_delta),0) from ledger.xp_events where user_id = $1`, user); xp != 8*54000 {
		t.Fatalf("xp %d", xp)
	}
	// The poll job sees no open order for this user any more.
	if n := count(t, admin, `select count(*) from commerce.cashfree_orders where order_id = $1 and state in ('created','pending')`, o.OrderId); n != 0 {
		t.Fatal("order still open")
	}
}

func TestCashfreeTamperedWebhookRefused(t *testing.T) {
	api, admin := pgtest.Pools(t)
	m := newMoneyEnv(t, api, admin)
	ctx := context.Background()
	user := userWithPhone(t, m)
	o, err := m.svc.CreateCashfreeOrder(ctx, principal(user), purchases.CreateCashfreeOrderRequest{ProductId: "diamonds_4000"})
	if err != nil {
		t.Fatal(err)
	}
	m.cf.set(o.OrderId, map[string]any{"order_status": "PAID"})
	body, h := signedWebhook(o.OrderId, "PAYMENT_SUCCESS_WEBHOOK")
	tampered := append([]byte{}, body...)
	tampered[len(tampered)-3] = 'X'
	if err := m.svc.CashfreeWebhook(ctx, tampered, h); ruleCode(err) != "unauthenticated" {
		t.Fatalf("tampered webhook: %v", err)
	}
	stale := strconv.FormatInt(time.Now().Add(-10*time.Minute).UnixMilli(), 10)
	if err := m.svc.CashfreeWebhook(ctx, body, map[string]string{"X-Webhook-Signature": cashfree.Sign("cf-secret", stale, body), "X-Webhook-Timestamp": stale}); ruleCode(err) != "unauthenticated" {
		t.Fatalf("stale webhook: %v", err)
	}
	if b := balance(t, api, user, ledger.UserDiamondPurchased); b != 0 {
		t.Fatalf("credited from a refused webhook: %d", b)
	}
	if n := count(t, admin, `select count(*) from commerce.cashfree_webhooks where order_id = $1`, o.OrderId); n != 0 {
		t.Fatal("refused webhook was recorded")
	}
}

func TestCashfreeAmountMismatchNotCredited(t *testing.T) {
	api, admin := pgtest.Pools(t)
	m := newMoneyEnv(t, api, admin)
	ctx := context.Background()
	user := userWithPhone(t, m)
	o, err := m.svc.CreateCashfreeOrder(ctx, principal(user), purchases.CreateCashfreeOrderRequest{ProductId: "diamonds_140000"})
	if err != nil {
		t.Fatal(err)
	}
	m.cf.set(o.OrderId, map[string]any{"order_status": "PAID", "order_amount": 1.00})
	body, h := signedWebhook(o.OrderId, "PAYMENT_SUCCESS_WEBHOOK")
	if err := m.svc.CashfreeWebhook(ctx, body, h); err != nil {
		t.Fatal(err)
	}
	got, err := m.svc.GetCashfreeOrder(ctx, principal(user), o.OrderId)
	if err != nil || got.State != "failed" || got.DiamondsCredited != 0 {
		t.Fatalf("%+v %v", got, err)
	}
	if b := balance(t, api, user, ledger.UserDiamondPurchased); b != 0 {
		t.Fatalf("mismatched amount credited: %d", b)
	}
	if n := count(t, admin, `select count(*) from audit.events where target = $1 and action = 'cashfree.amount_mismatch'`, o.OrderId); n != 1 {
		t.Fatalf("mismatch audit %d", n)
	}
}

func TestCashfreeGuards(t *testing.T) {
	api, admin := pgtest.Pools(t)
	m := newMoneyEnv(t, api, admin)
	ctx := context.Background()
	noPhone := pgtest.NewUser(t, admin, true)
	if _, err := m.svc.CreateCashfreeOrder(ctx, principal(noPhone), purchases.CreateCashfreeOrderRequest{ProductId: "diamonds_4000"}); ruleCode(err) != "phone_required" {
		t.Fatalf("phone_required: %v", err)
	}
	d := m.deps
	d.CashfreeEnabled = false
	if _, err := purchases.NewService(d).CreateCashfreeOrder(ctx, principal(noPhone), purchases.CreateCashfreeOrderRequest{ProductId: "diamonds_4000"}); ruleCode(err) != "rail_disabled" {
		t.Fatalf("rail_disabled: %v", err)
	}
	d = m.deps
	d.Cashfree = nil
	if _, err := purchases.NewService(d).CreateCashfreeOrder(ctx, principal(noPhone), purchases.CreateCashfreeOrderRequest{ProductId: "diamonds_4000"}); ruleCode(err) != "cashfree_not_configured" {
		t.Fatalf("cashfree_not_configured: %v", err)
	}
	// Packages expose prices, rails and the ₹ estimate basis.
	list, err := m.svc.ListDiamondPackages(ctx, principal(noPhone))
	if err != nil || len(list.Items) != 6 || list.Items[0].PricePaise != 9900 || list.ApproxPaisePerDiamondMilli != 2475 ||
		len(list.Rails) != 2 || list.Rails[0] != "google_play" || list.Rails[1] != "cashfree" {
		t.Fatalf("%+v %v", list, err)
	}
	// Poll job expires orders older than 24 h after a final check.
	user := userWithPhone(t, m)
	o, err := m.svc.CreateCashfreeOrder(ctx, principal(user), purchases.CreateCashfreeOrderRequest{ProductId: "diamonds_4000"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := admin.Exec(ctx, `update commerce.cashfree_orders set created_at = now() - interval '25 hours' where order_id = $1`, o.OrderId); err != nil {
		t.Fatal(err)
	}
	if _, _, err := m.svc.PollCashfreeOrders(ctx); err != nil {
		t.Fatal(err)
	}
	if got, _ := m.svc.GetCashfreeOrder(ctx, principal(user), o.OrderId); got.State != "expired" {
		t.Fatalf("old order state %s", got.State)
	}
}
