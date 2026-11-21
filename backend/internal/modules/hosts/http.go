package hosts

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
	mux.Handle("GET /v1/host", mw.User(s.handleGetHostStatus))
	mux.Handle("POST /v1/host/application", mw.User(idempotency.Require(mw.Idempotency, s.handleApplyAsHost)))
	mux.Handle("POST /v1/host/kyc/sessions", mw.User(idempotency.Require(mw.Idempotency, s.handleStartKyc)))
	mux.Handle("PUT /v1/host/availability", mw.User(auth.Require(s.handleSetAvailability, auth.RoleHost)))
	mux.Handle("POST /v1/host/availability/heartbeat", mw.User(auth.Require(s.handleSendHeartbeat, auth.RoleHost)))
	mux.Handle("PUT /v1/host/rate", mw.User(auth.Require(s.handleSetRate, auth.RoleHost)))
	mux.Handle("PUT /v1/host/free-call-opt-in", mw.User(auth.Require(s.handleSetFreeCallOptIn, auth.RoleHost)))
	mux.Handle("GET /v1/host/earnings", mw.User(auth.Require(s.handleGetEarnings, auth.RoleHost)))
	mux.Handle("POST /v1/admin/hosts/{userId}/kyc-decision", mw.User(auth.Require(s.handleDecideKyc, auth.RoleModerator, auth.RoleAdmin)))
}

func (s *Service) handleDecideKyc(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in KycDecisionRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.DecideKyc(r.Context(), p, r.PathValue("userId"), in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleGetHostStatus(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetHostStatus(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleApplyAsHost(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.ApplyAsHost(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleStartKyc(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.StartKyc(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 201, out)
}

func (s *Service) handleSetAvailability(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in SetAvailabilityRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.SetAvailability(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleSendHeartbeat(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	if err := s.SendHeartbeat(r.Context(), p); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleSetRate(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in SetRateRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.SetRate(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleSetFreeCallOptIn(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in SetFreeCallOptInRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.SetFreeCallOptIn(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleGetEarnings(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetEarnings(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}
