package accounts

import (
	"context"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
)

// Service implements the accounts module's use cases. Every method is a
// scaffold that returns 501 until implemented; the documented steps are the
// required behaviour (see docs/architecture).
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service { return &Service{deps: d} }

// GetMe: GET /v1/me — Account status (eligibility, host role, restriction).
func (s *Service) GetMe(ctx context.Context, p auth.Principal) (AccountStatus, error) {
	return AccountStatus{}, apperr.NotImplemented("accounts.GetMe")
}

// GetMyProfile: GET /v1/me/profile — Own profile.
func (s *Service) GetMyProfile(ctx context.Context, p auth.Principal) (Profile, error) {
	return Profile{}, apperr.NotImplemented("accounts.GetMyProfile")
}

// UpdateMyProfile: PATCH /v1/me/profile — Update own profile. Text is screened for contact details and banned terms.
func (s *Service) UpdateMyProfile(ctx context.Context, p auth.Principal, in UpdateProfileRequest) (Profile, error) {
	return Profile{}, apperr.NotImplemented("accounts.UpdateMyProfile")
}

// GetProfile: GET /v1/profiles/{userId} — Another user's public profile (404 if blocked either way).
func (s *Service) GetProfile(ctx context.Context, p auth.Principal, userId string) (Profile, error) {
	return Profile{}, apperr.NotImplemented("accounts.GetProfile")
}

// RequestPhotoUpload: POST /v1/me/photos/upload-tickets — Signed upload URL for a profile photo (private until moderated).
func (s *Service) RequestPhotoUpload(ctx context.Context, p auth.Principal, in PhotoUploadTicketRequest) (PhotoUploadTicket, error) {
	return PhotoUploadTicket{}, apperr.NotImplemented("accounts.RequestPhotoUpload")
}

// GetAgeStatus: GET /v1/me/age — 18+ eligibility status.
func (s *Service) GetAgeStatus(ctx context.Context, p auth.Principal) (AgeStatus, error) {
	return AgeStatus{}, apperr.NotImplemented("accounts.GetAgeStatus")
}

// SubmitAgeDeclaration: POST /v1/me/age/declaration — Self-declared date of birth (minimum gate; hosts are verified via KYC).
func (s *Service) SubmitAgeDeclaration(ctx context.Context, p auth.Principal, in AgeDeclarationRequest) (AgeStatus, error) {
	return AgeStatus{}, apperr.NotImplemented("accounts.SubmitAgeDeclaration")
}

// GetConsents: GET /v1/me/consents — Privacy consents (DPDP).
func (s *Service) GetConsents(ctx context.Context, p auth.Principal) (ConsentState, error) {
	return ConsentState{}, apperr.NotImplemented("accounts.GetConsents")
}

// UpdateConsents: PUT /v1/me/consents — Update privacy consents.
func (s *Service) UpdateConsents(ctx context.Context, p auth.Principal, in UpdateConsentsRequest) (ConsentState, error) {
	return ConsentState{}, apperr.NotImplemented("accounts.UpdateConsents")
}

// RequestAccountDeletion: POST /v1/me/deletion-requests — Request account deletion (records required by law are anonymised and retained).
func (s *Service) RequestAccountDeletion(ctx context.Context, p auth.Principal) (DeletionRequest, error) {
	return DeletionRequest{}, apperr.NotImplemented("accounts.RequestAccountDeletion")
}

// RequestDataExport: POST /v1/me/data-exports — Request a copy of personal data.
func (s *Service) RequestDataExport(ctx context.Context, p auth.Principal) (DataExportRequest, error) {
	return DataExportRequest{}, apperr.NotImplemented("accounts.RequestDataExport")
}
