//go:build integration

package postgres_test

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/adapters/cashfree"
	"dashuri/backend/internal/adapters/googleplay"
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/modules/purchases"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/clock"
	"dashuri/backend/internal/platform/db"
)

const testPackage = "app.dashuri.test"

// fakePlay is an httptest stand-in for oauth2 + androidpublisher v3.
type fakePlay struct {
	mu       sync.Mutex
	srv      *httptest.Server
	purchase map[string]map[string]any // token → ProductPurchase JSON
	acks     map[string]int
	voided   []map[string]any
}

func newFakePlay(t *testing.T) *fakePlay {
	f := &fakePlay{purchase: map[string]map[string]any{}, acks: map[string]int{}}
	mux := http.NewServeMux()
	mux.HandleFunc("POST /token", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`{"access_token":"fake-at","expires_in":3600}`))
	})
	prefix := "/androidpublisher/v3/applications/" + testPackage + "/purchases/"
	mux.HandleFunc("GET "+prefix+"voidedpurchases", func(w http.ResponseWriter, r *http.Request) {
		f.mu.Lock()
		defer f.mu.Unlock()
		_ = json.NewEncoder(w).Encode(map[string]any{"voidedPurchases": f.voided})
	})
	mux.HandleFunc(prefix+"products/{product}/tokens/{rest}", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer fake-at" {
			w.WriteHeader(401)
			return
		}
		rest := r.PathValue("rest")
		f.mu.Lock()
		defer f.mu.Unlock()
		if tok, ok := strings.CutSuffix(rest, ":consume"); ok && r.Method == http.MethodPost {
			f.acks[tok]++
			w.WriteHeader(204)
			return
		}
		p, ok := f.purchase[rest]
		if !ok {
			w.WriteHeader(404)
			return
		}
		_ = json.NewEncoder(w).Encode(p)
	})
	f.srv = httptest.NewServer(mux)
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fakePlay) set(token string, state int, extra map[string]any) {
	f.mu.Lock()
	defer f.mu.Unlock()
	p := map[string]any{"purchaseState": state, "orderId": "GPA." + token, "acknowledgementState": 0,
		"purchaseTimeMillis": strconv.FormatInt(time.Now().UnixMilli(), 10)}
	for k, v := range extra {
		p[k] = v
	}
	f.purchase[token] = p
}

func (f *fakePlay) client(t *testing.T) *googleplay.Client {
	key, _ := rsa.GenerateKey(rand.Reader, 2048)
	der, _ := x509.MarshalPKCS8PrivateKey(key)
	creds, _ := json.Marshal(map[string]string{"type": "service_account", "client_email": "svc@test.iam.gserviceaccount.com",
		"private_key": string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})), "token_uri": f.srv.URL + "/token"})
	c, err := googleplay.New(creds, f.srv.Client())
	if err != nil {
		t.Fatal(err)
	}
	c.BaseURL = f.srv.URL
	return c
}

// fakeCashfree is an httptest stand-in for Cashfree PG /orders.
type fakeCashfree struct {
	mu     sync.Mutex
	srv    *httptest.Server
	orders map[string]map[string]any
	gets   int
}

func newFakeCashfree(t *testing.T) *fakeCashfree {
	f := &fakeCashfree{orders: map[string]map[string]any{}}
	mux := http.NewServeMux()
	mux.HandleFunc("POST /orders", func(w http.ResponseWriter, r *http.Request) {
		var body map[string]any
		_ = json.NewDecoder(r.Body).Decode(&body)
		cd, _ := body["customer_details"].(map[string]any)
		if r.Header.Get("x-client-secret") != "cf-secret" || cd["customer_phone"] == "" {
			w.WriteHeader(400)
			return
		}
		id := body["order_id"].(string)
		o := map[string]any{"cf_order_id": "cf_" + id, "order_id": id, "order_status": "ACTIVE",
			"order_amount": body["order_amount"], "order_currency": body["order_currency"], "payment_session_id": "session_" + id}
		f.mu.Lock()
		f.orders[id] = o
		f.mu.Unlock()
		_ = json.NewEncoder(w).Encode(o)
	})
	mux.HandleFunc("GET /orders/{id}", func(w http.ResponseWriter, r *http.Request) {
		f.mu.Lock()
		defer f.mu.Unlock()
		f.gets++
		o, ok := f.orders[r.PathValue("id")]
		if !ok {
			w.WriteHeader(404)
			return
		}
		_ = json.NewEncoder(w).Encode(o)
	})
	f.srv = httptest.NewServer(mux)
	t.Cleanup(f.srv.Close)
	return f
}

