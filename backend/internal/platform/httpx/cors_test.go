package httpx

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func corsServer(allowed ...string) (http.Handler, *int) {
	hits := 0
	return CORS(allowed)(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		hits++
		w.WriteHeader(http.StatusOK)
	})), &hits
}

func TestCORSAllowsOnlyListedOrigin(t *testing.T) {
	h, hits := corsServer("https://admin.example.web.app")

	r := httptest.NewRequest("GET", "/v1/admin/me", nil)
	r.Header.Set("Origin", "https://admin.example.web.app")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if got := w.Header().Get("Access-Control-Allow-Origin"); got != "https://admin.example.web.app" {
		t.Fatalf("allow-origin = %q", got)
	}
	if w.Header().Get("Access-Control-Allow-Credentials") != "" {
		t.Fatal("credentials must stay off (bearer tokens only)")
	}
	if *hits != 1 {
		t.Fatal("request must reach the handler")
	}

	r = httptest.NewRequest("GET", "/v1/admin/me", nil)
	r.Header.Set("Origin", "https://evil.example.com")
	w = httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if got := w.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("unknown origin got %q", got)
	}
}

func TestCORSPreflight(t *testing.T) {
	h, hits := corsServer("http://localhost:5173")
	r := httptest.NewRequest("OPTIONS", "/v1/admin/hosts/x/verification/actions", nil)
	r.Header.Set("Origin", "http://localhost:5173")
	r.Header.Set("Access-Control-Request-Method", "POST")
	r.Header.Set("Access-Control-Request-Headers", "authorization, content-type, idempotency-key")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != http.StatusNoContent {
		t.Fatalf("status %d", w.Code)
	}
	if *hits != 0 {
		t.Fatal("preflight must not reach the handler")
	}
	if w.Header().Get("Access-Control-Allow-Headers") == "" || w.Header().Get("Access-Control-Allow-Methods") == "" {
		t.Fatal("missing preflight headers")
	}
}

func TestCORSDisabledWhenEmptyAndMobileUnaffected(t *testing.T) {
	h, _ := corsServer()
	r := httptest.NewRequest("GET", "/v1/me", nil)
	r.Header.Set("Origin", "http://localhost:5173")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Header().Get("Access-Control-Allow-Origin") != "" {
		t.Fatal("CORS must be off with no origins")
	}

	h, hits := corsServer("http://localhost:5173")
	r = httptest.NewRequest("GET", "/v1/me", nil) // mobile: no Origin header
	w = httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if *hits != 1 || w.Header().Get("Access-Control-Allow-Origin") != "" {
		t.Fatal("requests without an Origin pass through untouched")
	}
}

func TestCORSIgnoresWildcardAndTrailingSlash(t *testing.T) {
	h, _ := corsServer("*", "https://a.example.com/")
	r := httptest.NewRequest("GET", "/", nil)
	r.Header.Set("Origin", "https://other.example.com")
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Header().Get("Access-Control-Allow-Origin") != "" {
		t.Fatal("a wildcard must never be honoured")
	}
	r.Header.Set("Origin", "https://a.example.com")
	w = httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Header().Get("Access-Control-Allow-Origin") != "https://a.example.com" {
		t.Fatal("trailing slash in config should still match")
	}
}
