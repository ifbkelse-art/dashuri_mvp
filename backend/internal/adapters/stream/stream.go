// Package stream implements calls.VideoProvider against the Stream Video
// server-side REST API (getstream.io, ADR-005 / founder decision F2).
//
//   - Server requests are authenticated with an HS256 JWT signed with the API
//     secret ({"server": true}), sent as the Authorization header together
//     with `Stream-Auth-Type: jwt` and the `api_key` query parameter.
//   - User tokens are HS256 JWTs with user_id, iat, exp and call_cids
//     restricted to the one call ("default:<call id>").
//   - Webhooks carry X-Signature = hex(HMAC-SHA256(raw body, API secret)) and
//     X-Api-Key; both are checked before any event is parsed.
//
// Only the standard library is used (no Stream SDK on the server).
package stream

import (
	"bytes"
	"compress/gzip"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"
	"time"

	"dashuri/backend/internal/modules/calls"
	"dashuri/backend/internal/platform/apperr"
)

// DefaultBaseURL is the Stream Video coordinator API root.
const DefaultBaseURL = "https://video.stream-io-api.com/api/v2"

// CallType is the Stream call type used for every Dashuri call.
const CallType = "default"

// Client is the Stream Video adapter.
type Client struct {
	APIKey    string
	APISecret string
	BaseURL   string // defaults to DefaultBaseURL (tests point it at httptest)
	HTTP      *http.Client
	Now       func() time.Time
}

var _ calls.VideoProvider = (*Client)(nil)

// New returns the Stream adapter, or a provider that refuses every call with
// 503 video_not_configured when the key or secret is missing.
func New(apiKey, apiSecret string, hc *http.Client) calls.VideoProvider {
	if apiKey == "" || apiSecret == "" {
		return NotConfigured{}
	}
	return &Client{APIKey: apiKey, APISecret: apiSecret, HTTP: hc}
}

// ProviderName is the {provider} path segment of the webhook URL.
func (c *Client) ProviderName() string { return "stream" }

// PublicAPIKey is handed to clients together with their call token.
func (c *Client) PublicAPIKey() string { return c.APIKey }

// CallCID is Stream's call identifier for one of our calls.
func CallCID(callID string) string { return CallType + ":" + callID }

func (c *Client) now() time.Time {
	if c.Now != nil {
		return c.Now()
	}
	return time.Now()
}

// ---------------------------------------------------------------- tokens

// SignHS256 builds a compact JWT signed with HMAC-SHA256.
func SignHS256(secret string, claims map[string]any) (string, error) {
	header := base64.RawURLEncoding.EncodeToString([]byte(`{"alg":"HS256","typ":"JWT"}`))
	body, err := json.Marshal(claims)
	if err != nil {
		return "", err
	}
	signing := header + "." + base64.RawURLEncoding.EncodeToString(body)
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(signing))
	return signing + "." + base64.RawURLEncoding.EncodeToString(mac.Sum(nil)), nil
}

// ServerToken is the token for server-side REST calls.
func (c *Client) ServerToken() (string, error) {
	return SignHS256(c.APISecret, map[string]any{"server": true, "iat": c.now().Add(-5 * time.Second).Unix()})
}

// IssueToken mints a user token that can join only this call.
func (c *Client) IssueToken(_ context.Context, userID, providerCallID string, ttl time.Duration) (string, time.Time, error) {
	if userID == "" || providerCallID == "" {
		return "", time.Time{}, errors.New("stream: user and call required")
	}
	now := c.now()
	exp := now.Add(ttl).Truncate(time.Second)
	tok, err := SignHS256(c.APISecret, map[string]any{
		"user_id":   userID,
		"iat":       now.Add(-5 * time.Second).Unix(), // tolerate small clock skew at Stream
		"exp":       exp.Unix(),
		"call_cids": []string{CallCID(providerCallID)},
	})
	return tok, exp.UTC(), err
}

// ---------------------------------------------------------------- REST

