// Package mux implements reels.VideoProvider with Mux Video (EXPERIMENT).
//
// API used (https://www.mux.com/docs):
//   - POST   /video/v1/uploads          direct upload (signed playback policy, basic quality)
//   - GET    /video/v1/uploads/{id}     upload status → asset id
//   - GET    /video/v1/assets/{id}      asset status, duration, playback ids
//   - DELETE /video/v1/assets/{id}
//   - Webhooks signed with header `Mux-Signature: t=<unix>,v1=<hex hmac-sha256(secret, t + "." + body)>`
//   - Signed playback: RS256 JWT with the signing key id as `kid`, `sub` =
//     playback id, `aud` = v (video) or t (thumbnail); thumbnail options are
//     claims inside the token.
//
// Without MUX_TOKEN_ID/SECRET, signing key and webhook secret, Configured()
// is false and the module answers 503 video_provider_not_configured.
package mux

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"dashuri/backend/internal/modules/reels"
)

const (
	DefaultAPIBase   = "https://api.mux.com"
	StreamBase       = "https://stream.mux.com"
	ImageBase        = "https://image.mux.com"
	WebhookTolerance = 5 * time.Minute
	UploadTimeout    = 2 * time.Hour
)

// Client is the Mux adapter.
type Client struct {
	TokenID       string
	TokenSecret   string
	SigningKeyID  string
	SigningKey    *rsa.PrivateKey
	WebhookSecret string
	CORSOrigin    string // "*" for mobile apps (no browser origin)
	APIBase       string
	HTTP          *http.Client
}

var _ reels.VideoProvider = (*Client)(nil)

// New builds the adapter. signingKeyB64 is the base64-encoded PEM private key
// Mux returns when a signing key is created. A bad key leaves the client
// unconfigured (and is reported by the returned error).
func New(tokenID, tokenSecret, signingKeyID, signingKeyB64, webhookSecret string, hc *http.Client) (*Client, error) {
	c := &Client{TokenID: tokenID, TokenSecret: tokenSecret, SigningKeyID: signingKeyID, WebhookSecret: webhookSecret,
		CORSOrigin: "*", APIBase: DefaultAPIBase, HTTP: hc}
	if signingKeyB64 == "" {
		return c, nil
	}
	pemBytes, err := base64.StdEncoding.DecodeString(strings.TrimSpace(signingKeyB64))
	if err != nil {
		pemBytes = []byte(signingKeyB64) // raw PEM is accepted too
	}
	key, err := jwt.ParseRSAPrivateKeyFromPEM(pemBytes)
	if err != nil {
		return c, fmt.Errorf("mux: signing key: %w", err)
	}
	c.SigningKey = key
	return c, nil
}

func (c *Client) Name() string { return "mux" }

func (c *Client) Configured() bool {
	return c != nil && c.TokenID != "" && c.TokenSecret != "" && c.SigningKeyID != "" && c.SigningKey != nil && c.WebhookSecret != ""
}

// ---------------------------------------------------------------- REST

type apiError struct {
	Error struct {
		Type     string   `json:"type"`
		Messages []string `json:"messages"`
	} `json:"error"`
}

func (c *Client) do(ctx context.Context, method, path string, body, out any) (int, error) {
	if !c.Configured() {
		return 0, reels.ErrProviderNotConfigured
	}
	var rd io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return 0, err
		}
		rd = bytes.NewReader(b)
	}
	ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, method, strings.TrimRight(c.APIBase, "/")+path, rd)
	if err != nil {
		return 0, err
	}
	req.SetBasicAuth(c.TokenID, c.TokenSecret)
	req.Header.Set("Accept", "application/json")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	hc := c.HTTP
	if hc == nil {
		hc = http.DefaultClient
	}
	res, err := hc.Do(req)
	if err != nil {
		return 0, fmt.Errorf("mux: %w", err)
	}
	defer res.Body.Close()
	data, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if err != nil {
		return res.StatusCode, err
	}
	if res.StatusCode >= 300 {
		var e apiError
		_ = json.Unmarshal(data, &e)
		return res.StatusCode, fmt.Errorf("mux: status %d (%s)", res.StatusCode, e.Error.Type)
	}
	if out != nil && len(data) > 0 {
		return res.StatusCode, json.Unmarshal(data, out)
	}
	return res.StatusCode, nil
}

