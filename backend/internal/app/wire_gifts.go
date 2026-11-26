package app

import (
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/gifts"
	"dashuri/backend/internal/wiring"
)

// wireGifts builds the virtual-gifts module (GIFTS_ENABLED, default off).
// Admin catalogue endpoints work even while gifting is off.
func wireGifts(env wiring.Env) *gifts.Service {
	d := gifts.Deps{Rules: env.Rules, Clock: env.Clock, Enabled: env.Config.GiftsEnabled, Limits: gifts.DefaultLimits()}
	if env.Realtime != nil {
		d.Realtime = env.Realtime
	}
	if env.Pool != nil {
		d.Repo = postgres.GiftsRepo{Pool: env.Pool}
	}
	return gifts.NewService(d)
}
