package idempotency

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"
)

type memStore struct {
	mu sync.Mutex
	m  map[string]*Record
}

func (s *memStore) Begin(_ context.Context, scope, key, hash string, _ time.Duration) (*Record, bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if r, ok := s.m[scope+key]; ok {
		return r, false, nil
	}
	s.m[scope+key] = &Record{RequestHash: hash}
	return nil, true, nil
}

func (s *memStore) Complete(_ context.Context, scope, key string, status int, body []byte) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	r := s.m[scope+key]
	r.Status, r.Body, r.Completed = status, body, true
	return nil
}

func (s *memStore) Release(_ context.Context, scope, key string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.m, scope+key)
	return nil
}

func TestReplayExecutesOnce(t *testing.T) {
	store := &memStore{m: map[string]*Record{}}
	calls := 0
	h := Require(store, func(w http.ResponseWriter, _ *http.Request) {
		calls++
		w.WriteHeader(http.StatusCreated)
		_, _ = w.Write([]byte(`{"withdrawal_id":"w1"}`))
	})
	key := "0b6f9f5e-7b8a-4c1e-9a55-1d2f3e4a5b6c"
	for i := 0; i < 3; i++ {
		req := httptest.NewRequest(http.MethodPost, "/v1/host/withdrawals", strings.NewReader(`{"beans":100000}`))
		req.Header.Set("Idempotency-Key", key)
		rr := httptest.NewRecorder()
		h(rr, req)
		if rr.Code != http.StatusCreated || rr.Body.String() != `{"withdrawal_id":"w1"}` {
			t.Fatalf("attempt %d: got %d %q", i, rr.Code, rr.Body.String())
		}
	}
	if calls != 1 {
		t.Fatalf("handler ran %d times, want 1", calls)
	}
}

func TestKeyReuseWithDifferentBodyIsRejected(t *testing.T) {
	store := &memStore{m: map[string]*Record{}}
	h := Require(store, func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusCreated) })
	key := "0b6f9f5e-7b8a-4c1e-9a55-1d2f3e4a5b6c"
	for i, body := range []string{`{"beans":100000}`, `{"beans":900000}`} {
		req := httptest.NewRequest(http.MethodPost, "/v1/host/withdrawals", strings.NewReader(body))
		req.Header.Set("Idempotency-Key", key)
		rr := httptest.NewRecorder()
		h(rr, req)
		if i == 1 && rr.Code != http.StatusUnprocessableEntity {
			t.Fatalf("reuse with different body: got %d, want 422", rr.Code)
		}
	}
}

func TestMissingKeyRejected(t *testing.T) {
	h := Require(&memStore{m: map[string]*Record{}}, func(http.ResponseWriter, *http.Request) { t.Fatal("must not run") })
	rr := httptest.NewRecorder()
	h(rr, httptest.NewRequest(http.MethodPost, "/v1/calls", strings.NewReader(`{}`)))
	if rr.Code != http.StatusUnprocessableEntity {
		t.Fatalf("got %d", rr.Code)
	}
}
