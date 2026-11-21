package fcm

import (
	"context"
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/golang-jwt/jwt/v5"

	"dashuri/backend/internal/modules/notifications"
)

func writeCreds(t *testing.T, tokenURL string) (string, *rsa.PrivateKey) {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	pemKey := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: must(x509.MarshalPKCS8PrivateKey(key))})
	b, _ := json.Marshal(map[string]string{
		"type": "service_account", "client_email": "push@test.iam.gserviceaccount.com",
		"private_key": string(pemKey), "token_uri": tokenURL, "project_id": "dashuri-test",
	})
	p := filepath.Join(t.TempDir(), "sa.json")
	if err := os.WriteFile(p, b, 0o600); err != nil {
		t.Fatal(err)
	}
	return p, key
}

func must[T any](v T, err error) T {
	if err != nil {
		panic(err)
	}
	return v
}

func TestSendFlow(t *testing.T) {
	var tokenCalls, sendCalls atomic.Int32
	var key *rsa.PrivateKey
	var lastMsg map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch {
		case r.URL.Path == "/token":
			tokenCalls.Add(1)
			b, _ := io.ReadAll(r.Body)
			form, _ := url.ParseQuery(string(b))
			if form.Get("grant_type") != "urn:ietf:params:oauth:grant-type:jwt-bearer" {
				t.Errorf("grant_type %q", form.Get("grant_type"))
			}
			claims := jwt.MapClaims{}
			if _, err := jwt.ParseWithClaims(form.Get("assertion"), claims, func(*jwt.Token) (any, error) { return &key.PublicKey, nil }); err != nil {
				t.Errorf("assertion: %v", err)
			}
			if claims["scope"] != scope || claims["iss"] != "push@test.iam.gserviceaccount.com" {
				t.Errorf("claims %v", claims)
			}
			_, _ = w.Write([]byte(`{"access_token":"at-1","expires_in":3600,"token_type":"Bearer"}`))
		case r.URL.Path == "/v1/projects/dashuri-test/messages:send":
			sendCalls.Add(1)
			if r.Header.Get("Authorization") != "Bearer at-1" {
				t.Errorf("auth %q", r.Header.Get("Authorization"))
			}
			var body map[string]map[string]any
			_ = json.NewDecoder(r.Body).Decode(&body)
			lastMsg = body["message"]
			if lastMsg["token"] == "gone" {
				w.WriteHeader(http.StatusNotFound)
				_, _ = w.Write([]byte(`{"error":{"code":404,"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}`))
				return
			}
			_, _ = w.Write([]byte(`{"name":"projects/dashuri-test/messages/1"}`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()
	path, k := writeCreds(t, srv.URL+"/token")
	key = k
	c := &Client{CredentialsFile: path, Endpoint: srv.URL, HTTP: srv.Client()}

	ctx := context.Background()
	if err := c.Send(ctx, "tok-1", notifications.Push{Kind: "message", Title: "New message", Data: map[string]string{"conversation_id": "c1"}}); err != nil {
		t.Fatal(err)
	}
	if lastMsg["notification"] == nil || lastMsg["data"].(map[string]any)["conversation_id"] != "c1" {
		t.Fatalf("message %v", lastMsg)
	}
	if err := c.Send(ctx, "tok-2", notifications.Push{Kind: "incoming_call", Title: "x", Data: map[string]string{"call_id": "k"}}); err != nil {
		t.Fatal(err)
	}
	if lastMsg["notification"] != nil || lastMsg["android"].(map[string]any)["priority"] != "high" {
		t.Fatalf("incoming call must be data-only high priority: %v", lastMsg)
	}
	if err := c.Send(ctx, "gone", notifications.Push{Kind: "message"}); !errors.Is(err, notifications.ErrTokenUnregistered) {
		t.Fatalf("want unregistered, got %v", err)
	}
	if tokenCalls.Load() != 1 || sendCalls.Load() != 3 {
		t.Fatalf("token calls %d (want cached: 1), sends %d", tokenCalls.Load(), sendCalls.Load())
	}
}

func TestNotConfigured(t *testing.T) {
	s := New("", "", nil)
	if _, ok := s.(Disabled); !ok {
		t.Fatalf("got %T", s)
	}
	if err := s.Send(context.Background(), "t", notifications.Push{Kind: "x"}); err != nil {
		t.Fatal(err)
	}
	c := &Client{CredentialsFile: filepath.Join(t.TempDir(), "missing.json")}
	if err := c.Send(context.Background(), "t", notifications.Push{}); err == nil || !strings.Contains(err.Error(), "credentials") {
		t.Fatalf("got %v", err)
	}
}
