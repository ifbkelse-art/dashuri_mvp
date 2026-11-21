package notifications

import "context"

// PushSender delivers push notifications (FCM for Android; vendor wiring TODO).
// Incoming-call pushes are high priority and carry only the call id.
type PushSender interface {
	Send(ctx context.Context, token string, msg Push) error
}

type Push struct {
	Kind  string // incoming_call | message | payout | moderation
	Data  map[string]string
	Title string
	Body  string
}
