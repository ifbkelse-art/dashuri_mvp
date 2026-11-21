package freecall

import (
	"context"
	"errors"
	"time"
)

// IntegrityVerifier decodes and checks a Google Play Integrity token
// server-side. The adapter is internal/adapters/playintegrity.
type IntegrityVerifier interface {
	Verify(ctx context.Context, token string) (IntegrityVerdict, error)
}

// IntegrityVerdict is a passed integrity check.
type IntegrityVerdict struct {
	// DeviceBinding is the integrity-protected request hash (standard
	// request) or nonce (classic request) the genuine app derived from the
	// device; the card is bound to its SHA-256.
	DeviceBinding string
}

// ErrIntegrityFailed means the token is invalid or the verdict is not
// acceptable (unrecognised app, device integrity not met, stale token).
var ErrIntegrityFailed = errors.New("freecall: integrity check failed")

// CallLauncher creates the provider call and rings the host for a call row
// inserted by this module (implemented by calls.Service).
type CallLauncher interface {
	LaunchCreatedCall(ctx context.Context, callID string) error
}

// CardRow is a freecall.cards row.
type CardRow struct {
	Exists bool
	Status string
	UsedAt *time.Time
}

// MatchParams is one Free Call Card use.
type MatchParams struct {
	UserID, PhoneHash, DeviceHash string
	CallID, RuleSetVersion        string
	MaxPerHostPerDay              int
	Now                           time.Time
}

// RequestRow is a freecall.requests row.
type RequestRow struct {
	ID, UserID, Status string
	CallID             *string
}

// Domain errors returned by Repository implementations.
var (
	ErrNotFound     = errors.New("freecall: not found")
	ErrCardUsed     = errors.New("freecall: card already used")
	ErrDeviceUsed   = errors.New("freecall: device already used")
	ErrCallerInCall = errors.New("freecall: caller in a live call")
)

// Repository persists freecall.* and creates the free call row.
type Repository interface {
	PhoneHash(ctx context.Context, userID string) (string, error) // "" when the account has no phone
	Card(ctx context.Context, userID string) (CardRow, error)
	PhoneUsedByOther(ctx context.Context, userID, phoneHash string) (bool, error)
	// Match runs in one transaction: lock/create the card, pick a random
	// opted-in available host with today's (IST) count below the cap under
	// FOR UPDATE, increment it, insert the free call (rate 0, ringing), mark
	// the card used and record the request. No host → no_host_available
	// (card unchanged).
	Match(ctx context.Context, m MatchParams) (RequestRow, error)
	Request(ctx context.Context, id string) (RequestRow, error)
}