type uploadObj struct {
	ID      string `json:"id"`
	URL     string `json:"url"`
	Status  string `json:"status"`
	AssetID string `json:"asset_id"`
	Timeout int    `json:"timeout"`
}

type playbackID struct {
	ID     string `json:"id"`
	Policy string `json:"policy"`
}

type assetObj struct {
	ID          string       `json:"id"`
	Status      string       `json:"status"`
	Duration    float64      `json:"duration"`
	AspectRatio string       `json:"aspect_ratio"`
	PlaybackIDs []playbackID `json:"playback_ids"`
	Passthrough string       `json:"passthrough"`
}

func (a assetObj) info() reels.AssetInfo {
	out := reels.AssetInfo{ID: a.ID, State: a.Status, DurationMs: int(math.Round(a.Duration * 1000)),
		AspectRatio: a.AspectRatio, Passthrough: a.Passthrough}
	for _, p := range a.PlaybackIDs {
		if p.Policy == "signed" {
			out.PlaybackID = p.ID
			break
		}
	}
	return out
}

func (c *Client) CreateUpload(ctx context.Context, passthrough string) (reels.UploadSession, error) {
	body := map[string]any{
		"cors_origin": c.CORSOrigin,
		"timeout":     int(UploadTimeout.Seconds()),
		"new_asset_settings": map[string]any{
			"playback_policies": []string{"signed"}, // never public: every URL needs our token
			"video_quality":     "basic",            // free encoding tier
			"passthrough":       passthrough,
		},
	}
	var out struct {
		Data uploadObj `json:"data"`
	}
	if _, err := c.do(ctx, http.MethodPost, "/video/v1/uploads", body, &out); err != nil {
		return reels.UploadSession{}, err
	}
	if out.Data.ID == "" || out.Data.URL == "" {
		return reels.UploadSession{}, errors.New("mux: upload response missing id or url")
	}
	return reels.UploadSession{UploadID: out.Data.ID, URL: out.Data.URL, ExpiresAt: time.Now().Add(UploadTimeout)}, nil
}

func (c *Client) UploadStatus(ctx context.Context, uploadID string) (reels.UploadState, error) {
	var out struct {
		Data uploadObj `json:"data"`
	}
	if _, err := c.do(ctx, http.MethodGet, "/video/v1/uploads/"+uploadID, nil, &out); err != nil {
		return reels.UploadState{}, err
	}
	return reels.UploadState{State: out.Data.Status, AssetID: out.Data.AssetID}, nil
}

func (c *Client) Asset(ctx context.Context, assetID string) (reels.AssetInfo, error) {
	var out struct {
		Data assetObj `json:"data"`
	}
	status, err := c.do(ctx, http.MethodGet, "/video/v1/assets/"+assetID, nil, &out)
	if status == http.StatusNotFound {
		return reels.AssetInfo{}, reels.ErrAssetNotFound
	}
	if err != nil {
		return reels.AssetInfo{}, err
	}
	return out.Data.info(), nil
}

func (c *Client) DeleteAsset(ctx context.Context, assetID string) error {
	status, err := c.do(ctx, http.MethodDelete, "/video/v1/assets/"+assetID, nil, nil)
	if status == http.StatusNotFound {
		return reels.ErrAssetNotFound
	}
	return err
}

// ---------------------------------------------------------------- signed playback

func (c *Client) sign(playbackID, aud string, ttl time.Duration, extra map[string]any) (string, time.Time, error) {
	if !c.Configured() {
		return "", time.Time{}, reels.ErrProviderNotConfigured
	}
	exp := time.Now().Add(ttl)
	claims := jwt.MapClaims{"sub": playbackID, "aud": aud, "exp": exp.Unix()}
	for k, v := range extra {
		claims[k] = v
	}
	t := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	t.Header["kid"] = c.SigningKeyID
	s, err := t.SignedString(c.SigningKey)
	return s, exp, err
}

