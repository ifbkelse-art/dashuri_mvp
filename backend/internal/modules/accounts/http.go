package accounts

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
	mux.Handle("GET /v1/me", mw.User(s.handleGetMe))
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

func (s *Service) handleGetMe(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetMe(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleGetMyProfile(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetMyProfile(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleUpdateMyProfile(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in UpdateProfileRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.UpdateMyProfile(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleGetProfile(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetProfile(r.Context(), p, r.PathValue("userId"))
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleRequestPhotoUpload(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in PhotoUploadTicketRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.RequestPhotoUpload(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 201, out)
}

func (s *Service) handleGetAgeStatus(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetAgeStatus(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleSubmitAgeDeclaration(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in AgeDeclarationRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.SubmitAgeDeclaration(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleGetConsents(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.GetConsents(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleUpdateConsents(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	var in UpdateConsentsRequest
	if err := httpx.DecodeJSON(r, &in); err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	if errs := in.validate(); len(errs) > 0 {
		httpx.WriteError(w, r, validationError(errs))
		return
	}
	out, err := s.UpdateConsents(r.Context(), p, in)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 200, out)
}

func (s *Service) handleRequestAccountDeletion(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.RequestAccountDeletion(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 202, out)
}

func (s *Service) handleRequestDataExport(w http.ResponseWriter, r *http.Request) {
	p, _ := auth.FromContext(r.Context())
	out, err := s.RequestDataExport(r.Context(), p)
	if err != nil {
		httpx.WriteError(w, r, err)
		return
	}
	httpx.WriteJSON(w, 202, out)
}
