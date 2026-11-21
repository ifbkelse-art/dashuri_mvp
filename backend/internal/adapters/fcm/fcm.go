// Package fcm sends push notifications through Firebase Cloud Messaging
// HTTP v1 (https://firebase.google.com/docs/cloud-messaging/send/v1-api),
// authenticating with a Google service account (OAuth 2.0 JWT bearer
// grant, RFC 7523) read from GOOGLE_APPLICATION_CREDENTIALS. Standard
// library plus golang-jwt only.
package fcm

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"dashuri/backend/internal/modules/notifications"
)

const (
	scope           = "https://www.googleapis.com/auth/firebase.messaging"
	defaultTokenURL = "https://oauth2.googleapis.com/token"
	defaultEndpoint = "https://fcm.googleapis.com"
)

// New returns a PushSender. Without a credentials file it returns Disabled,
// which logs at debug level and skips the push.
func New(projectID, credentialsFile string, client *http.Client) notifications.PushSender {
	if credentialsFile == "" {
		return Disabled{}
	}
	return &Client{ProjectID: projectID, CredentialsFile: credentialsFile, HTTP: client}
}

// Disabled is the PushSender used when FCM is not configured.
type Disabled struct{}

func (Disabled) Send(ctx context.Context, _ string, msg notifications.Push) error {
	slog.DebugContext(ctx, "push not configured; skipped", "kind", msg.Kind)
	return nil
}

// Client is the FCM HTTP v1 sender.
type Client struct {
	ProjectID       string // FCM_PROJECT_ID; defaults to the service account's project_id
	CredentialsFile string
	HTTP            *http.Client
	Endpoint        string           // tests; default https://fcm.googleapis.com
	Now             func() time.Time // tests

	mu      sync.Mutex
	account *serviceAccount
	token   string
	expiry  time.Time
}

type serviceAccount struct {
	ClientEmail  string `json:"client_email"`
	PrivateKey   string `json:"private_key"`
	PrivateKeyID string `json:"private_key_id"`
	TokenURI     string `json:"token_uri"`
	ProjectID    string `json:"project_id"`
}

func (c *Client) now() time.Time {
	if c.Now != nil {
		return c.Now()
	}
	return time.Now()
}

func (c *Client) httpClient() *http.Client {
	if c.HTTP != nil {
		return c.HTTP
	}
	return http.DefaultClient
}

func (c *Client) loadAccount() (*serviceAccount, error) {
	if c.account != nil {
		return c.account, nil
	}
	b, err := os.ReadFile(c.CredentialsFile)
	if err != nil {
		return nil, fmt.Errorf("fcm: read credentials: %w", err)
	}
	var sa serviceAccount
	if err := json.Unmarshal(b, &sa); err != nil {
		return nil, fmt.Errorf("fcm: parse credentials: %w", err)
	}
	if sa.ClientEmail == "" || sa.PrivateKey == "" {
		return nil, errors.New("fcm: credentials file is not a service account key")
	}
	if sa.TokenURI == "" {
		sa.TokenURI = defaultTokenURL
	}
	c.account = &sa
	return c.account, nil
}