func (f *fakeCashfree) set(orderID string, kv map[string]any) {
	f.mu.Lock()
	defer f.mu.Unlock()
	for k, v := range kv {
		f.orders[orderID][k] = v
	}
}

func (f *fakeCashfree) client() *cashfree.Client {
	c := cashfree.New("sandbox", "cf-id", "cf-secret", "2025-01-01", f.srv.Client())
	c.BaseURL = f.srv.URL
	return c
}

type moneyEnv struct {
	api, admin *pgxpool.Pool
	play       *fakePlay
	cf         *fakeCashfree
	pushKey    *rsa.PrivateKey
	svc        *purchases.Service
	deps       purchases.Deps
}

const rtdnAudience = "https://api.test/v1/webhooks/google-play/rtdn"
const rtdnEmail = "rtdn@test.iam.gserviceaccount.com"

func newMoneyEnv(t *testing.T, api, admin *pgxpool.Pool) *moneyEnv {
	t.Helper()
	// auth.users carries the phone in Supabase; the local stub lacks the column.
	if _, err := admin.Exec(context.Background(), `alter table auth.users add column if not exists phone text`); err != nil {
		t.Fatal(err)
	}
	m := &moneyEnv{api: api, admin: admin, play: newFakePlay(t), cf: newFakeCashfree(t)}
	m.pushKey, _ = rsa.GenerateKey(rand.Reader, 2048)
	m.deps = purchases.Deps{
		Rules: economy.Founder(), Repo: postgres.PurchasesRepo{Pool: api, Tx: db.TxManager{Pool: api}}, Clock: clock.System{},
		PackageName: testPackage, Play: m.play.client(t),
		Push: &googleplay.PushVerifier{Audience: rtdnAudience, Email: rtdnEmail,
			Keyfunc: func(*jwt.Token) (any, error) { return &m.pushKey.PublicKey, nil }},
		CashfreeEnabled: true, Cashfree: m.cf.client(),
	}
	m.svc = purchases.NewService(m.deps)
	return m
}

func (m *moneyEnv) pushAuth() string {
	s, _ := jwt.NewWithClaims(jwt.SigningMethodRS256, jwt.MapClaims{"iss": "https://accounts.google.com", "aud": rtdnAudience,
		"email": rtdnEmail, "email_verified": true, "exp": time.Now().Add(time.Hour).Unix()}).SignedString(m.pushKey)
	return "Bearer " + s
}

func (m *moneyEnv) rtdn(t *testing.T, msgID string, notification map[string]any) error {
	t.Helper()
	notification["version"], notification["packageName"] = "1.0", testPackage
	data, _ := json.Marshal(notification)
	body, _ := json.Marshal(map[string]any{"message": map[string]any{"messageId": msgID, "data": base64.StdEncoding.EncodeToString(data)},
		"subscription": "projects/p/subscriptions/rtdn"})
	return m.svc.GooglePlayNotification(context.Background(), body, map[string]string{"Authorization": m.pushAuth()})
}

func principal(id string, roles ...auth.Role) auth.Principal {
	if len(roles) == 0 {
		roles = []auth.Role{auth.RoleCustomer}
	}
	return auth.Principal{UserID: id, Roles: roles, Status: "active", AgeEligible: true}
}

func balance(t *testing.T, api *pgxpool.Pool, user string, k ledger.AccountKind) int64 {
	t.Helper()
	b, err := postgres.LedgerStore{Pool: api}.Balance(context.Background(), ledger.User(user, k), ledger.CurrencyOf(k))
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func ruleCode(err error) string {
	if e := apperr.As(err); e != nil {
		return e.Code
	}
	return ""
}

func count(t *testing.T, q *pgxpool.Pool, sql string, args ...any) int64 {
	t.Helper()
	var n int64
	if err := q.QueryRow(context.Background(), sql, args...).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}
