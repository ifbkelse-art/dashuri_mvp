package mux

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"dashuri/backend/internal/modules/reels"
)

func testKey(t *testing.T) (*rsa.PrivateKey, string) {
	t.Helper()
	k, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	pemBytes := pem.EncodeToMemory(&pem.Block{Type: "RSA PRIVATE KEY", Bytes: x509.MarshalPKCS1PrivateKey(k)})
	return k, base64.StdEncoding.EncodeToString(pemBytes)
}

func sig(secret string, ts int64, body []byte) string {
	m := hmac.New(sha256.New, []byte(secret))
	fmt.Fprintf(m, "%d.", ts)
	m.Write(body)
	return fmt.Sprintf("t=%d,v1=%s", ts, hex.EncodeToString(m.Sum(nil)))
}

func TestUnconfiguredWithoutCredentials(t *testing.T) {
	c, err := New("", "", "", "", "", nil)
	if err != nil || c.Configured() {
		t.Fatalf("empty config must be unconfigured without error: %v", err)
	}
	if _, err := c.CreateUpload(t.Context(), "x"); !errors.Is(err, reels.ErrProviderNotConfigured) {
		t.Fatalf("got %v", err)
	}
	if _, err := c.Playback("p", time.Minute); !errors.Is(err, reels.ErrProviderNotConfigured) {
		t.Fatalf("got %v", err)
	}
	if _, err := New("a", "b", "k", "not-a-key", "w", nil); err == nil {
		t.Fatal("bad key must be reported")
	}
}

func TestWebhookSignature(t *testing.T) {
	now := time.Unix(1_800_000_000, 0)
	body := []byte(`{"id":"evt1","type":"video.asset.ready","data":{"id":"as1","status":"ready","duration":21.5,"aspect_ratio":"9:16","passthrough":"vid","playback_ids":[{"id":"pb1","policy":"signed"}]}}`)
	good := sig("whsec", now.Unix(), body)
	if err := VerifySignature("whsec", good, body, now); err != nil {
		t.Fatalf("valid signature rejected: %v", err)
	}
	cases := map[string]struct {
		header string
		body   []byte
		at     time.Time
	}{
		"wrong secret": {sig("other", now.Unix(), body), body, now},
		"tampered":     {good, append([]byte(nil), append(body[:len(body)-1], ' ', '}')...), now},
		"stale":        {good, body, now.Add(6 * time.Minute)},
		"future":       {good, body, now.Add(-6 * time.Minute)},
		"missing":      {"", body, now},
		"garbage":      {"t=abc,v1=zz", body, now},
	}
	for name, c := range cases {
		if err := VerifySignature("whsec", c.header, c.body, c.at); !errors.Is(err, reels.ErrWebhookSignature) {
			t.Errorf("%s: want signature error, got %v", name, err)
		}
	}
	// Multiple v1 values (secret rotation) are accepted if one matches.
	rot := sig("whsec", now.Unix(), body) + ",v1=" + strings.Repeat("0", 64)
	if err := VerifySignature("whsec", rot, body, now); err != nil {
		t.Fatalf("rotation header rejected: %v", err)
	}
}

func TestParseWebhookEvents(t *testing.T) {
	_, key := testKey(t)
	c, _ := New("id", "secret", "kid1", key, "whsec", nil)
	now := time.Now()
	ready := []byte(`{"id":"evt1","type":"video.asset.ready","data":{"id":"as1","status":"ready","duration":21.5,"aspect_ratio":"9:16","passthrough":"vid","playback_ids":[{"id":"pub","policy":"public"},{"id":"pb1","policy":"signed"}]}}`)
	ev, err := c.ParseWebhook(map[string]string{"Mux-Signature": sig("whsec", now.Unix(), ready)}, ready, now)
	if err != nil {
		t.Fatal(err)
	}
	if ev.Type != "asset_ready" || ev.Asset.ID != "as1" || ev.Asset.DurationMs != 21500 || ev.Asset.PlaybackID != "pb1" || ev.Asset.Passthrough != "vid" {
		t.Fatalf("parsed %+v", ev)
	}
	up := []byte(`{"id":"evt2","type":"video.upload.asset_created","data":{"id":"up1","asset_id":"as1","status":"asset_created"}}`)
	ev, err = c.ParseWebhook(map[string]string{"mux-signature": sig("whsec", now.Unix(), up)}, up, now)
	if err != nil || ev.Type != "upload_asset_created" || ev.UploadID != "up1" || ev.Asset.ID != "as1" {
		t.Fatalf("upload event %+v %v", ev, err)
	}
	other := []byte(`{"id":"evt3","type":"video.asset.static_renditions.ready","data":{}}`)
	ev, err = c.ParseWebhook(map[string]string{"Mux-Signature": sig("whsec", now.Unix(), other)}, other, now)
	if err != nil || ev.Type != "ignored" {
		t.Fatalf("unknown events are ignored, got %+v %v", ev, err)
	}
	if _, err := c.ParseWebhook(map[string]string{}, ready, now); !errors.Is(err, reels.ErrWebhookSignature) {
		t.Fatal("unsigned webhook must be rejected")
	}
}

