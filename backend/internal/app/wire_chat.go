package app

import (
	"dashuri/backend/internal/modules/chat"
	"dashuri/backend/internal/wiring"
)

// wireChat builds the chat module from shared infrastructure.
func wireChat(env wiring.Env) *chat.Service {
	return chat.NewService(chat.Deps{})
}
