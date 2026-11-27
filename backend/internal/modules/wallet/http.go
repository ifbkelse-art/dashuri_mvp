package wallet

import (
	"net/http"

	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/routing"
)

// Routes registers this module's endpoints. Handlers only decode, validate,
// call the service and encode; no business logic lives here.
func Routes(mux *http.ServeMux, s *Service, mw routing.Stack) {
	mux.Handle("GET /v1/wallet", mw.User(s.handleGetWalletSummary))
	mux.Handle("GET /v1/wallet/entries", mw.User(s.handleListWalletEntries))
	mux.Handle("GET /v1/host/beans/history", mw.User(auth.Require(s.handleListBeanHistory, auth.RoleHost)))
	mux.Handle("GET /v1/host/beans/summary", mw.User(auth.Require(s.handleGetBeanSummary, auth.RoleHost)))
}

func (s *Service) handleListBeanHistory(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	page, err := parsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.ListBeanHistory(r.Context(), p, page, r.URL.Query().Get("type"))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleGetBeanSummary(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetBeanSummary(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleGetWalletSummary(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetWalletSummary(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleListWalletEntries(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	page, err := parsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.ListWalletEntries(r.Context(), p, page)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}
