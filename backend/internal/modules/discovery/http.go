package discovery

import (
	"net/http"

	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/routing"
)

// Routes registers this module's endpoints. Handlers only decode, validate,
// call the service and encode; no business logic lives here.
func Routes(mux *http.ServeMux, s *Service, mw routing.Stack) {
	mux.Handle("GET /v1/discovery/hosts", mw.User(s.handleListAvailableHosts))
}

func (s *Service) handleListAvailableHosts(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	page, err := parsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.ListAvailableHosts(r.Context(), p, page)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}
