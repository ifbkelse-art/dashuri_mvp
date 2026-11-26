package hosts

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"time"
)

// KYCProvider is the identity-verification vendor (not chosen; Aadhaar
// offline e-KYC / DigiLocker + PAN + liveness). Raw documents stay with the
// vendor; Dashuri stores status, masked identifiers and verified DOB.
type KYCProvider interface {
	StartSession(ctx context.Context, hostID string) (sessionID, redirectURL string, err error)
	VerifyCallback(raw []byte, headers map[string]string) (KYCResult, error)
}

type KYCResult struct {
	SessionID   string
	HostID      string
	Approved    bool
	AgeVerified bool // must be 18+
	NameOnID    string
	FailureCode string
}

// HostRow is a hosting.hosts row ("Exists=false" when the user never applied).
type HostRow struct {
	Exists        bool
	State         string
	KycState      string
	IsAvailable   bool
	FreeCallOptIn bool
	RatePerMinute int64
	// KycRejectionReason is the latest rejected KYC session's reason (H08).
	KycRejectionReason *string
	// VerificationStatus is the Verified Host status (not the hosting KYC).
	VerificationStatus string
	// VerificationNote is the open info request or the latest rejection,
	// suspension or revocation reason shown to the host; nil otherwise.
	VerificationNote *string
	// Open online session (nil when offline or sessions are not enabled).
	OnlineSessionID *string
	OnlineSince     *time.Time
}

// Today is the host's activity in the current IST day.
type Today struct {
	EarnedBeans int64
	Calls       int64
}

// Balances are the host's Bean buckets.
type Balances struct {
	Held, Available, PayoutPending int64
}

// KycDecision is a moderator's manual KYC outcome.
type KycDecision struct {
	HostID      string
	ModeratorID string
	Approve     bool
	DateOfBirth time.Time
	Reason      string
	At          time.Time
}

// Domain errors returned by Repository implementations.
var (
	ErrNotFound       = errors.New("hosts: not found")
	ErrAlreadyApplied = errors.New("hosts: already applied")
	ErrInCall         = errors.New("hosts: in a live call")
	ErrNoKycSession   = errors.New("hosts: no KYC session")
)

// Repository persists hosting.* (and, for KYC approval, the verified DOB
// and host role on identity.accounts plus an audit event).
type Repository interface {
	Host(ctx context.Context, userID string) (HostRow, error)
	LifetimeXP(ctx context.Context, userID string) (int64, error)
	Today(ctx context.Context, userID string, dayStart time.Time) (Today, error)
	Balances(ctx context.Context, userID string) (Balances, error)
	Apply(ctx context.Context, userID string) error
	// StartKyc records a started session (state kyc_pending, kyc in_progress)
	// or returns the id of a session already started.
	StartKyc(ctx context.Context, userID, sessionID, provider string) (string, error)
	SetAvailability(ctx context.Context, userID string, available bool, at time.Time) error
	Heartbeat(ctx context.Context, userID string, at time.Time) error
	// UpdateRate locks the host row, reads the host's pricing state (stored
	// rate, lifetime XP, Verified Host status) in the same transaction and
	// writes the rate decide returns. Concurrent verification changes, level
	// changes and calls serialise on the same row lock.
	UpdateRate(ctx context.Context, userID string, decide func(PricingState) (int64, error)) error
	// ChangeVerification locks the host row and the host's open verification
	// application, passes the state to decide and applies the returned
	// change atomically (application row, host status, price cap, evidence
	// links and an audit.events row).
	ChangeVerification(ctx context.Context, hostID string, decide func(VerificationState) (VerificationChange, error)) (VerificationState, error)
	// Verification reads the host's verification state without locking.
	Verification(ctx context.Context, hostID string) (VerificationState, error)
	CreateEvidence(ctx context.Context, e Evidence) error
	Evidence(ctx context.Context, hostID, evidenceID string) (Evidence, error)
	VerificationQueue(ctx context.Context, statuses []string, limit int) ([]QueueItem, error)
	VerificationHistory(ctx context.Context, hostID string, limit int) ([]HistoryEvent, error)
	Audit(ctx context.Context, actor, action, target string, details map[string]any) error
	// EvidenceDueForPurge lists unpurged evidence whose retention ended:
	// evidence of applications decided (approved, rejected, revoked) before
	// decidedBefore, and uploads never attached to an application created
	// before orphanBefore.
	EvidenceDueForPurge(ctx context.Context, decidedBefore, orphanBefore time.Time, limit int) ([]Evidence, error)
	MarkEvidencePurged(ctx context.Context, evidenceID string, at time.Time) error
	SetFreeCallOptIn(ctx context.Context, userID string, optIn bool) error
	DecideKyc(ctx context.Context, d KycDecision) error
}

