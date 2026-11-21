package calls

import (
	"context"
	"time"
)

// VideoProvider is the boundary to the video SDK vendor (ADR-005). The
// Stream adapter lives in internal/adapters/stream (TODO). No other code
// imports a vendor SDK.
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

// ProviderEvent is a normalised server-side media event.
type ProviderEvent struct {
	EventID        string // provider event id; deduplicated
	ProviderCallID string
	UserID         string
	Kind           string // participant_joined | participant_left | video_published | video_unpublished | call_ended
	At             time.Time
}

// Repository persists calls, reservations, media events and settlements.
// Implementations must enforce in SQL: one active call per user (unique
// partial index), optimistic phase transitions, unique settlement per call.
type Repository interface {
	// Implemented with the Postgres schema in supabase/migrations (TODO).
}

// RealtimePublisher pushes server events to private channels
// (`user:<id>`, `call:<id>`) through Supabase Realtime broadcast (ADR-006).
type RealtimePublisher interface {
	Publish(ctx context.Context, channel, event string, payload any) error
}
