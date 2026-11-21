package moderation

import (
	"encoding/json"
	"errors"
	"net/http"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/idempotency"
	"dashuri/backend/internal/platform/routing"
)

// Routes registers this module's endpoints. Handlers only decode, validate,
// call the service and encode; no business logic lives here.
func Routes(mux *http.ServeMux, s *Service, mw routing.Stack) {
	mux.Handle("POST /v1/calls/{callId}/moderation-frames", mw.User(s.handleSubmitFrame))
	mux.Handle("GET /v1/admin/moderation/queue", mw.User(auth.Require(s.handleListModerationQueue, auth.RoleModerator, auth.RoleAdmin)))
	mux.Handle("POST /v1/admin/reports/{reportId}/decisions", mw.User(idempotency.Require(mw.Idempotency, auth.Require(s.handleDecideReport, auth.RoleModerator, auth.RoleAdmin))))
	mux.Handle("POST /v1/admin/appeals/{appealId}/decisions", mw.User(idempotency.Require(mw.Idempotency, auth.Require(s.handleDecideAppeal, auth.RoleModerator, auth.RoleAdmin))))
}

func (s *Service) handleListModerationQueue(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	page, err := parsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.ListModerationQueue(r.Context(), p, page)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleDecideReport(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in ModerationDecisionRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.DecideReport(r.Context(), p, r.PathValue("reportId"), in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 201, out)
}

func (s *Service) handleDecideAppeal(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in AppealDecisionRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.DecideAppeal(r.Context(), p, r.PathValue("appealId"), in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 201, out)
}

// frameBodyLimit allows a 200 KB JPEG in base64 plus the JSON envelope (the
// shared 64 KB JSON cap is too small for frames).
const frameBodyLimit = 300 << 10

func (s *Service) handleSubmitFrame(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in ModerationFrameRequest
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, frameBodyLimit))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&in); err != nil {
		var tooBig *http.MaxBytesError
		if errors.As(err, &tooBig) {
			httpx.WriteError(w, r, apperr.Validation(map[string]string{"body": "too_large"}))
			return
		}
		httpx.WriteError(w, r, apperr.Validation(map[string]string{"body": "invalid_json"}))
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.SubmitFrame(r.Context(), p, r.PathValue("callId"), in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, http.StatusAccepted, out)
}
