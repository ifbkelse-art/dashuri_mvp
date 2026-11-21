package notifications

import (
	"net/http"

	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/routing"
)

// Routes registers this module's endpoints. Handlers only decode, validate,
// call the service and encode; no business logic lives here.
func Routes(mux *http.ServeMux, s *Service, mw routing.Stack) {
	mux.Handle("PUT /v1/me/devices", mw.User(s.handleRegisterDevice))
	mux.Handle("DELETE /v1/me/devices/{token}", mw.User(s.handleUnregisterDevice))
	mux.Handle("GET /v1/notifications", mw.User(s.handleListInbox))
	mux.Handle("POST /v1/notifications/{notificationId}/read", mw.User(s.handleMarkRead))
}

func (s *Service) handleRegisterDevice(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in DeviceRegistration
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	if err := s.RegisterDevice(r.Context(), p, in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleUnregisterDevice(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	if err := s.UnregisterDevice(r.Context(), p, r.PathValue("token")); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleListInbox(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	page, err := parsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.ListInbox(r.Context(), p, page)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleMarkRead(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	if err := s.MarkRead(r.Context(), p, r.PathValue("notificationId")); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
