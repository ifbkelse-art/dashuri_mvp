// Package googleplay implements purchases.PlayDeveloperAPI against the Google
// Play Developer API (androidpublisher v3) and purchases.PushAuthenticator for
// Real-Time Developer Notifications delivered by Pub/Sub push.
//
// Authentication uses a service-account key file (GOOGLE_APPLICATION_CREDENTIALS)
// with the OAuth 2.0 JWT-bearer grant: the client signs an RS256 assertion
// with the key's private key and exchanges it at the key's token_uri for a
// one-hour access token (scope androidpublisher). Only stdlib and golang-jwt.
package googleplay

import (
	"bytes"
	"context"
	"crypto/rsa"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"

	"dashuri/backend/internal/modules/purchases"
)

const (
	DefaultBaseURL  = "https://androidpublisher.googleapis.com"
	Scope           = "https://www.googleapis.com/auth/androidpublisher"
	defaultTokenURI = "https://oauth2.googleapis.com/token"
)

// ServiceAccount is the subset of a Google service-account key file we use.
type ServiceAccount struct {
	Type         string `json:"type"`
	ClientEmail  string `json:"client_email"`
	PrivateKey   string `json:"private_key"`
	PrivateKeyID string `json:"private_key_id"`
	TokenURI     string `json:"token_uri"`
}

// Client calls the Android Publisher API.
type Client struct {
	HTTP    *http.Client
	BaseURL string

	sa  ServiceAccount
	key *rsa.PrivateKey

	mu       sync.Mutex
	token    string
	tokenExp time.Time
}

var _ purchases.PlayDeveloperAPI = (*Client)(nil)

// NewFromFile loads a service-account key file.
func NewFromFile(path string, hc *http.Client) (*Client, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("googleplay: read credentials: %w", err)
	}
	return New(b, hc)
}

// New parses service-account JSON.
func New(credentialsJSON []byte, hc *http.Client) (*Client, error) {
	var sa ServiceAccount
	if err := json.Unmarshal(credentialsJSON, &sa); err != nil {
		return nil, fmt.Errorf("googleplay: parse credentials: %w", err)
	}
	if sa.ClientEmail == "" || sa.PrivateKey == "" {
		return nil, errors.New("googleplay: credentials need client_email and private_key")
	}
	key, err := jwt.ParseRSAPrivateKeyFromPEM([]byte(sa.PrivateKey))
	if err != nil {
		return nil, fmt.Errorf("googleplay: parse private key: %w", err)
	}
	if sa.TokenURI == "" {
		sa.TokenURI = defaultTokenURI
	}
	if hc == nil {
		hc = &http.Client{Timeout: 15 * time.Second}
	}
	return &Client{HTTP: hc, BaseURL: DefaultBaseURL, sa: sa, key: key}, nil
}

// accessToken returns a cached OAuth token, refreshing 2 minutes early.
func (c *Client) accessToken(ctx context.Context) (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.token != "" && time.Now().Before(c.tokenExp.Add(-2*time.Minute)) {
		return c.token, nil
	}
	now := time.Now()
	claims := jwt.MapClaims{
		"iss": c.sa.ClientEmail, "scope": Scope, "aud": c.sa.TokenURI,
		"iat": now.Unix(), "exp": now.Add(time.Hour).Unix(),
	}
	t := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	if c.sa.PrivateKeyID != "" {
		t.Header["kid"] = c.sa.PrivateKeyID
	}
	assertion, err := t.SignedString(c.key)
	if err != nil {
		return "", fmt.Errorf("googleplay: sign assertion: %w", err)
	}
	form := url.Values{"grant_type": {"urn:ietf:params:oauth:grant-type:jwt-bearer"}, "assertion": {assertion}}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.sa.TokenURI, strings.NewReader(form.Encode()))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return "", fmt.Errorf("googleplay: token request: %w", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("googleplay: token endpoint returned %d", resp.StatusCode)
	}
	var tok struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int64  `json:"expires_in"`
	}
	if err := json.Unmarshal(body, &tok); err != nil || tok.AccessToken == "" {
		return "", errors.New("googleplay: token endpoint returned no access_token")
	}
	if tok.ExpiresIn <= 0 {
		tok.ExpiresIn = 3600
	}
	c.token, c.tokenExp = tok.AccessToken, now.Add(time.Duration(tok.ExpiresIn)*time.Second)
	return c.token, nil
}

func (c *Client) do(ctx context.Context, method, path string, body any) (int, []byte, error) {
	tok, err := c.accessToken(ctx)
	if err != nil {
		return 0, nil, err
	}
	var rd io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rd = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(ctx, method, strings.TrimRight(c.BaseURL, "/")+path, rd)
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("Authorization", "Bearer "+tok)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return 0, nil, fmt.Errorf("googleplay: %s %s: %w", method, path, err)
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(io.LimitReader(resp.Body, 4<<20))
	return resp.StatusCode, b, nil
}

func productPath(pkg, productID, token string) string {
	return "/androidpublisher/v3/applications/" + url.PathEscape(pkg) + "/purchases/products/" +
		url.PathEscape(productID) + "/tokens/" + url.PathEscape(token)
}

// ProductPurchaseResponse is Google's ProductPurchase resource.
type ProductPurchaseResponse struct {
	Kind                        string `json:"kind"`
	PurchaseTimeMillis          string `json:"purchaseTimeMillis"`
	PurchaseState               *int   `json:"purchaseState"`
	ConsumptionState            int    `json:"consumptionState"`
	OrderID                     string `json:"orderId"`
	PurchaseType                *int   `json:"purchaseType"`
	AcknowledgementState        int    `json:"acknowledgementState"`
	ObfuscatedExternalAccountID string `json:"obfuscatedExternalAccountId"`
	RegionCode                  string `json:"regionCode"`
	Quantity                    *int   `json:"quantity"`
	ProductID                   string `json:"productId"`
}

