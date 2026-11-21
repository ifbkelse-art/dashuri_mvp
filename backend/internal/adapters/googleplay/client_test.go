package googleplay

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"dashuri/backend/internal/modules/purchases"
)

func intp(i int) *int { return &i }

func TestMapProductPurchase(t *testing.T) {
	p := MapProductPurchase(ProductPurchaseResponse{
		PurchaseTimeMillis: "1763700000000", PurchaseState: intp(2), ConsumptionState: 0, OrderID: "GPA.1",
		PurchaseType: intp(0), AcknowledgementState: 1, ObfuscatedExternalAccountID: "abc", Quantity: intp(3),
	})
	if p.PurchaseState != purchases.PlayStatePending || !p.Acknowledged || p.Consumed || p.OrderID != "GPA.1" ||
		p.ObfuscatedAccountID != "abc" || p.Quantity != 3 || p.PurchaseType == nil || *p.PurchaseType != 0 ||
		p.PurchaseTime.UnixMilli() != 1763700000000 {
		t.Fatalf("bad mapping %+v", p)
	}
	// Missing purchaseState means purchased; missing quantity means 1.
	q := MapProductPurchase(ProductPurchaseResponse{ConsumptionState: 1})
	if q.PurchaseState != purchases.PlayStatePurchased || q.Quantity != 1 || !q.Consumed || q.PurchaseType != nil {
		t.Fatalf("defaults %+v", q)
	}
}

// FakeCredentials returns a service-account JSON whose token_uri is tokenURL.
func fakeCredentials(t *testing.T, tokenURL string) []byte {
	key, _ := rsa.GenerateKey(rand.Reader, 2048)
	der, _ := x509.MarshalPKCS8PrivateKey(key)
	pemKey := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})
	b, _ := json.Marshal(map[string]string{"type": "service_account", "client_email": "svc@example.iam.gserviceaccount.com",
		"private_key": string(pemKey), "private_key_id": "k1", "token_uri": tokenURL})
	return b
}

func TestClientMintsTokenAndCallsAPI(t *testing.T) {
	tokenCalls := 0
	mux := http.NewServeMux()
	mux.HandleFunc("POST /token", func(w http.ResponseWriter, r *http.Request) {
		tokenCalls++
		_ = r.ParseForm()
		if r.Form.Get("grant_type") != "urn:ietf:params:oauth:grant-type:jwt-bearer" || r.Form.Get("assertion") == "" {
			t.Error("bad token request")
		}
		_, _ = w.Write([]byte(`{"access_token":"at-1","expires_in":3600}`))
	})
	mux.HandleFunc("GET /androidpublisher/v3/applications/app.dashuri/purchases/products/diamonds_4000/tokens/good", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer at-1" {
			t.Error("missing bearer")
		}
		_, _ = w.Write([]byte(`{"purchaseState":0,"orderId":"GPA.9","acknowledgementState":0}`))
	})
	mux.HandleFunc("GET /androidpublisher/v3/applications/app.dashuri/purchases/products/diamonds_4000/tokens/bad", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(404)
	})
	mux.HandleFunc("POST /androidpublisher/v3/applications/app.dashuri/purchases/products/diamonds_4000/tokens/good:acknowledge", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(204)
	})
	srv := httptest.NewServer(mux)
	defer srv.Close()
	c, err := New(fakeCredentials(t, srv.URL+"/token"), srv.Client())
	if err != nil {
		t.Fatal(err)
	}
	c.BaseURL = srv.URL
	ctx := context.Background()
	p, err := c.GetProductPurchase(ctx, "app.dashuri", "diamonds_4000", "good")
	if err != nil || p.OrderID != "GPA.9" {
		t.Fatalf("%+v %v", p, err)
	}
	if _, err := c.GetProductPurchase(ctx, "app.dashuri", "diamonds_4000", "bad"); !errors.Is(err, purchases.ErrPlayTokenInvalid) {
		t.Fatalf("want ErrPlayTokenInvalid, got %v", err)
	}
	if err := c.Acknowledge(ctx, "app.dashuri", "diamonds_4000", "good"); err != nil {
		t.Fatal(err)
	}
	if tokenCalls != 1 {
		t.Fatalf("token should be cached, minted %d times", tokenCalls)
	}
}

func TestPushVerifier(t *testing.T) {
	key, _ := rsa.GenerateKey(rand.Reader, 2048)
	other, _ := rsa.GenerateKey(rand.Reader, 2048)
	v := &PushVerifier{Audience: "https://api.dashuri.app/v1/webhooks/google-play/rtdn", Email: "rtdn@proj.iam.gserviceaccount.com",
		Keyfunc: func(*jwt.Token) (any, error) { return &key.PublicKey, nil }}
	mk := func(k *rsa.PrivateKey, mut func(jwt.MapClaims)) string {
		c := jwt.MapClaims{"iss": "https://accounts.google.com", "aud": v.Audience, "email": v.Email, "email_verified": true,
			"exp": time.Now().Add(time.Hour).Unix(), "iat": time.Now().Unix()}
		if mut != nil {
			mut(c)
		}
		s, _ := jwt.NewWithClaims(jwt.SigningMethodRS256, c).SignedString(k)
		return "Bearer " + s
	}
	ctx := context.Background()
	if err := v.VerifyPush(ctx, mk(key, nil)); err != nil {
		t.Fatalf("valid token refused: %v", err)
	}
	bad := map[string]string{
		"other key":      mk(other, nil),
		"wrong audience": mk(key, func(c jwt.MapClaims) { c["aud"] = "https://evil" }),
		"wrong email":    mk(key, func(c jwt.MapClaims) { c["email"] = "x@evil.com" }),
		"unverified":     mk(key, func(c jwt.MapClaims) { c["email_verified"] = false }),
		"wrong issuer":   mk(key, func(c jwt.MapClaims) { c["iss"] = "https://evil" }),
		"expired":        mk(key, func(c jwt.MapClaims) { c["exp"] = time.Now().Add(-time.Hour).Unix() }),
		"no bearer":      strings.TrimPrefix(mk(key, nil), "Bearer "),
	}
	for name, h := range bad {
		if err := v.VerifyPush(ctx, h); err == nil {
			t.Errorf("%s accepted", name)
		}
	}
}
