package stream

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"dashuri/backend/internal/modules/calls"
	"dashuri/backend/internal/platform/apperr"
)

const secret = "test-secret-test-secret"

func decodeJWT(t *testing.T, tok string) map[string]any {
	t.Helper()
	parts := strings.Split(tok, ".")
	if len(parts) != 3 {
		t.Fatalf("not a JWT: %q", tok)
	}
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(parts[0] + "." + parts[1]))
	if base64.RawURLEncoding.EncodeToString(mac.Sum(nil)) != parts[2] {
		t.Fatal("bad HS256 signature")
	}
	var hdr, claims map[string]any
	h, _ := base64.RawURLEncoding.DecodeString(parts[0])
	_ = json.Unmarshal(h, &hdr)
	if hdr["alg"] != "HS256" {
		t.Fatalf("alg %v", hdr["alg"])
	}
	b, _ := base64.RawURLEncoding.DecodeString(parts[1])
	if err := json.Unmarshal(b, &claims); err != nil {
		t.Fatal(err)
	}
	return claims
}

func TestUserTokenScopedToOneCall(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	c := &Client{APIKey: "key", APISecret: secret, Now: func() time.Time { return now }}
	tok, exp, err := c.IssueToken(context.Background(), "user-1", "call-1", time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	cl := decodeJWT(t, tok)
	if cl["user_id"] != "user-1" || int64(cl["exp"].(float64)) != now.Add(time.Hour).Unix() || exp.Unix() != now.Add(time.Hour).Unix() {
		t.Fatalf("claims %v", cl)
	}
	cids := cl["call_cids"].([]any)
	if len(cids) != 1 || cids[0] != "default:call-1" {
		t.Fatalf("call_cids %v", cids)
	}
	if _, ok := cl["iat"]; !ok {
		t.Fatal("iat missing")
	}
}

func TestRESTCallsAreServerSigned(t *testing.T) {
	var mu sync.Mutex
	var paths []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()
		paths = append(paths, r.Method+" "+r.URL.Path)
		if r.URL.Query().Get("api_key") != "key" || r.Header.Get("Stream-Auth-Type") != "jwt" {
			w.WriteHeader(401)
			return
		}
		if cl := decodeJWT(t, r.Header.Get("Authorization")); cl["server"] != true {
			w.WriteHeader(401)
			return
		}
		body, _ := io.ReadAll(r.Body)
		if strings.HasSuffix(r.URL.Path, "/video/call/default/c1") {
			var b map[string]any
			_ = json.Unmarshal(body, &b)
			data := b["data"].(map[string]any)
			if len(data["members"].([]any)) != 2 || data["settings_override"] == nil {
				w.WriteHeader(400)
				return
			}
		}
		w.Write([]byte(`{}`))
	}))
	defer srv.Close()
	c := &Client{APIKey: "key", APISecret: secret, BaseURL: srv.URL}
	id, err := c.CreateCall(context.Background(), "c1", "a", "b")
	if err != nil || id != "c1" {
		t.Fatalf("create: %v %v", id, err)
	}
	if err := c.EndCall(context.Background(), "c1"); err != nil {
		t.Fatal(err)
	}
	want := []string{"POST /users", "POST /video/call/default/c1", "POST /video/call/default/c1/mark_ended"}
	if strings.Join(paths, ",") != strings.Join(want, ",") {
		t.Fatalf("paths %v", paths)
	}
}

func TestRESTErrorSurfaced(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(403)
		w.Write([]byte(`{"code":17,"message":"denied"}`))
	}))
	defer srv.Close()
	c := &Client{APIKey: "key", APISecret: secret, BaseURL: srv.URL}
	if _, err := c.CreateCall(context.Background(), "c1", "a", "b"); err == nil || !strings.Contains(err.Error(), "denied") {
		t.Fatalf("want error, got %v", err)
	}
}

