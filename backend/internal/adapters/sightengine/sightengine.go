// Package sightengine implements moderation.NudityClassifier with the
// Sightengine image moderation API (model nudity-2.1):
// POST https://api.sightengine.com/1.0/check.json, multipart form with
// media, models, api_user and api_secret.
package sightengine

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"time"

	"dashuri/backend/internal/modules/moderation"
)

// DefaultEndpoint is the Sightengine check endpoint.
const DefaultEndpoint = "https://api.sightengine.com/1.0/check.json"

// Client is the Sightengine adapter.
type Client struct {
	APIUser   string
	APISecret string
	Endpoint  string // defaults to DefaultEndpoint (tests use httptest)
	HTTP      *http.Client
}

var _ moderation.NudityClassifier = (*Client)(nil)

// New returns a classifier, or nil when credentials are missing (the
// moderation service then refuses frames with 503 moderation_not_configured).
func New(user, secret string, hc *http.Client) moderation.NudityClassifier {
	if user == "" || secret == "" {
		return nil
	}
	return &Client{APIUser: user, APISecret: secret, HTTP: hc}
}

// response is the subset of the nudity-2.1 response used.
type response struct {
	Status string `json:"status"`
	Error  *struct {
		Type    string `json:"type"`
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"error"`
	Nudity *struct {
		SexualActivity   float64 `json:"sexual_activity"`
		SexualDisplay    float64 `json:"sexual_display"`
		Erotica          float64 `json:"erotica"`
		VerySuggestive   float64 `json:"very_suggestive"`
		Suggestive       float64 `json:"suggestive"`
		MildlySuggestive float64 `json:"mildly_suggestive"`
		None             float64 `json:"none"`
	} `json:"nudity"`
}

// ParseResponse maps a Sightengine JSON response to a NudityScore.
func ParseResponse(body []byte) (moderation.NudityScore, error) {
	var r response
	if err := json.Unmarshal(body, &r); err != nil {
		return moderation.NudityScore{}, fmt.Errorf("sightengine: decode: %w", err)
	}
	if r.Status != "success" {
		if r.Error != nil {
			return moderation.NudityScore{}, fmt.Errorf("sightengine: %s (%d): %s", r.Error.Type, r.Error.Code, r.Error.Message)
		}
		return moderation.NudityScore{}, errors.New("sightengine: status " + r.Status)
	}
	if r.Nudity == nil {
		return moderation.NudityScore{}, errors.New("sightengine: response has no nudity block")
	}
	n := r.Nudity
	return moderation.NudityScore{
		Vendor: "sightengine", SexualActivity: n.SexualActivity, SexualDisplay: n.SexualDisplay, Erotica: n.Erotica,
		VerySuggestive: n.VerySuggestive, Suggestive: n.Suggestive,
	}, nil
}

// Score uploads one JPEG frame and returns its nudity probabilities.
func (c *Client) Score(ctx context.Context, frame []byte) (moderation.NudityScore, error) {
	var buf bytes.Buffer
	mw := multipart.NewWriter(&buf)
	for k, v := range map[string]string{"models": "nudity-2.1", "api_user": c.APIUser, "api_secret": c.APISecret} {
		if err := mw.WriteField(k, v); err != nil {
			return moderation.NudityScore{}, err
		}
	}
	fw, err := mw.CreateFormFile("media", "frame.jpg")
	if err != nil {
		return moderation.NudityScore{}, err
	}
	if _, err := fw.Write(frame); err != nil {
		return moderation.NudityScore{}, err
	}
	if err := mw.Close(); err != nil {
		return moderation.NudityScore{}, err
	}
	endpoint := c.Endpoint
	if endpoint == "" {
		endpoint = DefaultEndpoint
	}
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, &buf)
	if err != nil {
		return moderation.NudityScore{}, err
	}
	req.Header.Set("Content-Type", mw.FormDataContentType())
	hc := c.HTTP
	if hc == nil {
		hc = http.DefaultClient
	}
	res, err := hc.Do(req)
	if err != nil {
		return moderation.NudityScore{}, fmt.Errorf("sightengine: %w", err)
	}
	defer res.Body.Close()
	body, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if err != nil {
		return moderation.NudityScore{}, err
	}
	if res.StatusCode >= 500 {
		return moderation.NudityScore{}, fmt.Errorf("sightengine: status %d", res.StatusCode)
	}
	return ParseResponse(body)
}
