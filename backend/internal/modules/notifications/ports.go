package notifications

import (
	"context"
	"errors"

	"dashuri/backend/internal/modules/keyset"
)

// PushSender delivers push notifications (FCM HTTP v1 adapter in
// internal/adapters/fcm). Incoming-call pushes are high priority and carry
// only the call id.
type PushSender interface {
	Send(ctx context.Context, token string, msg Push) error
}

// ErrTokenUnregistered is returned by a PushSender when the device token is
// no longer valid; the Notifier then forgets the device.
var ErrTokenUnregistered = errors.New("push: device token unregistered")

type Push struct {
	Kind  string // incoming_call | message | payout | moderation | ...
	Data  map[string]string
	Title string
	Body  string
}

// Cursor is the keyset position for the inbox.
type Cursor = keyset.Cursor

// ErrNotFound: no such notification for this user.
var ErrNotFound = errors.New("notifications: not found")

// Repository is the notify.* persistence port.
type Repository interface {
	UpsertDevice(ctx context.Context, userID, token, platform string) error
	DeleteDevice(ctx context.Context, userID, token string) error
	DeviceTokens(ctx context.Context, userID string) ([]string, error)
	ForgetToken(ctx context.Context, token string) error
	InsertInbox(ctx context.Context, userID, kind, title, body string) (InboxItem, error)
	ListInbox(ctx context.Context, userID string, after *Cursor, limit int) ([]InboxItem, error)
	// MarkRead returns ErrNotFound when the item is not the user's.
	MarkRead(ctx context.Context, userID, id string) error
}

// Publisher pushes Realtime hints (wiring.Publisher).
type Publisher interface {
	Publish(ctx context.Context, channel, event string, payload any) error
}