func TestVerifyWebhook(t *testing.T) {
	c := &Client{APIKey: "key", APISecret: secret}
	body := []byte(`{"type":"call.session_participant_joined","created_at":"2026-11-21T10:00:00Z","call_cid":"default:3f1c7b1e-0000-4000-8000-000000000001","participant":{"user":{"id":"u1"}}}`)
	h := map[string]string{"X-Signature": Sign(secret, body), "X-Api-Key": "key", "X-Webhook-Id": "w-1"}
	evs, err := c.VerifyWebhook(body, h)
	if err != nil || len(evs) != 1 {
		t.Fatalf("%v %v", evs, err)
	}
	e := evs[0]
	if e.Kind != calls.EventJoined || e.UserID != "u1" || e.ProviderCallID != "3f1c7b1e-0000-4000-8000-000000000001" || !strings.HasPrefix(e.EventID, "sha256:") {
		t.Fatalf("event %+v", e)
	}

	// Tampered body, wrong secret, wrong api key, missing signature.
	cases := map[string]map[string]string{
		"tampered": {"X-Signature": Sign(secret, append(body, ' ')), "X-Api-Key": "key"},
		"secret":   {"X-Signature": Sign("other", body), "X-Api-Key": "key"},
		"api key":  {"X-Signature": Sign(secret, body), "X-Api-Key": "other"},
		"missing":  {"X-Api-Key": "key"},
	}
	for name, hh := range cases {
		if _, err := c.VerifyWebhook(body, hh); apperr.As(err) == nil || apperr.As(err).Code != "invalid_signature" {
			t.Errorf("%s: want invalid_signature, got %v", name, err)
		}
	}
}

func TestWebhookMapping(t *testing.T) {
	c := &Client{APIKey: "key", APISecret: secret}
	sign := func(b string) map[string]string { return map[string]string{"x-signature": Sign(secret, []byte(b))} }
	for _, tc := range []struct{ body, kind, user string }{
		{`{"type":"call.session_participant_left","call_cid":"default:x","participant":{"user":{"id":"u2"}}}`, calls.EventLeft, "u2"},
		{`{"type":"call.ended","call_cid":"default:x","user":{"id":"u2"}}`, calls.EventCallEnded, ""},
		{`{"type":"call.track_published","call_cid":"default:x","user":{"id":"u3"},"track_type":"TRACK_TYPE_VIDEO"}`, calls.EventVideoPublished, "u3"},
		{`{"type":"call.track_unpublished","call_cid":"default:x","participant":{"user":{"id":"u3"}},"track_type":"video"}`, calls.EventVideoUnpublished, "u3"},
	} {
		evs, err := c.VerifyWebhook([]byte(tc.body), sign(tc.body))
		if err != nil || len(evs) != 1 || evs[0].Kind != tc.kind || evs[0].UserID != tc.user || evs[0].ProviderCallID != "x" {
			t.Errorf("%s: %+v %v", tc.body, evs, err)
		}
		if !strings.HasPrefix(evs[0].EventID, "sha256:") {
			t.Errorf("body-hash event id expected, got %q", evs[0].EventID)
		}
	}
	for _, b := range []string{
		`{"type":"call.track_published","call_cid":"default:x","user":{"id":"u3"},"track_type":"audio"}`,
		`{"type":"call.reaction_new","call_cid":"default:x"}`,
		`{"type":"call.session_participant_joined","call_cid":"livestream:x","participant":{"user":{"id":"u"}}}`,
	} {
		if evs, err := c.VerifyWebhook([]byte(b), sign(b)); err != nil || len(evs) != 0 {
			t.Errorf("%s: want ignored, got %+v %v", b, evs, err)
		}
	}
}

func TestNotConfigured(t *testing.T) {
	p := New("", "", nil)
	_, err := p.CreateCall(context.Background(), "a", "b", "c")
	if e := apperr.As(err); e == nil || e.Code != "video_not_configured" || e.Kind != apperr.KindUnavailable {
		t.Fatalf("got %v", err)
	}
	if _, ok := New("k", "s", nil).(*Client); !ok {
		t.Fatal("configured provider expected")
	}
	if !errors.Is(err, err) {
		t.Fatal()
	}
}

// Stream may gzip the webhook body and sign the decompressed bytes.
func TestVerifyWebhookGzipBody(t *testing.T) {
	c := &Client{APIKey: "key", APISecret: secret}
	plain := []byte(`{"type":"call.session_participant_joined","created_at":"2026-11-21T10:00:00Z","call_cid":"default:3f1c7b1e-0000-4000-8000-000000000001","participant":{"user":{"id":"u1"}}}`)
	var buf bytes.Buffer
	zw := gzip.NewWriter(&buf)
	_, _ = zw.Write(plain)
	_ = zw.Close()

	evs, err := c.VerifyWebhook(buf.Bytes(), map[string]string{"X-Signature": Sign(secret, plain), "X-Api-Key": "key"})
	if err != nil || len(evs) != 1 || evs[0].UserID != "u1" {
		t.Fatalf("gzip body signed over plain bytes: %v %v", evs, err)
	}
	if _, err := c.VerifyWebhook(buf.Bytes(), map[string]string{"X-Signature": Sign("other", plain), "X-Api-Key": "key"}); err == nil {
		t.Fatal("wrong secret must still be rejected")
	}
}