func (c *Client) Playback(playbackID string, ttl time.Duration) (reels.Playback, error) {
	vt, exp, err := c.sign(playbackID, "v", ttl, nil)
	if err != nil {
		return reels.Playback{}, err
	}
	tt, _, err := c.sign(playbackID, "t", ttl, map[string]any{"width": 720, "fit_mode": "preserve"})
	if err != nil {
		return reels.Playback{}, err
	}
	return reels.Playback{
		HLSURL:       StreamBase + "/" + playbackID + ".m3u8?token=" + vt,
		ThumbnailURL: ImageBase + "/" + playbackID + "/thumbnail.jpg?token=" + tt,
		ExpiresAt:    exp,
	}, nil
}

// FrameURLs returns a signed still every interval (t = 0, interval, …, < duration),
// at least one frame, at most 120.
func (c *Client) FrameURLs(playbackID string, durationMs int, interval, ttl time.Duration) ([]string, error) {
	if interval <= 0 {
		interval = 2 * time.Second
	}
	var out []string
	for t := time.Duration(0); t < time.Duration(durationMs)*time.Millisecond && len(out) < 120; t += interval {
		tok, _, err := c.sign(playbackID, "t", ttl, map[string]any{"time": t.Seconds(), "width": 640})
		if err != nil {
			return nil, err
		}
		out = append(out, ImageBase+"/"+playbackID+"/thumbnail.jpg?token="+tok)
	}
	if len(out) == 0 {
		tok, _, err := c.sign(playbackID, "t", ttl, map[string]any{"time": 0, "width": 640})
		if err != nil {
			return nil, err
		}
		out = append(out, ImageBase+"/"+playbackID+"/thumbnail.jpg?token="+tok)
	}
	return out, nil
}

// ---------------------------------------------------------------- webhooks

// VerifySignature checks `Mux-Signature` over the raw body.
func VerifySignature(secret, header string, body []byte, now time.Time) error {
	if secret == "" || header == "" {
		return reels.ErrWebhookSignature
	}
	var ts string
	var sigs []string
	for _, part := range strings.Split(header, ",") {
		k, v, ok := strings.Cut(strings.TrimSpace(part), "=")
		if !ok {
			continue
		}
		switch k {
		case "t":
			ts = v
		case "v1":
			sigs = append(sigs, v)
		}
	}
	sec, err := strconv.ParseInt(ts, 10, 64)
	if err != nil || len(sigs) == 0 {
		return reels.ErrWebhookSignature
	}
	if d := now.Sub(time.Unix(sec, 0)); d > WebhookTolerance || d < -WebhookTolerance {
		return reels.ErrWebhookSignature
	}
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(ts + "."))
	mac.Write(body)
	want := mac.Sum(nil)
	for _, s := range sigs {
		got, err := hex.DecodeString(s)
		if err == nil && hmac.Equal(got, want) {
			return nil
		}
	}
	return reels.ErrWebhookSignature
}

func header(h map[string]string, name string) string {
	for k, v := range h {
		if strings.EqualFold(k, name) {
			return v
		}
	}
	return ""
}

func (c *Client) ParseWebhook(headers map[string]string, body []byte, now time.Time) (reels.WebhookEvent, error) {
	if err := VerifySignature(c.WebhookSecret, header(headers, "Mux-Signature"), body, now); err != nil {
		return reels.WebhookEvent{}, err
	}
	var env struct {
		ID   string          `json:"id"`
		Type string          `json:"type"`
		Data json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(body, &env); err != nil {
		return reels.WebhookEvent{}, fmt.Errorf("mux: webhook decode: %w", err)
	}
	ev := reels.WebhookEvent{DeliveryID: env.ID, RawType: env.Type, Type: "ignored"}
	switch env.Type {
	case "video.upload.asset_created", "video.upload.errored", "video.upload.cancelled":
		var u uploadObj
		if err := json.Unmarshal(env.Data, &u); err != nil {
			return ev, err
		}
		ev.UploadID = u.ID
		ev.Asset.ID = u.AssetID
		ev.Type = "upload_asset_created"
		if env.Type != "video.upload.asset_created" {
			ev.Type = "upload_failed"
		}
	case "video.asset.ready", "video.asset.errored":
		var a assetObj
		if err := json.Unmarshal(env.Data, &a); err != nil {
			return ev, err
		}
		ev.Asset = a.info()
		ev.Type = "asset_ready"
		if env.Type == "video.asset.errored" {
			ev.Type = "asset_errored"
		}
	}
	return ev, nil
}
