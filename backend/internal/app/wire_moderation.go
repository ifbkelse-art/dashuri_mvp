package app

import (
	"dashuri/backend/internal/modules/moderation"
	"dashuri/backend/internal/wiring"
)

// wireModeration builds the moderation module from shared infrastructure.
func wireModeration(env wiring.Env) *moderation.Service {
	return moderation.NewService(moderation.Deps{})
}
