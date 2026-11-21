package accounts

import (
	"net/http"

	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/idempotency"
	"dashuri/backend/internal/platform/routing"
)

// Routes registers this module's endpoints. Handlers only decode, call the
// service and encode; validation and rules live in the service.
func Routes(mux *http.ServeMux, s *Service, mw routing.Stack) {
	mux.Handle("GET /v1/me", mw.User(s.handleGetMe))
	mux.Handle("POST /v1/me/rules-acceptance", mw.User(s.handleAcceptRules))
	mux.Handle("GET /v1/me/profile", mw.User(s.handleGetMyProfile))
	mux.Handle("PATCH /v1/me/profile", mw.User(s.handleUpdateMyProfile))
	mux.Handle("GET /v1/profiles/{userId}", mw.User(s.handleGetProfile))
	mux.Handle("POST /v1/me/photos/upload-tickets", mw.User(idempotency.Require(mw.Idempotency, s.handleRequestPhotoUpload)))
	mux.Handle("GET /v1/me/age", mw.User(s.handleGetAgeStatus))
	mux.Handle("POST /v1/me/age/declaration", mw.User(idempotency.Require(mw.Idempotency, s.handleSubmitAgeDeclaration)))
	mux.Handle("GET /v1/me/consents", mw.User(s.handleGetConsents))
	mux.Handle("PUT /v1/me/consents", mw.User(s.handleUpdateConsents))
	mux.Handle("POST /v1/me/deletion-requests", mw.User(idempotency.Require(mw.Idempotency, s.handleRequestAccountDeletion)))
	mux.Handle("POST /v1/me/data-exports", mw.User(idempotency.Require(mw.Idempotency, s.handleRequestDataExport)))
}

func write[T any](w http.ResponseWriter, r *http.Request, status int, out T, err error) {
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, status, out)
}

func principal(r *http.Request) auth.Principal {
	p, _ := auth.FromContext(r.Context())
	return p
}

func (s *Service) handleGetMe(w http.ResponseWriter, r *http.Request) {
	out, err := s.GetMe(r.Context(), principal(r))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleAcceptRules(w http.ResponseWriter, r *http.Request) {
	var in RulesAcceptanceRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.AcceptRules(r.Context(), principal(r), in)
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleGetMyProfile(w http.ResponseWriter, r *http.Request) {
	out, err := s.GetMyProfile(r.Context(), principal(r))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleUpdateMyProfile(w http.ResponseWriter, r *http.Request) {
	var in UpdateProfileRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.UpdateMyProfile(r.Context(), principal(r), in)
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleGetProfile(w http.ResponseWriter, r *http.Request) {
	out, err := s.GetProfile(r.Context(), principal(r), r.PathValue("userId"))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleRequestPhotoUpload(w http.ResponseWriter, r *http.Request) {
	var in PhotoUploadTicketRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.RequestPhotoUpload(r.Context(), principal(r), in)
	write(w, r, http.StatusCreated, out, err)
}

func (s *Service) handleGetAgeStatus(w http.ResponseWriter, r *http.Request) {
	out, err := s.GetAgeStatus(r.Context(), principal(r))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleSubmitAgeDeclaration(w http.ResponseWriter, r *http.Request) {
	var in AgeDeclarationRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.SubmitAgeDeclaration(r.Context(), principal(r), in)
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleGetConsents(w http.ResponseWriter, r *http.Request) {
	out, err := s.GetConsents(r.Context(), principal(r))
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleUpdateConsents(w http.ResponseWriter, r *http.Request) {
	var in UpdateConsentsRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	out, err := s.UpdateConsents(r.Context(), principal(r), in)
	write(w, r, http.StatusOK, out, err)
}

func (s *Service) handleRequestAccountDeletion(w http.ResponseWriter, r *http.Request) {
	out, err := s.RequestAccountDeletion(r.Context(), principal(r))
	write(w, r, http.StatusAccepted, out, err)
}

func (s *Service) handleRequestDataExport(w http.ResponseWriter, r *http.Request) {
	out, err := s.RequestDataExport(r.Context(), principal(r))
	write(w, r, http.StatusAccepted, out, err)
}
