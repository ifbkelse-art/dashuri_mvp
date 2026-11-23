package sightengine

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/url"
	"strings"
	"time"

	"dashuri/backend/internal/modules/reels"
)

// DefaultReelModels are the Sightengine models applied to every Reels frame
// (EXPERIMENT). Configurable with REELS_MODERATION_MODELS. Each model costs
// one operation per frame.
const DefaultReelModels = "nudity-2.1,gore-2.0,offensive-2.0"

// FrameClient implements reels.FrameClassifier with the image check API on
// a frame URL: GET check.json?url=…&models=…&api_user=…&api_secret=…
type FrameClient struct {
	APIUser   string
	APISecret string
	Models    string
	Endpoint  string
	HTTP      *http.Client
}

var _ reels.FrameClassifier = (*FrameClient)(nil)

// NewFrameClassifier returns nil without credentials, so Reels moderation
// fails closed to human review (never to publication).
func NewFrameClassifier(user, secret, models string, hc *http.Client) reels.FrameClassifier {
	if user == "" || secret == "" {
		return nil
	}
	if strings.TrimSpace(models) == "" {
		models = DefaultReelModels
	}
	return &FrameClient{APIUser: user, APISecret: secret, Models: models, HTTP: hc}
}

func (c *FrameClient) ClassifyURL(ctx context.Context, frameURL string) (reels.FrameScores, error) {
	endpoint := c.Endpoint
	if endpoint == "" {
		endpoint = DefaultEndpoint
	}
	q := url.Values{"url": {frameURL}, "models": {c.Models}, "api_user": {c.APIUser}, "api_secret": {c.APISecret}}
	ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint+"?"+q.Encode(), nil)
	if err != nil {
		return reels.FrameScores{}, err
	}
	hc := c.HTTP
	if hc == nil {
		hc = http.DefaultClient
	}
	res, err := hc.Do(req)
	if err != nil {
		// The error may contain the URL with the API secret; never wrap it.
		return reels.FrameScores{}, errors.New("sightengine: request failed")
	}
	defer res.Body.Close()
	body, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if err != nil {
		return reels.FrameScores{}, err
	}
	if res.StatusCode >= 500 {
		return reels.FrameScores{}, fmt.Errorf("sightengine: status %d", res.StatusCode)
	}
	return ParseFrameResponse(body)
}

// ParseFrameResponse maps a multi-model response to FrameScores:
// Sexual = max(sexual_activity, sexual_display, erotica); Suggestive =
// very_suggestive; Other = the highest probability in every other model
// block (ignoring "none" classes and context fields).
func ParseFrameResponse(body []byte) (reels.FrameScores, error) {
	var raw map[string]json.RawMessage
	if err := json.Unmarshal(body, &raw); err != nil {
		return reels.FrameScores{}, fmt.Errorf("sightengine: decode: %w", err)
	}
	var status string
	_ = json.Unmarshal(raw["status"], &status)
	if status != "success" {
		return reels.FrameScores{}, errors.New("sightengine: status " + status)
	}
	var out reels.FrameScores
	if n, ok := raw["nudity"]; ok {
		score, err := ParseResponse(append([]byte(`{"status":"success","nudity":`), append(n, '}')...))
		if err != nil {
			return out, err
		}
		out.Sexual = math.Max(score.SexualActivity, math.Max(score.SexualDisplay, score.Erotica))
		out.Suggestive = score.VerySuggestive
	} else {
		return out, errors.New("sightengine: response has no nudity block")
	}
	for k, v := range raw {
		switch k {
		case "status", "request", "media", "nudity":
			continue
		}
		var block any
		if json.Unmarshal(v, &block) == nil {
			out.Other = math.Max(out.Other, maxProb(block))
		}
	}
	return out, nil
}

func maxProb(v any) float64 {
	m := 0.0
	switch t := v.(type) {
	case map[string]any:
		for k, x := range t {
			if k == "none" || k == "context" || strings.HasSuffix(k, "_none") {
				continue
			}
			m = math.Max(m, maxProb(x))
		}
	case []any:
		for _, x := range t {
			m = math.Max(m, maxProb(x))
		}
	case float64:
		if t >= 0 && t <= 1 {
			m = t
		}
	}
	return m
}
