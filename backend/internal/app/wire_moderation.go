package app

import (
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/adapters/sightengine"
	"dashuri/backend/internal/modules/moderation"
	"dashuri/backend/internal/wiring"
)

// wireModeration builds the moderation module from shared infrastructure.
func wireModeration(env wiring.Env) *moderation.Service { return BuildModeration(env) }

// BuildModeration builds the moderation service (also used by jobs). The
// Sightengine classifier is nil without SIGHTENGINE_API_USER/SECRET, so
// frames return 503 moderation_not_configured while MODERATION_ENABLED.
func BuildModeration(env wiring.Env) *moderation.Service {
	d := moderation.Deps{
		Enabled:    env.Config.ModerationEnabled,
		Classifier: sightengine.New(env.Config.SightengineUser, env.Config.SightengineSecret, env.HTTP),
		Clock:      env.Clock,
		Calls:      BuildCalls(env),
		Threshold:  moderation.DefaultFlagThreshold,
	}
	if env.Pool != nil {
		d.Repo = postgres.ModerationRepo{Pool: env.Pool, Tx: env.Tx}
	}
	return moderation.NewService(d)
}
