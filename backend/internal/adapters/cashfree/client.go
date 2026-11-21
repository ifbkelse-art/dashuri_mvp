// Package cashfree implements purchases.CashfreeAPI against Cashfree PG
// (Orders API, webhook signature verification). Credentials are server-held;
// the app only ever receives a payment_session_id.
package cashfree

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"dashuri/backend/internal/modules/purchases"
)

const (
	SandboxBaseURL    = "https://sandbox.cashfree.com/pg"
	ProductionBaseURL = "https://api.cashfree.com/pg"
	// MaxWebhookAge rejects replayed webhook deliveries.
	MaxWebhookAge = 5 * time.Minute
)

// Client calls Cashfree PG.
type Client struct {
	HTTP         *http.Client
	BaseURL      string
	Env          string // sandbox | production
	ClientID     string
	ClientSecret string
	APIVersion   string
}

var _ purchases.CashfreeAPI = (*Client)(nil)

// New builds a client for CASHFREE_ENV.
func New(env, clientID, clientSecret, apiVersion string, hc *http.Client) *Client {
	base := SandboxBaseURL
	if env == "production" {
		base = ProductionBaseURL
	}
	if hc == nil {
		hc = &http.Client{Timeout: 15 * time.Second}
	}
	if apiVersion == "" {
		apiVersion = "2025-01-01"
	}
	return &Client{HTTP: hc, BaseURL: base, Env: env, ClientID: clientID, ClientSecret: clientSecret, APIVersion: apiVersion}
}

func (c *Client) Environment() string {
	if c.Env == "production" {
		return "production"
	}
	return "sandbox"
}

// ErrSignature means the webhook signature or timestamp is not acceptable.
var ErrSignature = errors.New("cashfree: invalid webhook signature")

// Sign computes base64(HMAC-SHA256(timestamp + rawBody, secret)).
func Sign(secret, timestamp string, raw []byte) string {
	m := hmac.New(sha256.New, []byte(secret))
	m.Write([]byte(timestamp))
	m.Write(raw)
	return base64.StdEncoding.EncodeToString(m.Sum(nil))
}

// VerifyWebhook checks the signature in constant time and rejects
// timestamps (milliseconds since epoch) outside ±5 minutes of now.
func (c *Client) VerifyWebhook(raw []byte, signature, timestamp string, now time.Time) error {
	return VerifySignature(c.ClientSecret, raw, signature, timestamp, now)
}

// VerifySignature is VerifyWebhook without a client.
func VerifySignature(secret string, raw []byte, signature, timestamp string, now time.Time) error {
	if secret == "" || signature == "" || timestamp == "" {
		return ErrSignature
	}
	ts, err := strconv.ParseInt(strings.TrimSpace(timestamp), 10, 64)
	if err != nil {
		return ErrSignature
	}
	at := time.UnixMilli(ts)
	if ts < 1e11 { // tolerate a timestamp sent in seconds
		at = time.Unix(ts, 0)
	}
	if d := now.Sub(at); d > MaxWebhookAge || d < -MaxWebhookAge {
		return fmt.Errorf("%w: stale timestamp", ErrSignature)
	}
	want := Sign(secret, timestamp, raw)
	if subtle.ConstantTimeCompare([]byte(want), []byte(signature)) != 1 {
		return ErrSignature
	}
	return nil
}

// PaiseToAmount formats paise as a rupee decimal (e.g. 119900 → 1199.00).
func PaiseToAmount(paise int64) json.Number {
	return json.Number(fmt.Sprintf("%d.%02d", paise/100, paise%100))
}

// AmountToPaise parses a rupee decimal exactly (no floating point).
func AmountToPaise(n json.Number) (int64, error) {
	s := strings.TrimSpace(n.String())
	if s == "" || strings.HasPrefix(s, "-") {
		return 0, fmt.Errorf("cashfree: bad amount %q", s)
	}
	whole, frac, _ := strings.Cut(s, ".")
	frac = strings.TrimRight(frac, "0")
	if len(frac) > 2 {
		return 0, fmt.Errorf("cashfree: amount %q has sub-paise precision", s)
	}
	for len(frac) < 2 {
		frac += "0"
	}
	w, err := strconv.ParseInt(whole, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("cashfree: bad amount %q", s)
	}
	f, err := strconv.ParseInt(frac, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("cashfree: bad amount %q", s)
	}
	return w*100 + f, nil
}

type orderResponse struct {
	CFOrderID        json.RawMessage `json:"cf_order_id"`
	OrderID          string          `json:"order_id"`
	OrderStatus      string          `json:"order_status"`
	OrderAmount      json.Number     `json:"order_amount"`
	OrderCurrency    string          `json:"order_currency"`
	PaymentSessionID string          `json:"payment_session_id"`
}

