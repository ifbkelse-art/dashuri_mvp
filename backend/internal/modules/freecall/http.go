package freecall

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
	mux.Handle("GET /v1/free-call/card", mw.User(s.handleGetFreeCallCard))
	mux.Handle("POST /v1/free-call/requests", mw.User(idempotency.Require(mw.Idempotency, s.handleRequestFreeCall)))
	mux.Handle("GET /v1/free-call/requests/{requestId}", mw.User(s.handleGetFreeCallRequest))
}

func (s *Service) handleGetFreeCallCard(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetFreeCallCard(r.Context(), p, r.Header.Get(PlatformHeader))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleRequestFreeCall(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in FreeCallRequestBody
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.RequestFreeCall(r.Context(), p, in, r.Header.Get(PlatformHeader))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 201, out)
}

func (s *Service) handleGetFreeCallRequest(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetFreeCallRequest(r.Context(), p, r.PathValue("requestId"))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}