func TestSignedPlaybackTokens(t *testing.T) {
	k, key := testKey(t)
	c, err := New("id", "secret", "kid1", key, "whsec", nil)
	if err != nil || !c.Configured() {
		t.Fatalf("configured: %v", err)
	}
	pb, err := c.Playback("pb1", time.Hour)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(pb.HLSURL, "https://stream.mux.com/pb1.m3u8?token=") || !strings.HasPrefix(pb.ThumbnailURL, "https://image.mux.com/pb1/thumbnail.jpg?token=") {
		t.Fatalf("urls: %s %s", pb.HLSURL, pb.ThumbnailURL)
	}
	u, _ := url.Parse(pb.HLSURL)
	tok, err := jwt.Parse(u.Query().Get("token"), func(tk *jwt.Token) (any, error) {
		if tk.Header["kid"] != "kid1" {
			return nil, errors.New("kid")
		}
		return &k.PublicKey, nil
	}, jwt.WithValidMethods([]string{"RS256"}))
	if err != nil || !tok.Valid {
		t.Fatalf("token invalid: %v", err)
	}
	cl := tok.Claims.(jwt.MapClaims)
	if cl["sub"] != "pb1" || cl["aud"] != "v" {
		t.Fatalf("claims %v", cl)
	}
	frames, err := c.FrameURLs("pb1", 21500, 2*time.Second, time.Minute)
	if err != nil || len(frames) != 11 { // t = 0, 2, …, 20
		t.Fatalf("frames %d %v", len(frames), err)
	}
	if f, _ := c.FrameURLs("pb1", 0, 2*time.Second, time.Minute); len(f) != 1 {
		t.Fatal("at least one frame")
	}
}

func TestRESTCalls(t *testing.T) {
	_, key := testKey(t)
	var gotBody map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user, pass, _ := r.BasicAuth()
		if user != "id" || pass != "secret" {
			w.WriteHeader(401)
			return
		}
		switch {
		case r.Method == http.MethodPost && r.URL.Path == "/video/v1/uploads":
			_ = json.NewDecoder(r.Body).Decode(&gotBody)
			_, _ = w.Write([]byte(`{"data":{"id":"up1","url":"https://storage.example/up1","status":"waiting"}}`))
		case r.Method == http.MethodGet && r.URL.Path == "/video/v1/uploads/up1":
			_, _ = w.Write([]byte(`{"data":{"id":"up1","status":"asset_created","asset_id":"as1"}}`))
		case r.Method == http.MethodGet && r.URL.Path == "/video/v1/assets/as1":
			_, _ = w.Write([]byte(`{"data":{"id":"as1","status":"ready","duration":30.02,"playback_ids":[{"id":"pb1","policy":"signed"}]}}`))
		case r.Method == http.MethodDelete && r.URL.Path == "/video/v1/assets/as1":
			w.WriteHeader(204)
		default:
			w.WriteHeader(404)
			_, _ = w.Write([]byte(`{"error":{"type":"not_found","messages":["x"]}}`))
		}
	}))
	defer srv.Close()
	c, _ := New("id", "secret", "kid1", key, "whsec", srv.Client())
	c.APIBase = srv.URL
	up, err := c.CreateUpload(t.Context(), "video-1")
	if err != nil || up.UploadID != "up1" || up.URL == "" {
		t.Fatalf("upload %+v %v", up, err)
	}
	settings := gotBody["new_asset_settings"].(map[string]any)
	if settings["passthrough"] != "video-1" || settings["video_quality"] != "basic" ||
		settings["playback_policies"].([]any)[0] != "signed" {
		t.Fatalf("asset settings %v", settings)
	}
	st, err := c.UploadStatus(t.Context(), "up1")
	if err != nil || st.AssetID != "as1" || st.State != "asset_created" {
		t.Fatalf("status %+v %v", st, err)
	}
	a, err := c.Asset(t.Context(), "as1")
	if err != nil || a.DurationMs != 30020 || a.PlaybackID != "pb1" {
		t.Fatalf("asset %+v %v", a, err)
	}
	if err := c.DeleteAsset(t.Context(), "as1"); err != nil {
		t.Fatal(err)
	}
	if err := c.DeleteAsset(t.Context(), "gone"); !errors.Is(err, reels.ErrAssetNotFound) {
		t.Fatalf("missing asset: %v", err)
	}
	if _, err := c.Asset(t.Context(), "gone"); !errors.Is(err, reels.ErrAssetNotFound) {
		t.Fatalf("missing asset: %v", err)
	}
}
