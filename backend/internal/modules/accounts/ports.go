package accounts

import (
	"context"
	"errors"
	"time"

	"dashuri/backend/internal/modules/keyset"
)

// Sentinel errors returned by the Repository; the service maps them.
var (
	ErrNotFound            = errors.New("accounts: not found")
	ErrDisplayNameRequired = errors.New("accounts: display name required to create a profile")
	ErrUnknownCity         = errors.New("accounts: unknown city")
	ErrPhotoLimit          = errors.New("accounts: photo limit reached")
	ErrDeclarationLocked   = errors.New("accounts: date of birth already recorded")
	ErrPendingBalance      = errors.New("accounts: beans held, available or pending payout, or a live call")
	ErrPhotoNotPending     = errors.New("accounts: photo is not pending review")
)

// PendingPhoto is one photo in the moderation queue.
type PendingPhoto struct {
	PhotoID   string
	UserID    string
	Path      string
	CreatedAt time.Time
}

// SlotPolicy decides which pending photos still hold an upload slot.
// Uploaded lists the user's objects in Storage; nil means unknown (Storage
// unreachable), in which case every pending photo counts.
type SlotPolicy struct {
	Uploaded  map[string]bool
	TicketTTL time.Duration
}

// AccountRow is the account state behind GET /v1/me.
type AccountRow struct {
	UserID       string
	Status       string
	AgeEligible  bool
	AgeMethod    *string
	DateOfBirth  *time.Time
	RulesVersion *string
	HostState    *string
	DisplayName  *string // nil without a profile row
	Gender       *string
	CreatedAt    time.Time
}

// ProfileRow is a profile with the data needed to render it.
type ProfileRow struct {
	UserID      string
	DisplayName string
	Bio         *string
	Languages   []string
	Gender      *string
	City        *City
	HostState   *string
	LifetimeXP  int64
	PhotoPaths  []string // storage paths, ordered by position
}

// ProfileUpdate is a partial update; nil / unset fields stay unchanged.
type ProfileUpdate struct {
	DisplayName *string
	SetBio      bool
	Bio         *string
	Languages   []string // nil = unchanged
	Gender      *string
	SetCity     bool
	CityID      *string
}

// Repository is the identity.* persistence port.
type Repository interface {
	Account(ctx context.Context, userID string) (AccountRow, error)
	// OwnProfile returns the caller's profile with approved and pending photos.
	OwnProfile(ctx context.Context, userID string) (ProfileRow, error)
	// PublicProfile returns ErrNotFound when the profile is missing, the
	// account is not active/restricted, or a block exists either way.
	PublicProfile(ctx context.Context, viewerID, userID string) (ProfileRow, error)
	UpdateProfile(ctx context.Context, userID string, u ProfileUpdate) error
	AcceptRules(ctx context.Context, userID, version string) error
	// CreatePhoto locks the account, enforces max live photos, calls sign
	// for the new object path and records a pending_review photo.
	// Pending photos whose ticket is older than policy.TicketTTL and whose
	// object was never uploaded are deleted first and free their slot.
	CreatePhoto(ctx context.Context, userID, photoID, path string, max int, policy SlotPolicy, sign func(path string) (string, error)) (uploadURL string, err error)
	// DeletePhoto removes the user's own photo row and returns its path.
	DeletePhoto(ctx context.Context, userID, photoID string) (path string, err error)
	// ListPendingPhotos is the moderation queue, oldest first.
	ListPendingPhotos(ctx context.Context, after *keyset.Cursor, limit int) ([]PendingPhoto, error)
	// PendingPhoto returns one pending photo (ErrNotFound / ErrPhotoNotPending).
	PendingPhoto(ctx context.Context, photoID string) (PendingPhoto, error)
	// DecidePhoto sets approved/rejected on a pending photo and writes an
	// audit.events row for the moderator, atomically.
	DecidePhoto(ctx context.Context, moderatorID, photoID string, approve bool, reason *string) error
	// Audit appends an audit.events row (staff access).
	Audit(ctx context.Context, actor, action, target string) error
	// DeclareAge records a self-declared DOB once. Under 18 also restricts the account.
	DeclareAge(ctx context.Context, userID string, dob time.Time, eligible bool) error
	Consents(ctx context.Context, userID string) (ConsentState, error)
	SetConsents(ctx context.Context, userID string, analytics, marketing bool) (ConsentState, error)
	// RequestDeletion returns the open request if one exists, refuses with
	// ErrPendingBalance, or schedules a new one.
	RequestDeletion(ctx context.Context, userID string, scheduledFor time.Time) (DeletionRequest, error)
	RequestExport(ctx context.Context, userID string) (DataExportRequest, error)
}

// PhotoStorage signs URLs for the private profile-photos bucket.
type PhotoStorage interface {
	Configured() bool
	SignUpload(ctx context.Context, path string) (string, error)
	SignRead(ctx context.Context, paths []string, ttl time.Duration) map[string]string
	// List returns object paths under prefix ("<user id>/").
	List(ctx context.Context, prefix string, limit int) ([]string, error)
	Delete(ctx context.Context, path string) error
}
