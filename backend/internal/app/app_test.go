package app

import (
	"net/http"
	"net/http/httptest"
	"os"
	"regexp"
	"strings"
	"testing"

	"dashuri/backend/internal/platform/config"
)

func TestHealthz(t *testing.T) {
	h := New(config.Config{Env: "development"}, nil)
	rr := httptest.NewRecorder()
	h.ServeHTTP(rr, httptest.NewRequest(http.MethodGet, "/healthz", nil))
	if rr.Code != http.StatusOK {
		t.Fatalf("healthz %d", rr.Code)
	}
}

// Every user endpoint in the OpenAPI contract is mounted and refuses
// requests without a token (401), proving routes exist and auth wraps them.
func TestEveryContractRouteIsMountedAndAuthenticated(t *testing.T) {
	spec, err := os.ReadFile("../../../api/openapi/dashuri.v1.yaml")
	if err != nil {
		t.Fatal(err)
	}
	h := New(config.Config{Env: "development"}, nil)
	pathRE := regexp.MustCompile(`(?m)^  "?(/v1/[^:"]+)"?:$`)
	anyPathRE := regexp.MustCompile(`(?m)^  "?/[^:"]+"?:$`)
	methodRE := regexp.MustCompile(`(?m)^    (get|post|put|patch|delete):$`)
	sections := pathRE.FindAllStringSubmatchIndex(string(spec), -1)
	if len(sections) < 45 {
		t.Fatalf("parsed only %d paths", len(sections))
	}
	for _, s := range sections {
		path := string(spec[s[2]:s[3]])
		end := len(spec)
		if loc := anyPathRE.FindIndex(spec[s[1]:]); loc != nil {
			end = s[1] + loc[0]
		}
		block := string(spec[s[1]:end])
		for _, m := range methodRE.FindAllStringSubmatch(block, -1) {
			concrete := regexp.MustCompile(`\{[^}]+\}`).ReplaceAllString(path, "00000000-0000-4000-8000-000000000000")
			req := httptest.NewRequest(strings.ToUpper(m[1]), concrete, strings.NewReader(`{}`))
			rr := httptest.NewRecorder()
			h.ServeHTTP(rr, req)
			webhook := strings.Contains(path, "/webhooks/")
			switch {
			case webhook && rr.Code == http.StatusNotFound:
				t.Errorf("%s %s not mounted", m[1], path)
			case !webhook && rr.Code != http.StatusUnauthorized:
				t.Errorf("%s %s: got %d, want 401 without token", m[1], path, rr.Code)
			}
		}
	}
}
