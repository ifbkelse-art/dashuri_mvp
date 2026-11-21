package app

import (
	"dashuri/backend/internal/modules/levels"
	"dashuri/backend/internal/wiring"
)

// wireLevels builds the levels module from shared infrastructure.
func wireLevels(env wiring.Env) *levels.Service {
	return levels.NewService(levels.Deps{Rules: env.Rules})
}