func (r orderResponse) toRemote() (purchases.CashfreeRemoteOrder, error) {
	paise, err := AmountToPaise(r.OrderAmount)
	if err != nil {
		return purchases.CashfreeRemoteOrder{}, err
	}
	cf := strings.Trim(string(r.CFOrderID), `"`)
	if cf == "null" {
		cf = ""
	}
	return purchases.CashfreeRemoteOrder{
		OrderID: r.OrderID, CFOrderID: cf, Status: r.OrderStatus, AmountPaise: paise,
		Currency: r.OrderCurrency, PaymentSessionID: r.PaymentSessionID,
	}, nil
}

func (c *Client) do(ctx context.Context, method, path string, body any, idemKey string) (int, []byte, error) {
	if c.ClientID == "" || c.ClientSecret == "" {
		return 0, nil, errors.New("cashfree: not configured")
	}
	var rd io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return 0, nil, err
		}
		rd = bytes.NewReader(b)
	}
	req, err := http.NewRequestWithContext(ctx, method, strings.TrimRight(c.BaseURL, "/")+path, rd)
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("x-client-id", c.ClientID)
	req.Header.Set("x-client-secret", c.ClientSecret)
	req.Header.Set("x-api-version", c.APIVersion)
	req.Header.Set("Accept", "application/json")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if idemKey != "" {
		req.Header.Set("x-idempotency-key", idemKey)
	}
	resp, err := c.HTTP.Do(req)
	if err != nil {
		return 0, nil, fmt.Errorf("cashfree: %s %s: %w", method, path, err)
	}
	defer resp.Body.Close()
	b, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	return resp.StatusCode, b, nil
}

// CreateOrder implements POST /orders.
func (c *Client) CreateOrder(ctx context.Context, in purchases.CashfreeCreateOrder) (purchases.CashfreeRemoteOrder, error) {
	meta := map[string]any{}
	if in.ReturnURL != "" {
		ru := in.ReturnURL
		if !strings.Contains(ru, "{order_id}") {
			sep := "?"
			if strings.Contains(ru, "?") {
				sep = "&"
			}
			ru += sep + "order_id={order_id}"
		}
		meta["return_url"] = ru
	}
	body := map[string]any{
		"order_id":       in.OrderID,
		"order_amount":   PaiseToAmount(in.AmountPaise),
		"order_currency": in.Currency,
		"customer_details": map[string]string{
			"customer_id":    in.CustomerID,
			"customer_phone": in.CustomerPhone,
		},
		"order_expiry_time": in.ExpiresAt.In(time.FixedZone("IST", 5*3600+1800)).Format(time.RFC3339),
		"order_note":        in.Note,
	}
	if len(meta) > 0 {
		body["order_meta"] = meta
	}
	status, b, err := c.do(ctx, http.MethodPost, "/orders", body, in.OrderID)
	if err != nil {
		return purchases.CashfreeRemoteOrder{}, err
	}
	if status != http.StatusOK && status != http.StatusCreated {
		return purchases.CashfreeRemoteOrder{}, fmt.Errorf("cashfree: create order returned %d: %s", status, errorMessage(b))
	}
	var r orderResponse
	if err := json.Unmarshal(b, &r); err != nil {
		return purchases.CashfreeRemoteOrder{}, fmt.Errorf("cashfree: decode order: %w", err)
	}
	return r.toRemote()
}

// GetOrder implements GET /orders/{order_id}.
func (c *Client) GetOrder(ctx context.Context, orderID string) (purchases.CashfreeRemoteOrder, error) {
	status, b, err := c.do(ctx, http.MethodGet, "/orders/"+url.PathEscape(orderID), nil, "")
	if err != nil {
		return purchases.CashfreeRemoteOrder{}, err
	}
	if status != http.StatusOK {
		return purchases.CashfreeRemoteOrder{}, fmt.Errorf("cashfree: get order returned %d: %s", status, errorMessage(b))
	}
	var r orderResponse
	if err := json.Unmarshal(b, &r); err != nil {
		return purchases.CashfreeRemoteOrder{}, fmt.Errorf("cashfree: decode order: %w", err)
	}
	return r.toRemote()
}

func errorMessage(b []byte) string {
	var e struct {
		Message string `json:"message"`
		Code    string `json:"code"`
	}
	if json.Unmarshal(b, &e) == nil && (e.Message != "" || e.Code != "") {
		return e.Code + " " + e.Message
	}
	return ""
}
