package app

import (
	"dashuri/backend/internal/adapters/fcm"
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/notifications"
	"dashuri/backend/internal/wiring"
)

// pushSender is FCM HTTP v1 when GOOGLE_APPLICATION_CREDENTIALS is set,
// otherwise a sender that logs at debug level and skips.
func pushSender(env wiring.Env) notifications.PushSender {
	return fcm.New(env.Config.FCMProjectID, env.Config.GoogleCredentialsFile, env.HTTP)
}

// wireNotifier builds the reusable Notifier (inbox + notification.created +
// push). Other modules use it through a port they declare; wire it here.
func wireNotifier(env wiring.Env) notifications.Notifier {
	n := notifications.Notifier{Push: pushSender(env), Realtime: env.Realtime}
	if env.Pool != nil {
		n.Repo = postgres.NotificationsRepo{Pool: env.Pool}
	}
	return n
}

// wireNotifications builds the notifications module from shared infrastructure.
func wireNotifications(env wiring.Env) *notifications.Service {
	d := notifications.Deps{Push: pushSender(env)}
	if env.Pool != nil {
		d.Repo = postgres.NotificationsRepo{Pool: env.Pool}
	}
	return notifications.NewService(d)
}
