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
	SetRate(ctx context.Context, userID string, rate int64) error
	SetFreeCallOptIn(ctx context.Context, userID string, optIn bool) error
	DecideKyc(ctx context.Context, d KycDecision) error
}

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
