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

	// Verified Host (2026-11-23).
	mux.Handle("GET /v1/host/verification", mw.User(auth.Require(s.handleGetVerification, auth.RoleHost)))
	mux.Handle("POST /v1/host/verification/evidence", mw.User(auth.Require(s.handleCreateEvidenceUpload, auth.RoleHost)))
	mux.Handle("POST /v1/host/verification/submissions", mw.User(idempotency.Require(mw.Idempotency, auth.Require(s.handleSubmitVerification, auth.RoleHost))))
	staff := []auth.Role{auth.RoleModerator, auth.RoleAdmin}
	mux.Handle("GET /v1/admin/host-verifications", mw.User(auth.Require(s.handleVerificationQueue, staff...)))
	mux.Handle("GET /v1/admin/hosts/{userId}/verification", mw.User(auth.Require(s.handleGetAdminVerification, staff...)))
	mux.Handle("POST /v1/admin/hosts/{userId}/verification/actions", mw.User(idempotency.Require(mw.Idempotency, auth.Require(s.handleVerificationAction, staff...))))
	mux.Handle("POST /v1/admin/hosts/{userId}/verification/evidence/{evidenceId}/access", mw.User(auth.Require(s.handleEvidenceAccess, staff...)))

	// Arrival photo (2026-11-26; ARRIVAL_PHOTOS_ENABLED).
	mux.Handle("GET /v1/host/arrival-photo", mw.User(auth.Require(s.handleGetArrivalPhoto, auth.RoleHost)))
	mux.Handle("DELETE /v1/host/arrival-photo", mw.User(auth.Require(s.handleDeleteArrivalPhoto, auth.RoleHost)))
	mux.Handle("POST /v1/host/arrival-photo/upload-tickets", mw.User(auth.Require(s.handleCreateArrivalUpload, auth.RoleHost)))
	mux.Handle("POST /v1/host/arrival-photo/{photoId}/confirm", mw.User(auth.Require(s.handleConfirmArrivalPhoto, auth.RoleHost)))
	mux.Handle("GET /v1/admin/arrival-photos", mw.User(auth.Require(s.handleArrivalQueue, staff...)))
	mux.Handle("POST /v1/admin/arrival-photos/{photoId}/decision", mw.User(idempotency.Require(mw.Idempotency, auth.Require(s.handleArrivalDecision, staff...))))
}

func (s *Service) handleGetArrivalPhoto(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetArrivalPhoto(r.Context(), p)
	if err == nil && out == nil {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	writeResult(w, r, 200, out, err)
}

func (s *Service) handleDeleteArrivalPhoto(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	if err := s.DeleteArrivalPhoto(r.Context(), p); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (s *Service) handleCreateArrivalUpload(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in ArrivalUploadRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.CreateArrivalUpload(r.Context(), p, in)
	writeResult(w, r, 201, out, err)
}

func (s *Service) handleConfirmArrivalPhoto(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.ConfirmArrivalPhoto(r.Context(), p, r.PathValue("photoId"))
	writeResult(w, r, 200, out, err)
}

func (s *Service) handleArrivalQueue(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	pg, err := parsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.ArrivalReviewQueue(r.Context(), p, pg.Limit)
	writeResult(w, r, 200, map[string]any{"items": out}, err)
}

func (s *Service) handleArrivalDecision(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in ArrivalDecisionRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.DecideArrivalPhotoStaff(r.Context(), p, r.PathValue("photoId"), in)
	writeResult(w, r, 200, out, err)
}

func (s *Service) handleGetVerification(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetVerification(r.Context(), p)
	writeResult(w, r, 200, out, err)
}

func (s *Service) handleCreateEvidenceUpload(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in EvidenceUploadRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.CreateEvidenceUpload(r.Context(), p, in)
	writeResult(w, r, 201, out, err)
}

func (s *Service) handleSubmitVerification(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in SubmitVerificationRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.SubmitVerification(r.Context(), p, in)
	writeResult(w, r, 200, out, err)
}

func (s *Service) handleVerificationQueue(w http.ResponseWriter, r *http.Request) {
	pg, err := parsePage(r)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.VerificationQueue(r.Context(), r.URL.Query().Get("status"), pg.Limit)
	writeResult(w, r, 200, out, err)
}

func (s *Service) handleGetAdminVerification(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetAdminVerification(r.Context(), p, r.PathValue("userId"))
	writeResult(w, r, 200, out, err)
}

func (s *Service) handleVerificationAction(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in VerificationActionRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.ActOnVerification(r.Context(), p, r.PathValue("userId"), in)
	writeResult(w, r, 200, out, err)
}

func (s *Service) handleEvidenceAccess(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.EvidenceAccessURL(r.Context(), p, r.PathValue("userId"), r.PathValue("evidenceId"))
	writeResult(w, r, 200, out, err)
}

func writeResult(w http.ResponseWriter, r *http.Request, status int, out any, err error) {
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, status, out)
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
