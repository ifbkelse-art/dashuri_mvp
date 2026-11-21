package safety

import (
	"net/http"

	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/idempotency"
	"dashuri/backend/internal/platform/routing"
)

// Routes registers this module's endpoints. Handlers only decode, validate,
// call the service and encode; no business logic lives here.
func Routes(mux *http.ServeMux, s *Service, mw routing.Stack) {
	mux.Handle("POST /v1/reports", mw.User(idempotency.Require(mw.Idempotency, s.handleReportUser)))
	mux.Handle("POST /v1/blocks", mw.User(idempotency.Require(mw.Idempotency, s.handleBlockUser)))
	mux.Handle("DELETE /v1/blocks/{userId}", mw.User(s.handleUnblockUser))
	mux.Handle("GET /v1/blocks", mw.User(s.handleListBlockedUsers))
	mux.Handle("GET /v1/me/enforcement", mw.User(s.handleListEnforcementNotices))
	mux.Handle("POST /v1/appeals", mw.User(idempotency.Require(mw.Idempotency, s.handleSubmitAppeal)))
}

func (s *Service) handleReportUser(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in ReportRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.ReportUser(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 201, out)
}

func (s *Service) handleBlockUser(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in BlockRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.BlockUser(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 201, out)
}

func (s *Service) handleUnblockUser(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	if err := s.UnblockUser(r.Context(), p, r.PathValue("userId")); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleListBlockedUsers(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	page, err := parsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.ListBlockedUsers(r.Context(), p, page)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleListEnforcementNotices(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	page, err := parsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.ListEnforcementNotices(r.Context(), p, page)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleSubmitAppeal(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in AppealRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.SubmitAppeal(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 201, out)
}
