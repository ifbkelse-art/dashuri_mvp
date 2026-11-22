package app

import (
	"context"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/chat"
	"dashuri/backend/internal/modules/notifications"
	"dashuri/backend/internal/wiring"
)

// wireChat builds the chat module from shared infrastructure.
func wireChat(env wiring.Env) *chat.Service {
	d := chat.Deps{Realtime: env.Realtime, Photos: profilePhotoStorage(env),
		MessageContext: env.Config.ChatMessageContextEnabled} // EXPERIMENT: unified/in-call chat
	if env.Pool != nil {
		d.Repo = postgres.ChatRepo{Pool: env.Pool, MessageContext: env.Config.ChatMessageContextEnabled}
		notifier := wireNotifier(env)
		d.Push = func(ctx context.Context, recipientID, conversationID string) {
			// Data-light push: no message text leaves the server in a push.
			notifier.PushOnly(ctx, recipientID, notifications.Push{
				Kind: "message", Title: "New message", Body: "You have a new message on Dashuri",
				Data: map[string]string{"conversation_id": conversationID},
			})
		}
	}
	return chat.NewService(d)
}
