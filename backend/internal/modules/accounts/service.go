package accounts

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"time"

	"dashuri/backend/internal/modules/textfilter"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/clock"
)

const (
	// CurrentRulesVersion is the community-rules version the app must accept.
	CurrentRulesVersion = "2026-11"
	// MaxPhotos is the number of live (pending or approved) profile photos.
	MaxPhotos = 6
	// PhotoReadTTL is the lifetime of signed photo read URLs.
	PhotoReadTTL = time.Hour
	// DeletionGrace is the delay before a deletion request is executed (D-21).
	DeletionGrace = 7 * 24 * time.Hour
	// UploadTicketTTL matches Supabase's fixed signed-upload lifetime.
	UploadTicketTTL = 2 * time.Hour
)

// Service implements the accounts use cases.
type Service struct {
	deps Deps
}

func NewService(d Deps) *Service {
	if d.Clock == nil {
		d.Clock = clock.System{}
	}
	return &Service{deps: d}
}

func (s *Service) repo() (Repository, error) {
	if s.deps.Repo == nil {
		return nil, apperr.Unavailable("database_unavailable", "database not configured")
	}
	return s.deps.Repo, nil
}

func internal(err error) error {
	if apperr.As(err) != nil {
		return err
	}
	return apperr.Internal(err)
}

// GetMe: GET /v1/me — account status for route guards.
func (s *Service) GetMe(ctx context.Context, p auth.Principal) (AccountStatus, error) {
	repo, err := s.repo()
	if err != nil {
		return AccountStatus{}, err
	}
	a, err := repo.Account(ctx, p.UserID)
	if err != nil {
		return AccountStatus{}, internal(err)
	}
	return statusFrom(a), nil
}

func statusFrom(a AccountRow) AccountStatus {
	st := AccountStatus{
		UserId:          a.UserID,
		AgeEligible:     a.AgeEligible,
		HostState:       a.HostState,
		IsHost:          a.HostState != nil && *a.HostState == "approved",
		ProfileComplete: a.DisplayName != nil && *a.DisplayName != "" && a.Gender != nil,
		RulesAccepted:   a.RulesVersion != nil && *a.RulesVersion == CurrentRulesVersion,
	}
	if a.Status == "restricted" {
		r := "restricted"
		if a.DateOfBirth != nil && !a.AgeEligible {
			r = "under_18"
		}
		st.Restriction = &r
	}
	return st
}

// AcceptRules: POST /v1/me/rules-acceptance.
func (s *Service) AcceptRules(ctx context.Context, p auth.Principal, in RulesAcceptanceRequest) (AccountStatus, error) {
	if in.Version != CurrentRulesVersion {
		return AccountStatus{}, apperr.BusinessRule("rules_version_outdated", "accept the current community rules version "+CurrentRulesVersion)
	}
	repo, err := s.repo()
	if err != nil {
		return AccountStatus{}, err
	}
	if err := repo.AcceptRules(ctx, p.UserID, in.Version); err != nil {
		return AccountStatus{}, internal(err)
	}
	return s.GetMe(ctx, p)
}

func (s *Service) profileFrom(ctx context.Context, row ProfileRow, own bool) Profile {
	out := Profile{
		UserId: row.UserID, DisplayName: row.DisplayName, Bio: row.Bio, Languages: row.Languages,
		PhotoUrls: []string{}, IsHost: row.HostState != nil && *row.HostState == "approved",
		Level: s.deps.Rules.LevelForXP(row.LifetimeXP), City: row.City,
	}
	if out.Languages == nil {
		out.Languages = []string{}
	}
	if own {
		out.Gender = row.Gender
	}
	if s.deps.Storage != nil && len(row.PhotoPaths) > 0 {
		signed := s.deps.Storage.SignRead(ctx, row.PhotoPaths, PhotoReadTTL)
		for _, path := range row.PhotoPaths {
			if u, ok := signed[path]; ok {
				out.PhotoUrls = append(out.PhotoUrls, u)
			}
		}
	}
	return out
}