func (c *Client) do(ctx context.Context, method, path string, body any) error {
	tok, err := c.ServerToken()
	if err != nil {
		return err
	}
	base := c.BaseURL
	if base == "" {
		base = DefaultBaseURL
	}
	var rd io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return err
		}
		rd = bytes.NewReader(b)
	}
	u := strings.TrimRight(base, "/") + path + "?api_key=" + url.QueryEscape(c.APIKey)
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, method, u, rd)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", tok)
	req.Header.Set("Stream-Auth-Type", "jwt")
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Stream-Client", "dashuri-backend")
	hc := c.HTTP
	if hc == nil {
		hc = http.DefaultClient
	}
	res, err := hc.Do(req)
	if err != nil {
		return fmt.Errorf("stream: %s %s: %w", method, path, err)
	}
	defer res.Body.Close()
	if res.StatusCode >= 300 {
		var e struct {
			Code    int    `json:"code"`
			Message string `json:"message"`
		}
		_ = json.NewDecoder(io.LimitReader(res.Body, 64<<10)).Decode(&e)
		return fmt.Errorf("stream: %s %s: status %d code %d: %s", method, path, res.StatusCode, e.Code, e.Message)
	}
	_, _ = io.Copy(io.Discard, io.LimitReader(res.Body, 1<<20))
	return nil
}

// UpsertUsers registers the users with Stream (POST /users).
func (c *Client) UpsertUsers(ctx context.Context, ids ...string) error {
	users := map[string]any{}
	for _, id := range ids {
		users[id] = map[string]any{"id": id, "role": "user"}
	}
	return c.do(ctx, http.MethodPost, "/users", map[string]any{"users": users})
}

// CreateCall upserts both users, then get-or-creates the call
// default:<callID> with exactly these two members, at most two participants
// and no Stream-side ringing (Dashuri rings through its own Realtime).
func (c *Client) CreateCall(ctx context.Context, callID, callerID, receiverID string) (string, error) {
	if err := c.UpsertUsers(ctx, callerID, receiverID); err != nil {
		return "", err
	}
	body := map[string]any{
		"ring":   false,
		"notify": false,
		"data": map[string]any{
			"created_by_id": callerID,
			"members": []map[string]any{
				{"user_id": callerID, "role": "user"},
				{"user_id": receiverID, "role": "user"},
			},
			"settings_override": map[string]any{
				"limits": map[string]any{"max_participants": 2},
				// Explicit target resolution: Stream validates the call type's stored
				// value (>= 240) and rejects the request when the type has none.
				"video": map[string]any{
					"enabled":           true,
					"camera_default_on": true,
					// Required by the client SDK's response parser; the call type
					// in a fresh Stream app can carry none.
					"camera_facing":          "front",
					"access_request_enabled": false,
					"target_resolution":      map[string]any{"width": 1280, "height": 720, "bitrate": 1500000},
				},
				"audio": map[string]any{"default_device": "speaker"},
			},
		},
	}
	if err := c.do(ctx, http.MethodPost, "/video/call/"+CallType+"/"+url.PathEscape(callID), body); err != nil {
		return "", err
	}
	return callID, nil
}

// EndCall marks the call ended for everyone (POST …/mark_ended).
func (c *Client) EndCall(ctx context.Context, providerCallID string) error {
	return c.do(ctx, http.MethodPost, "/video/call/"+CallType+"/"+url.PathEscape(providerCallID)+"/mark_ended", map[string]any{})
}

// ---------------------------------------------------------------- webhooks

// ErrInvalidSignature is returned for an unauthenticated webhook.
var ErrInvalidSignature = &apperr.Error{Kind: apperr.KindUnauthenticated, Code: "invalid_signature", Detail: "webhook signature invalid"}

func header(h map[string]string, name string) string {
	for k, v := range h {
		if strings.EqualFold(k, name) {
			return v
		}
	}
	return ""
}

// Sign returns the X-Signature value for a body (exported for tests).
func Sign(secret string, raw []byte) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(raw)
	return hex.EncodeToString(mac.Sum(nil))
}

type webhookUser struct {
	ID string `json:"id"`
}

type webhookBody struct {
	Type        string    `json:"type"`
	CreatedAt   time.Time `json:"created_at"`
	CallCID     string    `json:"call_cid"`
	Participant *struct {
		User     webhookUser `json:"user"`
		JoinedAt *time.Time  `json:"joined_at"`
	} `json:"participant"`
	User      *webhookUser `json:"user"`
	TrackType string       `json:"track_type"`
	Call      *struct {
		CID string `json:"cid"`
		ID  string `json:"id"`
	} `json:"call"`
}

