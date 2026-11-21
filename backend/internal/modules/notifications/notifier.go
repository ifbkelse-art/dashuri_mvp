package notifications

import (
	"context"
	"errors"
	"log/slog"
)

// EventNotificationCreated is published to user:<id> for every inbox item.
const EventNotificationCreated = "notification.created"

// Notification is one in-app notification (plus push).
type Notification struct {
	Kind  string
	Title string
	Body  string
	Data  map[string]string // push data only; not stored
}

// Notifier is the reusable entry point for other modules (via a port they
// declare and internal/app wires): it stores an inbox item, publishes
// notification.created and sends a push to every registered device.
type Notifier struct {
	Repo     Repository
	Push     PushSender // nil: push skipped
	Realtime Publisher  // nil: hint skipped
}

// Notify stores the item, then (after commit) sends the hint and pushes.
// Hint and push failures are logged and never fail the call.
func (n Notifier) Notify(ctx context.Context, userID string, note Notification) (InboxItem, error) {
	if n.Repo == nil {
		return InboxItem{}, errors.New("notifications: database not configured")
	}
	item, err := n.Repo.InsertInbox(ctx, userID, note.Kind, note.Title, note.Body)
	if err != nil {
		return InboxItem{}, err
	}
	if n.Realtime != nil {
		if err := n.Realtime.Publish(ctx, "user:"+userID, EventNotificationCreated,
			map[string]string{"notification_id": item.Id, "kind": item.Kind}); err != nil {
			slog.WarnContext(ctx, "notification hint failed", "err", err)
		}
	}
	data := map[string]string{"notification_id": item.Id}
	for k, v := range note.Data {
		data[k] = v
	}
	n.PushOnly(ctx, userID, Push{Kind: note.Kind, Title: note.Title, Body: note.Body, Data: data})
	return item, nil
}

// PushOnly sends a push to all of the user's devices without an inbox item
// (incoming calls, chat messages). Best effort.
func (n Notifier) PushOnly(ctx context.Context, userID string, msg Push) {
	if n.Push == nil || n.Repo == nil {
		return
	}
	tokens, err := n.Repo.DeviceTokens(ctx, userID)
	if err != nil {
		slog.WarnContext(ctx, "push: device lookup failed", "err", err)
		return
	}
	if msg.Data == nil {
		msg.Data = map[string]string{}
	}
	msg.Data["kind"] = msg.Kind
	for _, t := range tokens {
		err := n.Push.Send(ctx, t, msg)
		switch {
		case errors.Is(err, ErrTokenUnregistered):
			if err := n.Repo.ForgetToken(ctx, t); err != nil {
				slog.WarnContext(ctx, "push: forget token failed", "err", err)
			}
		case err != nil:
			slog.WarnContext(ctx, "push send failed", "kind", msg.Kind, "err", err)
		}
	}
}
