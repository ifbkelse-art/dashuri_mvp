package cashfree

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"

	"dashuri/backend/internal/modules/purchases"
)

func TestVerifySignature(t *testing.T) {
	secret := "cf-secret"
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	body := []byte(`{"type":"PAYMENT_SUCCESS_WEBHOOK","data":{"order":{"order_id":"dsh_abc12345"}}}`)
	ts := strconv.FormatInt(now.Add(-30*time.Second).UnixMilli(), 10)
	sig := Sign(secret, ts, body)

	if err := VerifySignature(secret, body, sig, ts, now); err != nil {
		t.Fatalf("valid signature refused: %v", err)
	}
	tampered := append([]byte{}, body...)
	tampered[10] = 'X'
	if err := VerifySignature(secret, tampered, sig, ts, now); !errors.Is(err, ErrSignature) {
		t.Fatal("tampered body accepted")
	}
	if err := VerifySignature("other", body, sig, ts, now); !errors.Is(err, ErrSignature) {
		t.Fatal("wrong secret accepted")
	}
	stale := strconv.FormatInt(now.Add(-6*time.Minute).UnixMilli(), 10)
	if err := VerifySignature(secret, body, Sign(secret, stale, body), stale, now); !errors.Is(err, ErrSignature) {
		t.Fatal("stale timestamp accepted")
	}
	if err := VerifySignature(secret, body, "", ts, now); !errors.Is(err, ErrSignature) {
		t.Fatal("missing signature accepted")
	}
	if err := VerifySignature(secret, body, sig, "not-a-number", now); !errors.Is(err, ErrSignature) {
		t.Fatal("garbage timestamp accepted")
	}
}

func TestAmountConversion(t *testing.T) {
	cases := map[string]int64{"1199": 119900, "1199.00": 119900, "1199.5": 119950, "0.99": 99, "99.10": 9910}
	for in, want := range cases {
		got, err := AmountToPaise(json.Number(in))
		if err != nil || got != want {
			t.Errorf("%s: got %d %v want %d", in, got, err, want)
		}
	}
	for _, bad := range []string{"1.234", "-5", "abc", ""} {
		if _, err := AmountToPaise(json.Number(bad)); err == nil {
			t.Errorf("%q accepted", bad)
		}
	}
	if PaiseToAmount(119905).String() != "1199.05" {
		t.Fatal(PaiseToAmount(119905))
	}
}

func TestCreateAndGetOrderSendHeaders(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("x-client-id") != "id" || r.Header.Get("x-client-secret") != "sec" || r.Header.Get("x-api-version") != "2025-01-01" {
			t.Errorf("missing headers")
		}
		if r.Method == http.MethodPost {
			var body map[string]any
			_ = json.NewDecoder(r.Body).Decode(&body)
			if body["order_amount"].(float64) != 1199 || body["order_currency"] != "INR" {
				t.Errorf("bad body %v", body)
			}
		}
		_, _ = w.Write([]byte(`{"cf_order_id":"2149460581","order_id":"dsh_abcdefgh","order_status":"ACTIVE","order_amount":1199.00,"order_currency":"INR","payment_session_id":"session_x"}`))
	}))
	defer srv.Close()
	c := New("sandbox", "id", "sec", "", srv.Client())
	c.BaseURL = srv.URL
	o, err := c.CreateOrder(context.Background(), purchases.CashfreeCreateOrder{OrderID: "dsh_abcdefgh", AmountPaise: 119900, Currency: "INR",
		CustomerID: "u", CustomerPhone: "9999999999", ExpiresAt: time.Now().Add(30 * time.Minute)})
	if err != nil || o.PaymentSessionID != "session_x" || o.AmountPaise != 119900 || o.CFOrderID != "2149460581" {
		t.Fatalf("%+v %v", o, err)
	}
	if _, err := c.GetOrder(context.Background(), "dsh_abcdefgh"); err != nil {
		t.Fatal(err)
	}
}
