package app

import (
	"dashuri/backend/internal/modules/notifications"
	"dashuri/backend/internal/wiring"
)

// wireNotifications builds the notifications module from shared infrastructure.
func wireNotifications(env wiring.Env) *notifications.Service {
	return notifications.NewService(notifications.Deps{})
}
