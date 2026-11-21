package calls

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
	mux.Handle("POST /v1/calls", mw.User(idempotency.Require(mw.Idempotency, s.handleRequestCall)))
	mux.Handle("GET /v1/calls/{callId}", mw.User(s.handleGetCall))
	mux.Handle("POST /v1/calls/{callId}/accept", mw.User(auth.Require(s.handleAcceptCall, auth.RoleHost)))
	mux.Handle("POST /v1/calls/{callId}/decline", mw.User(auth.Require(s.handleDeclineCall, auth.RoleHost)))
	mux.Handle("POST /v1/calls/{callId}/end", mw.User(idempotency.Require(mw.Idempotency, s.handleEndCall)))
	mux.Handle("POST /v1/calls/{callId}/credentials", mw.User(s.handleGetCallCredentials))
	mux.Handle("POST /v1/webhooks/video/{provider}", mw.Webhook(s.handleVideoProviderWebhook))
}

func (s *Service) handleRequestCall(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in CallRequestBody
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.RequestCall(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 201, out)
}

func (s *Service) handleGetCall(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetCall(r.Context(), p, r.PathValue("callId"))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleAcceptCall(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.AcceptCall(r.Context(), p, r.PathValue("callId"))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleDeclineCall(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.DeclineCall(r.Context(), p, r.PathValue("callId"))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleEndCall(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in EndCallRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.EndCall(r.Context(), p, r.PathValue("callId"), in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleGetCallCredentials(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetCallCredentials(r.Context(), p, r.PathValue("callId"))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleVideoProviderWebhook(w http.ResponseWriter, r *http.Request) {
	raw, err := httpx.ReadRaw(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if err := s.VideoProviderWebhook(r.Context(), r.PathValue("provider"), raw, httpx.HeaderMap(r)); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
