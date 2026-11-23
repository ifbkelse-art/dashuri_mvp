package sightengine

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestParseFrameResponseMaxima(t *testing.T) {
	body := `{"status":"success","request":{"id":"r"},"media":{"uri":"x"},
	  "nudity":{"sexual_activity":0.01,"sexual_display":0.3,"erotica":0.05,"very_suggestive":0.6,"suggestive":0.9,"none":0.9,"context":{"sea_lake_pool":0.99}},
	  "gore":{"prob":0.02,"classes":{"very_bloody":0.01}},
	  "offensive":{"nazi":0.01,"middle_finger":0.45,"none":0.99}}`
	s, err := ParseFrameResponse([]byte(body))
	if err != nil {
		t.Fatal(err)
	}
	if s.Sexual != 0.3 || s.Suggestive != 0.6 || s.Other != 0.45 {
		t.Fatalf("got %+v", s)
	}
}

func TestParseFrameResponseFailures(t *testing.T) {
	for _, b := range []string{`{"status":"failure","error":{"type":"x","code":1,"message":"m"}}`, `{"status":"success"}`, `nope`} {
		if _, err := ParseFrameResponse([]byte(b)); err == nil {
			t.Fatalf("accepted %s", b)
		}
	}
}

func TestFrameClassifierRequestAndNilWithoutCredentials(t *testing.T) {
	if NewFrameClassifier("", "", "", nil) != nil {
		t.Fatal("no credentials → nil classifier (fail closed to human review)")
	}
	var q string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		q = r.URL.RawQuery
		_, _ = w.Write([]byte(`{"status":"success","nudity":{"sexual_activity":0.9}}`))
	}))
	defer srv.Close()
	c := NewFrameClassifier("u", "s", "", srv.Client()).(*FrameClient)
	c.Endpoint = srv.URL
	s, err := c.ClassifyURL(t.Context(), "https://image.mux.com/pb/thumbnail.jpg?token=t")
	if err != nil || s.Sexual != 0.9 {
		t.Fatalf("%+v %v", s, err)
	}
	if !strings.Contains(q, "models=nudity-2.1%2Cgore-2.0%2Coffensive-2.0") || !strings.Contains(q, "url=https") {
		t.Fatalf("query %s", q)
	}
	srv.Close()
	if _, err := c.ClassifyURL(t.Context(), "https://x"); err == nil || strings.Contains(err.Error(), "api_secret") {
		t.Fatalf("errors must not leak the secret: %v", err)
	}
}