// gunzip returns the decompressed bytes when b is a gzip stream (capped at 1 MiB).
func gunzip(b []byte) ([]byte, bool) {
	if len(b) < 2 || b[0] != 0x1f || b[1] != 0x8b {
		return nil, false
	}
	zr, err := gzip.NewReader(bytes.NewReader(b))
	if err != nil {
		return nil, false
	}
	defer zr.Close()
	out, err := io.ReadAll(io.LimitReader(zr, 1<<20))
	return out, err == nil
}

// VerifyWebhook checks X-Api-Key and X-Signature (constant time) over the raw
// body, then maps the event. Unknown event types return no events (the
// handler answers 204 so Stream does not retry them).
func (c *Client) VerifyWebhook(raw []byte, headers map[string]string) ([]calls.ProviderEvent, error) {
	if key := header(headers, "X-Api-Key"); key != "" && key != c.APIKey {
		return nil, ErrInvalidSignature
	}
	got, err := hex.DecodeString(strings.TrimSpace(header(headers, "X-Signature")))
	if err != nil || len(got) == 0 {
		return nil, ErrInvalidSignature
	}
	sign := func(b []byte) []byte {
		mac := hmac.New(sha256.New, []byte(c.APISecret))
		mac.Write(b)
		return mac.Sum(nil)
	}
	if !hmac.Equal(got, sign(raw)) {
		// Stream may gzip the body; accept a signature over the decompressed
		// bytes too (same secret, so no weaker than the raw check).
		plain, ok := gunzip(raw)
		if !ok || !hmac.Equal(got, sign(plain)) {
			slog.Warn("stream webhook signature mismatch",
				"content_encoding", header(headers, "Content-Encoding"), "bytes", len(raw), "gzip", ok)
			return nil, ErrInvalidSignature
		}
		raw = plain
	}
	var b webhookBody
	if err := json.Unmarshal(raw, &b); err != nil {
		return nil, apperr.Validation(map[string]string{"body": "invalid_json"})
	}
	return mapEvent(b, raw, header(headers, "X-Webhook-Id")), nil
}

func mapEvent(b webhookBody, raw []byte, webhookID string) []calls.ProviderEvent {
	cid := b.CallCID
	if cid == "" && b.Call != nil {
		cid = b.Call.CID
	}
	typ, id, ok := strings.Cut(cid, ":")
	if !ok || typ != CallType || id == "" {
		return nil
	}
	user := ""
	if b.Participant != nil {
		user = b.Participant.User.ID
	}
	if user == "" && b.User != nil {
		user = b.User.ID
	}
	video := strings.Contains(strings.ToLower(b.TrackType), "video")
	var kind string
	switch b.Type {
	case "call.session_participant_joined":
		kind = calls.EventJoined
	case "call.session_participant_left":
		kind = calls.EventLeft
	case "call.ended", "call.session_ended":
		kind, user = calls.EventCallEnded, ""
	case "call.track_published":
		if !video {
			return nil
		}
		kind = calls.EventVideoPublished
	case "call.track_unpublished":
		if !video {
			return nil
		}
		kind = calls.EventVideoUnpublished
	default:
		return nil
	}
	if kind != calls.EventCallEnded && user == "" {
		return nil
	}
	at := b.CreatedAt
	if at.IsZero() {
		at = time.Now()
	}
	// Dedupe on the HMAC-signed body: X-Webhook-Id is not covered by the
	// signature, so a replayed body with a new header must still collide.
	_ = webhookID
	sum := sha256.Sum256(raw)
	eventID := "sha256:" + hex.EncodeToString(sum[:])
	return []calls.ProviderEvent{{EventID: eventID, ProviderCallID: id, UserID: user, Kind: kind, At: at.UTC()}}
}

// ---------------------------------------------------------------- not configured

// NotConfigured refuses every operation: STREAM_API_KEY or STREAM_API_SECRET is empty.
type NotConfigured struct{}

var errNotConfigured = apperr.Unavailable("video_not_configured", "video calls are not configured on this server")

func (NotConfigured) CreateCall(context.Context, string, string, string) (string, error) {
	return "", errNotConfigured
}
func (NotConfigured) IssueToken(context.Context, string, string, time.Duration) (string, time.Time, error) {
	return "", time.Time{}, errNotConfigured
}
func (NotConfigured) EndCall(context.Context, string) error { return errNotConfigured }
func (NotConfigured) VerifyWebhook([]byte, map[string]string) ([]calls.ProviderEvent, error) {
	return nil, errNotConfigured
}
func (NotConfigured) PublicAPIKey() string { return "" }