// GetMyProfile: GET /v1/me/profile. 404 until the profile is created.
func (s *Service) GetMyProfile(ctx context.Context, p auth.Principal) (Profile, error) {
	repo, err := s.repo()
	if err != nil {
		return Profile{}, err
	}
	row, err := repo.OwnProfile(ctx, p.UserID)
	if errors.Is(err, ErrNotFound) {
		return Profile{}, apperr.NotFound("profile")
	}
	if err != nil {
		return Profile{}, internal(err)
	}
	return s.profileFrom(ctx, row, true), nil
}

// UpdateMyProfile: PATCH /v1/me/profile. Creates the profile on first call
// (display_name required then). Display name and bio are screened for
// contact details (409 profile_text_rejected).
func (s *Service) UpdateMyProfile(ctx context.Context, p auth.Principal, in UpdateProfileRequest) (Profile, error) {
	in.normalize()
	if errs := in.validate(); len(errs) > 0 {
		return Profile{}, validationError(errs)
	}
	if in.DisplayName != nil && textfilter.ContainsContactDetails(*in.DisplayName) {
		return Profile{}, apperr.BusinessRule("profile_text_rejected", "display_name contains contact details")
	}
	if in.Bio.Value != nil && textfilter.ContainsContactDetails(*in.Bio.Value) {
		return Profile{}, apperr.BusinessRule("profile_text_rejected", "bio contains contact details")
	}
	repo, err := s.repo()
	if err != nil {
		return Profile{}, err
	}
	u := ProfileUpdate{
		DisplayName: in.DisplayName, SetBio: in.Bio.Set, Bio: in.Bio.Value,
		Languages: in.Languages, Gender: in.Gender, SetCity: in.CityId.Set, CityID: in.CityId.Value,
	}
	switch err := repo.UpdateProfile(ctx, p.UserID, u); {
	case errors.Is(err, ErrDisplayNameRequired):
		return Profile{}, validationError(map[string]string{"display_name": "required"})
	case errors.Is(err, ErrUnknownCity):
		return Profile{}, validationError(map[string]string{"city_id": "unknown_city"})
	case err != nil:
		return Profile{}, internal(err)
	}
	return s.GetMyProfile(ctx, p)
}

// GetProfile: GET /v1/profiles/{userId}. Public view: no gender, approved
// photos only; 404 when missing, inactive or blocked either way.
func (s *Service) GetProfile(ctx context.Context, p auth.Principal, userId string) (Profile, error) {
	if !isUUID(userId) {
		return Profile{}, apperr.NotFound("profile")
	}
	repo, err := s.repo()
	if err != nil {
		return Profile{}, err
	}
	row, err := repo.PublicProfile(ctx, p.UserID, userId)
	if errors.Is(err, ErrNotFound) {
		return Profile{}, apperr.NotFound("profile")
	}
	if err != nil {
		return Profile{}, internal(err)
	}
	return s.profileFrom(ctx, row, false), nil
}

// RequestPhotoUpload: POST /v1/me/photos/upload-tickets. Signed upload URL
// for the private profile-photos bucket; the photo starts pending_review.
func (s *Service) RequestPhotoUpload(ctx context.Context, p auth.Principal, in PhotoUploadTicketRequest) (PhotoUploadTicket, error) {
	if errs := in.validate(); len(errs) > 0 {
		return PhotoUploadTicket{}, validationError(errs)
	}
	if s.deps.Storage == nil || !s.deps.Storage.Configured() {
		return PhotoUploadTicket{}, apperr.Unavailable("storage_not_configured", "photo storage is not configured on the server")
	}
	repo, err := s.repo()
	if err != nil {
		return PhotoUploadTicket{}, err
	}
	photoID := newUUID()
	path := fmt.Sprintf("%s/%s.%s", p.UserID, photoID, photoExtensions[in.ContentType])
	now := s.deps.Clock.Now()
	url, err := repo.CreatePhoto(ctx, p.UserID, photoID, path, MaxPhotos, s.slotPolicy(ctx, p.UserID), func(path string) (string, error) {
		return s.deps.Storage.SignUpload(ctx, path)
	})
	switch {
	case errors.Is(err, ErrPhotoLimit):
		return PhotoUploadTicket{}, apperr.BusinessRule("photo_limit_reached", fmt.Sprintf("at most %d photos", MaxPhotos))
	case err != nil:
		return PhotoUploadTicket{}, internal(err)
	}
	return PhotoUploadTicket{PhotoId: photoID, UploadUrl: url, ExpiresAt: now.Add(UploadTicketTTL), Status: "pending_review"}, nil
}

