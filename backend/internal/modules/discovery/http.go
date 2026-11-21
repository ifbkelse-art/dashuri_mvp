package discovery

import (
	"net/http"

	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/routing"
)

// Routes registers this module's endpoints.
func Routes(mux *http.ServeMux, s *Service, mw routing.Stack) {
	mux.Handle("GET /v1/discovery/hosts", mw.User(s.handleListAvailableHosts))
	mux.Handle("GET /v1/discovery/hosts/{userId}", mw.User(s.handleGetHost))
	mux.Handle("GET /v1/discovery/summary", mw.User(s.handleGetSummary))
}

func (s *Service) handleListAvailableHosts(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	in, err := parseList(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.ListAvailableHosts(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, out)
}

func (s *Service) handleGetHost(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetHost(r.Context(), p, r.PathValue("userId"))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, out)
}

func (s *Service) handleGetSummary(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetSummary(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, out)
}