// MapProductPurchase converts Google's resource to the module's type.
func MapProductPurchase(r ProductPurchaseResponse) purchases.PlayPurchase {
	p := purchases.PlayPurchase{
		OrderID:              r.OrderID,
		PurchaseState:        purchases.PlayStatePurchased,
		Acknowledged:         r.AcknowledgementState == 1,
		Consumed:             r.ConsumptionState == 1,
		ObfuscatedAccountID:  r.ObfuscatedExternalAccountID,
		PurchaseType:         r.PurchaseType,
		Quantity:             1,
		RegionCode:           r.RegionCode,
		ProductID:            r.ProductID,
		AcknowledgementState: r.AcknowledgementState,
	}
	if r.PurchaseState != nil {
		p.PurchaseState = *r.PurchaseState
	}
	if r.Quantity != nil && *r.Quantity > 0 {
		p.Quantity = *r.Quantity
	}
	if ms, err := strconv.ParseInt(r.PurchaseTimeMillis, 10, 64); err == nil {
		p.PurchaseTime = time.UnixMilli(ms).UTC()
	}
	return p
}

// GetProductPurchase implements purchases.products.get.
func (c *Client) GetProductPurchase(ctx context.Context, pkg, productID, token string) (purchases.PlayPurchase, error) {
	status, body, err := c.do(ctx, http.MethodGet, productPath(pkg, productID, token), nil)
	if err != nil {
		return purchases.PlayPurchase{}, err
	}
	switch {
	case status == http.StatusBadRequest || status == http.StatusNotFound || status == http.StatusGone:
		return purchases.PlayPurchase{}, purchases.ErrPlayTokenInvalid
	case status != http.StatusOK:
		return purchases.PlayPurchase{}, fmt.Errorf("googleplay: products.get returned %d", status)
	}
	var r ProductPurchaseResponse
	if err := json.Unmarshal(body, &r); err != nil {
		return purchases.PlayPurchase{}, fmt.Errorf("googleplay: decode purchase: %w", err)
	}
	return MapProductPurchase(r), nil
}

// Acknowledge implements purchases.products.acknowledge.
func (c *Client) Consume(ctx context.Context, pkg, productID, token string) error {
	status, _, err := c.do(ctx, http.MethodPost, productPath(pkg, productID, token)+":consume", map[string]string{})
	if err != nil {
		return err
	}
	if status/100 != 2 {
		return fmt.Errorf("googleplay: consume returned %d", status)
	}
	return nil
}

// errorSnippet returns the message Google put in an error response (or a
// short prefix of the body), so a failed call is diagnosable from the log.
// Error bodies hold no credentials or purchase data.
func errorSnippet(body []byte) string {
	var e struct {
		Error struct {
			Message string `json:"message"`
			Status  string `json:"status"`
		} `json:"error"`
	}
	if json.Unmarshal(body, &e) == nil && e.Error.Message != "" {
		return strings.TrimSpace(e.Error.Status + " " + e.Error.Message)
	}
	s := strings.TrimSpace(string(body))
	if len(s) > 200 {
		s = s[:200]
	}
	return s
}

// VoidedPurchases implements purchases.voidedpurchases.list (one-time
// products, type=0), following pagination. Google keeps 30 days of history.
func (c *Client) VoidedPurchases(ctx context.Context, pkg string, since time.Time) ([]purchases.VoidedPurchase, error) {
	var out []purchases.VoidedPurchase
	pageToken := ""
	for page := 0; page < 100; page++ {
		q := url.Values{"startTime": {strconv.FormatInt(since.UnixMilli(), 10)}, "type": {"0"}, "maxResults": {"1000"}}
		if pageToken != "" {
			q.Set("token", pageToken)
		}
		status, body, err := c.do(ctx, http.MethodGet,
			"/androidpublisher/v3/applications/"+url.PathEscape(pkg)+"/purchases/voidedpurchases?"+q.Encode(), nil)
		if err != nil {
			return nil, err
		}
		if status != http.StatusOK {
			return nil, fmt.Errorf("googleplay: voidedpurchases.list returned %d: %s", status, errorSnippet(body))
		}
		var r struct {
			VoidedPurchases []struct {
				PurchaseToken    string `json:"purchaseToken"`
				OrderID          string `json:"orderId"`
				VoidedTimeMillis string `json:"voidedTimeMillis"`
				VoidedReason     int    `json:"voidedReason"`
				VoidedSource     int    `json:"voidedSource"`
			} `json:"voidedPurchases"`
			TokenPagination struct {
				NextPageToken string `json:"nextPageToken"`
			} `json:"tokenPagination"`
		}
		if err := json.Unmarshal(body, &r); err != nil {
			return nil, fmt.Errorf("googleplay: decode voided purchases: %w", err)
		}
		for _, v := range r.VoidedPurchases {
			vp := purchases.VoidedPurchase{PurchaseToken: v.PurchaseToken, OrderID: v.OrderID, Reason: v.VoidedReason, Source: v.VoidedSource}
			if ms, err := strconv.ParseInt(v.VoidedTimeMillis, 10, 64); err == nil {
				vp.VoidedAt = time.UnixMilli(ms).UTC()
			}
			out = append(out, vp)
		}
		if r.TokenPagination.NextPageToken == "" {
			return out, nil
		}
		pageToken = r.TokenPagination.NextPageToken
	}
	return out, nil
}
