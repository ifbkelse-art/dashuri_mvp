// Package supabase publishes server events to Supabase Realtime private
// broadcast channels (ADR-006). Clients may only receive (RLS on
// realtime.messages); only this server-side key can send.
package supabase

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"time"
)

// Publisher sends broadcasts through the Realtime REST endpoint.
type Publisher struct {
	BaseURL string // SUPABASE_URL
	APIKey  string // server-only key allowed to broadcast
	Client  *http.Client
}

// Publish sends one event to a private topic such as `user:<id>` or `call:<id>`.
// Events are hints: clients re-fetch from the API, so a failure is logged and
// returned but must never roll back a committed business transaction.
func (p Publisher) Publish(ctx context.Context, channel, event string, payload any) error {
	if p.BaseURL == "" || p.APIKey == "" {
		slog.Debug("realtime disabled; event dropped", "channel_kind", strings.SplitN(channel, ":", 2)[0], "event", event)
		return nil
	}
	body, err := json.Marshal(map[string]any{"messages": []map[string]any{{
		"topic": channel, "event": event, "payload": payload, "private": true,
	}}})
	if err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(p.BaseURL, "/")+"/realtime/v1/api/broadcast", bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("apikey", p.APIKey)
	req.Header.Set("Authorization", "Bearer "+p.APIKey)
	c := p.Client
	if c == nil {
		c = http.DefaultClient
	}
	res, err := c.Do(req)
	if err != nil {
		slog.Warn("realtime publish failed", "event", event, "err", err)
		return err
	}
	defer res.Body.Close()
	if res.StatusCode >= 300 {
		slog.Warn("realtime publish rejected", "event", event, "status", res.StatusCode)
		return fmt.Errorf("realtime: status %d", res.StatusCode)
	}
	return nil
}
