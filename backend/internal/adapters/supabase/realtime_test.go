package supabase

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestPublishSendsPrivateBroadcast(t *testing.T) {
	var got map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/realtime/v1/api/broadcast" || r.Header.Get("apikey") != "k" {
			t.Errorf("bad request %s %s", r.URL.Path, r.Header.Get("apikey"))
		}
		_ = json.NewDecoder(r.Body).Decode(&got)
		w.WriteHeader(202)
	}))
	defer srv.Close()
	p := Publisher{BaseURL: srv.URL, APIKey: "k"}
	if err := p.Publish(context.Background(), "user:abc", "call.updated", map[string]string{"call_id": "1"}); err != nil {
		t.Fatal(err)
	}
	m := got["messages"].([]any)[0].(map[string]any)
	if m["topic"] != "user:abc" || m["private"] != true || m["event"] != "call.updated" {
		t.Fatalf("unexpected message %v", m)
	}
}

func TestPublishDisabledIsNoop(t *testing.T) {
	if err := (Publisher{}).Publish(context.Background(), "user:x", "e", nil); err != nil {
		t.Fatal(err)
	}
}
