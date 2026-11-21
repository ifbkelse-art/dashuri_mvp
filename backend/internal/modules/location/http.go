package location

import (
	"net/http"

	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/routing"
)

// Routes registers the location endpoints.
func Routes(mux *http.ServeMux, s *Service, mw routing.Stack) {
	mux.Handle("GET /v1/locations/cities", mw.User(s.handleListCities))
	mux.Handle("POST /v1/locations/resolve", mw.User(s.handleResolve))
}

func (s *Service) handleListCities(w http.ResponseWriter, r *http.Request) {
	out, err := s.ListCities(r.Context(), r.URL.Query().Get("query"))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, out)
}

func (s *Service) handleResolve(w http.ResponseWriter, r *http.Request) {
	var in ResolveRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.Resolve(r.Context(), in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusOK, out)
}