// accessToken returns a cached OAuth token, refreshing 60 s before expiry.
func (c *Client) accessToken(ctx context.Context, force bool) (string, string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	sa, err := c.loadAccount()
	if err != nil {
		return "", "", err
	}
	project := c.ProjectID
	if project == "" {
		project = sa.ProjectID
	}
	if project == "" {
		return "", "", errors.New("fcm: FCM_PROJECT_ID not set and missing from credentials")
	}
	if !force && c.token != "" && c.now().Before(c.expiry.Add(-60*time.Second)) {
		return c.token, project, nil
	}
	key, err := jwt.ParseRSAPrivateKeyFromPEM([]byte(sa.PrivateKey))
	if err != nil {
		return "", "", fmt.Errorf("fcm: private key: %w", err)
	}
	now := c.now()
	tok := jwt.NewWithClaims(jwt.SigningMethodRS256, jwt.MapClaims{
		"iss": sa.ClientEmail, "scope": scope, "aud": sa.TokenURI,
		"iat": now.Unix(), "exp": now.Add(time.Hour).Unix(),
	})
	if sa.PrivateKeyID != "" {
		tok.Header["kid"] = sa.PrivateKeyID
	}
	assertion, err := tok.SignedString(key)
	if err != nil {
		return "", "", fmt.Errorf("fcm: sign assertion: %w", err)
	}
	form := url.Values{"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"}, "assertion": {assertion}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, sa.TokenURI, strings.NewReader(form.Encode()))
	if err != nil {
		return "", "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	res, err := c.httpClient().Do(req)
	if err != nil {
		return "", "", fmt.Errorf("fcm: token request: %w", err)
	}
	defer res.Body.Close()
	var out struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int64  `json:"expires_in"`
	}
	body, _ := io.ReadAll(io.LimitReader(res.Body, 64<<10))
	if res.StatusCode != http.StatusOK {
		return "", "", fmt.Errorf("fcm: token endpoint status %d", res.StatusCode)
	}
	if err := json.Unmarshal(body, &out); err != nil || out.AccessToken == "" {
		return "", "", errors.New("fcm: invalid token response")
	}
	c.token, c.expiry = out.AccessToken, now.Add(time.Duration(out.ExpiresIn)*time.Second)
	return c.token, project, nil
}

type message struct {
	Token        string            `json:"token"`
	Notification *notification     `json:"notification,omitempty"`
	Data         map[string]string `json:"data,omitempty"`
	Android      androidConfig     `json:"android"`
}

type notification struct {
	Title string `json:"title,omitempty"`
	Body  string `json:"body,omitempty"`
}

type androidConfig struct {
	Priority string `json:"priority"`
	TTL      string `json:"ttl,omitempty"`
}

// Send delivers one message. An UNREGISTERED / NOT_FOUND token returns
// notifications.ErrTokenUnregistered so the caller forgets the device.
func (c *Client) Send(ctx context.Context, token string, msg notifications.Push) error {
	m := message{Token: token, Data: msg.Data, Android: androidConfig{Priority: "normal"}}
	if msg.Title != "" || msg.Body != "" {
		m.Notification = &notification{Title: msg.Title, Body: msg.Body}
	}
	if msg.Kind == "incoming_call" {
		// Data-only, high priority, short-lived: the app shows the ring UI.
		m.Notification, m.Android = nil, androidConfig{Priority: "high", TTL: "30s"}
	}
	body, err := json.Marshal(map[string]any{"message": m})
	if err != nil {
		return err
	}
	for attempt := 0; attempt < 2; attempt++ {
		access, project, err := c.accessToken(ctx, attempt > 0)
		if err != nil {
			return err
		}
		endpoint := c.Endpoint
		if endpoint == "" {
			endpoint = defaultEndpoint
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost,
			strings.TrimRight(endpoint, "/")+"/v1/projects/"+url.PathEscape(project)+"/messages:send", bytes.NewReader(body))
		if err != nil {
			return err
		}
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", "Bearer "+access)
		res, err := c.httpClient().Do(req)
		if err != nil {
			return fmt.Errorf("fcm: send: %w", err)
		}
		resBody, _ := io.ReadAll(io.LimitReader(res.Body, 64<<10))
		res.Body.Close()
		switch {
		case res.StatusCode == http.StatusOK:
			return nil
		case res.StatusCode == http.StatusUnauthorized && attempt == 0:
			continue // token revoked or expired early: refresh once
		case unregistered(res.StatusCode, resBody):
			return notifications.ErrTokenUnregistered
		default:
			return fmt.Errorf("fcm: send status %d", res.StatusCode)
		}
	}
	return errors.New("fcm: unauthorized")
}

func unregistered(status int, body []byte) bool {
	if status == http.StatusNotFound {
		return true
	}
	var e struct {
		Error struct {
			Details []struct {
				ErrorCode string `json:"errorCode"`
			} `json:"details"`
		} `json:"error"`
	}
	if json.Unmarshal(body, &e) == nil {
		for _, d := range e.Error.Details {
			if d.ErrorCode == "UNREGISTERED" {
				return true
			}
		}
	}
	return false
}
