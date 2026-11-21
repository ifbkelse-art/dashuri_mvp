package app

import (
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/levels"
	"dashuri/backend/internal/wiring"
)

// wireLevels builds the levels module from shared infrastructure.
func wireLevels(env wiring.Env) *levels.Service {
	d := levels.Deps{Rules: env.Rules}
	if env.Pool != nil {
		d.Repo = postgres.LevelsRepo{Pool: env.Pool}
	}
	return levels.NewService(d)
}
