package sightengine

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"dashuri/backend/internal/modules/moderation"
)

func TestParseResponse(t *testing.T) {
	s, err := ParseResponse([]byte(`{"status":"success","nudity":{"sexual_activity":0.01,"sexual_display":0.72,"erotica":0.1,"very_suggestive":0.2,"suggestive":0.3,"none":0.1}}`))
	if err != nil {
		t.Fatal(err)
	}
	if s.SexualDisplay != 0.72 || s.Explicit() != 0.72 || !s.Flagged(moderation.DefaultFlagThreshold) || s.Vendor != "sightengine" {
		t.Fatalf("%+v", s)
	}
	clean, _ := ParseResponse([]byte(`{"status":"success","nudity":{"sexual_activity":0.01,"sexual_display":0.02,"erotica":0.59,"very_suggestive":0.9}}`))
	if clean.Flagged(0.6) {
		t.Fatal("suggestive-only frame must not be flagged")
	}
	if !clean.Flagged(0.5) {
		t.Fatal("threshold must be configurable")
	}
	if _, err := ParseResponse([]byte(`{"status":"failure","error":{"type":"credentials_error","code":1,"message":"bad"}}`)); err == nil {
		t.Fatal("failure must error")
	}
}

func TestScoreSendsMultipart(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseMultipartForm(1 << 20); err != nil {
			w.WriteHeader(400)
			return
		}
		f, _, err := r.FormFile("media")
		if err != nil || r.FormValue("models") != "nudity-2.1" || r.FormValue("api_user") != "u" || r.FormValue("api_secret") != "s" {
			w.WriteHeader(400)
			return
		}
		b, _ := io.ReadAll(f)
		if string(b) != "\xff\xd8\xffjpeg" {
			w.WriteHeader(400)
			return
		}
		w.Write([]byte(`{"status":"success","nudity":{"sexual_activity":0.9}}`))
	}))
	defer srv.Close()
	c := &Client{APIUser: "u", APISecret: "s", Endpoint: srv.URL}
	s, err := c.Score(context.Background(), []byte("\xff\xd8\xffjpeg"))
	if err != nil || s.SexualActivity != 0.9 {
		t.Fatalf("%+v %v", s, err)
	}
	if New("", "", nil) != nil {
		t.Fatal("missing credentials must give a nil classifier")
	}
}
