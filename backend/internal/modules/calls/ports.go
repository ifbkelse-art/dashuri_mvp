package calls

import (
	"context"
	"errors"
	"time"

	"dashuri/backend/internal/modules/ledger"
)

// VideoProvider is the boundary to the video SDK vendor (ADR-005). The
// Stream adapter lives in internal/adapters/stream. No other code imports a
// vendor SDK.
type VideoProvider interface {
	// CreateCall registers a 1:1 call that only these two users may join.
	CreateCall(ctx context.Context, callID, callerID, receiverID string) (providerCallID string, err error)
	// IssueToken mints a short-lived token scoped to one user and one call.
	IssueToken(ctx context.Context, userID, providerCallID string, ttl time.Duration) (token string, expiresAt time.Time, err error)
	// EndCall force-ends the provider call (low balance, moderation, timeout).
	EndCall(ctx context.Context, providerCallID string) error
	// VerifyWebhook authenticates a provider webhook and returns its events.
	VerifyWebhook(raw []byte, headers map[string]string) ([]ProviderEvent, error)
}

// Normalised provider event kinds.
const (
	EventJoined           = "participant_joined"
	EventLeft             = "participant_left"
	EventVideoPublished   = "video_published"
	EventVideoUnpublished = "video_unpublished"
	EventCallEnded        = "call_ended"
)

// ProviderEvent is a normalised server-side media event.
type ProviderEvent struct {
	EventID        string // provider event id; deduplicated
	ProviderCallID string
	UserID         string
	Kind           string // one of the Event* constants
	At             time.Time
}

// Domain errors returned by Repository implementations.
var (
	ErrNotFound            = errors.New("calls: not found")
	ErrCallerInCall        = errors.New("calls: caller already in a live call")
	ErrHostBusy            = errors.New("calls: host already in a live call")
	ErrInsufficientBalance = errors.New("calls: insufficient balance")
)

// Call is the persisted call row.
type Call struct {
	ID, CallerID, ReceiverID string
	Phase                    Phase
	RatePerMinute            int64
	IsFreeCall               bool
	ProviderCallID           string
	RuleSetVersion           string
	EndReason                *string
	BilledSeconds            *int64
	DiamondsCharged          *int64
	CreatedAt                time.Time
	AcceptedAt               *time.Time
	ConnectedAt              *time.Time
	EndedAt                  *time.Time
	ModerationWindowEndsAt   *time.Time
	LastEventAt              *time.Time
	LowBalanceNotifiedAt     *time.Time
	FreeCallCompensated      bool
	BeansEarned              *int64 // from the settlement; nil until settled
}

// Participant reports whether the user is in the call.
func (c Call) Participant(userID string) bool { return userID == c.CallerID || userID == c.ReceiverID }

// HostForCall is the host's call eligibility, read under a row lock.
type HostForCall struct {
	Exists        bool
	State         string
	Available     bool
	RatePerMinute int64
	AccountStatus string
	AgeEligible   bool
}

// Reservation is a ledger.diamond_reservations row.
type Reservation struct {
	ID     string
	UserID string
	CallID string
	Amount int64
	Status string
}

// PhaseUpdate holds the optional columns written with a phase change.
type PhaseUpdate struct {
	AcceptedAt, ConnectedAt, ModerationWindowEndsAt, EndedAt *time.Time
	EndReason                                                *string
	BilledSeconds, DiamondsCharged                           *int64
}

// Settlement is a calls.settlements row.
type Settlement struct {
	CallID          string
	EntryID         *string
	BilledSeconds   int64
	DiamondsCharged int64
	BeansEarned     int64
}

// Peer is the other participant's public info.
type Peer struct {
	UserID      string  `json:"user_id"`
	DisplayName string  `json:"display_name"`
	PhotoURL    *string `json:"photo_url"`
}

// PeerPhotos resolves a signed URL of each user's first approved profile
// photo (identity.profile_photos in a private bucket). Users without one are
// missing from the map. Implemented outside the module; optional.
type PeerPhotos interface {
	FirstPhotoURLs(ctx context.Context, userIDs []string) map[string]string
}

// MediaEvent is a stored calls.media_events row.
type MediaEvent struct {
	UserID string
	Kind   string
	At     time.Time
}

// Repository persists calls, reservations, media events and settlements.
// The SQL enforces one live call per user (unique partial indexes),
// optimistic phase transitions and one settlement per call.
type Repository interface {
	InTx(ctx context.Context, fn func(Tx) error) error
	GetCall(ctx context.Context, id string) (Call, error)
	History(ctx context.Context, userID string, beforeAt *time.Time, beforeID string, limit int) ([]Call, error)
	Peers(ctx context.Context, ids []string) (map[string]Peer, error)
	MediaEvents(ctx context.Context, callID string) ([]MediaEvent, error)
	// InsertMediaEvent stores an event once (false when already seen) and
	// bumps calls.last_event_at.
	InsertMediaEvent(ctx context.Context, callID string, e ProviderEvent) (bool, error)
	// LiveCalls lists calls in a non-terminal phase (oldest first).
	LiveCalls(ctx context.Context, limit int) ([]Call, error)
}

// Tx is the set of operations available inside one database transaction.
type Tx interface {
	LockCall(id string) (Call, error)
	LockHost(hostID string) (HostForCall, error)
	Blocked(a, b string) (bool, error)
	InLiveCall(userID string) (bool, error)
	// LockDiamonds locks the user's Diamond buckets (ascending account id)
	// and returns (promotional, purchased).
	LockDiamonds(userID string) (promo, purchased int64, err error)
	ActiveReservationsTotal(userID string) (int64, error)
	LockReservation(callID string) (Reservation, bool, error)
	InsertCall(c Call) error
	InsertReservation(userID, callID string, amount int64) error
	SetReservationAmount(callID string, amount int64) error
	CloseReservation(callID, status string) error
	UpdatePhase(id string, from, to Phase, u PhaseUpdate) (bool, error)
	MediaEvents(callID string) ([]MediaEvent, error)
	PostEntry(e ledger.Entry) (entryID string, replayed bool, err error)
	InsertSettlement(s Settlement) error
	GrantXP(userID, sourceType, sourceID string, delta int64) error
	SetLowBalanceNotified(callID string, at time.Time) error
	MarkFreeCallCompensated(callID string) error
	// ReleaseFreeCard gives the caller's Free Call Card back (and the host's
	// daily slot) when a free call ends without ever connecting.
	ReleaseFreeCard(callID string) error
}

// RealtimePublisher pushes server events to private channels
// (`user:<id>`, `call:<id>`) through Supabase Realtime broadcast (ADR-006).
type RealtimePublisher interface {
	Publish(ctx context.Context, channel, event string, payload any) error
}