// GetAgeStatus: GET /v1/me/age.
func (s *Service) GetAgeStatus(ctx context.Context, p auth.Principal) (AgeStatus, error) {
	repo, err := s.repo()
	if err != nil {
		return AgeStatus{}, err
	}
	a, err := repo.Account(ctx, p.UserID)
	if err != nil {
		return AgeStatus{}, internal(err)
	}
	return AgeStatus{Eligible: a.AgeEligible, Method: a.AgeMethod, Declared: a.DateOfBirth != nil}, nil
}

// SubmitAgeDeclaration: POST /v1/me/age/declaration. One declaration per
// account (409 declaration_locked). Under 18 records the DOB, marks the
// account restricted and ineligible, and returns 409 under_18.
func (s *Service) SubmitAgeDeclaration(ctx context.Context, p auth.Principal, in AgeDeclarationRequest) (AgeStatus, error) {
	today := todayIST(s.deps.Clock.Now())
	dob, errs := in.parse(today)
	if len(errs) > 0 {
		return AgeStatus{}, validationError(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return AgeStatus{}, err
	}
	eligible := AgeOn(dob, today) >= 18
	switch err := repo.DeclareAge(ctx, p.UserID, dob, eligible); {
	case errors.Is(err, ErrDeclarationLocked):
		return AgeStatus{}, apperr.BusinessRule("declaration_locked", "date of birth was already declared")
	case err != nil:
		return AgeStatus{}, internal(err)
	}
	if !eligible {
		return AgeStatus{}, apperr.BusinessRule("under_18", "Dashuri is only for adults (18+)")
	}
	method := "self_declared"
	return AgeStatus{Eligible: true, Method: &method, Declared: true}, nil
}

// GetConsents: GET /v1/me/consents (defaults: everything off).
func (s *Service) GetConsents(ctx context.Context, p auth.Principal) (ConsentState, error) {
	repo, err := s.repo()
	if err != nil {
		return ConsentState{}, err
	}
	c, err := repo.Consents(ctx, p.UserID)
	return c, internalOrNil(err)
}

// UpdateConsents: PUT /v1/me/consents.
func (s *Service) UpdateConsents(ctx context.Context, p auth.Principal, in UpdateConsentsRequest) (ConsentState, error) {
	if errs := in.validate(); len(errs) > 0 {
		return ConsentState{}, validationError(errs)
	}
	repo, err := s.repo()
	if err != nil {
		return ConsentState{}, err
	}
	c, err := repo.SetConsents(ctx, p.UserID, *in.Analytics, *in.Marketing)
	return c, internalOrNil(err)
}

// RequestAccountDeletion: POST /v1/me/deletion-requests. Refused (409
// pending_balance_or_payout) while Beans are held, available or pending
// payout, or during a live call; otherwise scheduled after 7 days (D-21).
func (s *Service) RequestAccountDeletion(ctx context.Context, p auth.Principal) (DeletionRequest, error) {
	repo, err := s.repo()
	if err != nil {
		return DeletionRequest{}, err
	}
	d, err := repo.RequestDeletion(ctx, p.UserID, s.deps.Clock.Now().Add(DeletionGrace))
	if errors.Is(err, ErrPendingBalance) {
		return DeletionRequest{}, apperr.BusinessRule("pending_balance_or_payout",
			"withdraw or wait for your Beans to settle, and end any live call, before deleting the account")
	}
	return d, internalOrNil(err)
}

// RequestDataExport: POST /v1/me/data-exports.
func (s *Service) RequestDataExport(ctx context.Context, p auth.Principal) (DataExportRequest, error) {
	repo, err := s.repo()
	if err != nil {
		return DataExportRequest{}, err
	}
	d, err := repo.RequestExport(ctx, p.UserID)
	return d, internalOrNil(err)
}

func internalOrNil(err error) error {
	if err == nil {
		return nil
	}
	return internal(err)
}

func newUUID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}