// PricingState is what the pricing rules need, read under the host row lock.
type PricingState struct {
	Exists             bool
	State              string // hosting approval state
	RatePerMinute      int64
	LifetimeXP         int64
	VerificationStatus string
}

// Verified reports an ACTIVE Verified Host status.
func (p PricingState) Verified() bool { return p.VerificationStatus == VerificationVerified }

// Verified Host statuses (hosting.hosts.verification_status).
const (
	VerificationNotApplied   = "not_applied"
	VerificationSubmitted    = "submitted"
	VerificationUnderReview  = "under_review"
	VerificationInfoRequired = "info_required"
	VerificationVerified     = "verified"
	VerificationRejected     = "rejected"
	VerificationSuspended    = "suspended"
	VerificationRevoked      = "revoked"
)

// Evidence is one private verification object (metadata only; the object
// itself is in the private host-verification-evidence bucket).
type Evidence struct {
	ID            string
	HostID        string
	ApplicationID *string
	Kind          string // face_video | id_document_front | id_document_back
	ContentType   string
	StoragePath   string
	CreatedAt     time.Time
	PurgedAt      *time.Time
}

// Application is a hosting.verification_applications row.
type Application struct {
	ID              string
	Status          string // submitted | under_review | info_required | approved | rejected | suspended | revoked
	SubmittedAt     time.Time
	ResubmittedAt   *time.Time
	ReviewerID      *string
	ReviewStartedAt *time.Time
	InfoRequest     *string
	DecidedBy       *string
	DecidedAt       *time.Time
	DecisionReason  *string
}

// VerificationState is a host's Verified Host state.
type VerificationState struct {
	HostExists bool
	HostState  string // hosting approval state
	Pricing    PricingState
	Status     string // hosts.verification_status
	VerifiedAt *time.Time
	Current    *Application // latest application (open or final); nil when never applied
	// Attached is the unpurged evidence linked to Current.
	Attached []Evidence
	// Pending is the host's unpurged evidence not yet linked to an application.
	Pending []Evidence
}

// VerificationChange is what ChangeVerification writes.
type VerificationChange struct {
	ActorID           string
	Action            string // audit suffix: submitted, resubmitted, review_started, info_requested, approved, rejected, suspended, reinstated, revoked
	CreateApplication bool   // a new application in status ApplicationStatus
	ApplicationStatus string // the (new or current) application's new status
	HostStatus        string // hosting.hosts.verification_status
	AttachEvidence    []string
	Reason            string // decision reason (approve optional; negative actions required)
	InfoRequest       string // request_info only
	// CapRateTo lowers the stored rate in the same transaction (revocation,
	// suspension). Nil leaves the rate untouched (approval never raises it).
	CapRateTo *int64
	At        time.Time
}

// QueueItem is one row of the admin verification queue.
type QueueItem struct {
	ApplicationID string
	HostID        string
	DisplayName   string
	Status        string
	SubmittedAt   time.Time
	LifetimeXP    int64
}

// HistoryEvent is one audited verification or pricing action on a host.
type HistoryEvent struct {
	At      time.Time
	Actor   string
	Action  string
	Details map[string]any
}

// EvidenceStore is the private evidence bucket (signed URLs only; the
// storage key never leaves the server).
type EvidenceStore interface {
	Configured() bool
	SignUpload(ctx context.Context, path string) (string, error)
	SignRead(ctx context.Context, paths []string, ttl time.Duration) map[string]string
	Delete(ctx context.Context, path string) error
}

// Errors from verification writes.
var (
	ErrNoApplication = errors.New("hosts: no verification application")
)

// ManualKYC is the MVP KYC provider: a session is opened in Dashuri and a
// moderator decides it (POST /v1/admin/hosts/{userId}/kyc-decision).
type ManualKYC struct{}

func (ManualKYC) StartSession(_ context.Context, hostID string) (string, string, error) {
	b := make([]byte, 12)
	if _, err := rand.Read(b); err != nil {
		return "", "", err
	}
	return "manual_" + hex.EncodeToString(b), "", nil
}

func (ManualKYC) VerifyCallback([]byte, map[string]string) (KYCResult, error) {
	return KYCResult{}, errors.New("manual KYC has no vendor callback")
}
