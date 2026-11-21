package app

import (
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/safety"
	"dashuri/backend/internal/wiring"
)

// wireSafety builds the safety module from shared infrastructure.
func wireSafety(env wiring.Env) *safety.Service {
	d := safety.Deps{Clock: env.Clock}
	if env.Pool != nil {
		d.Repo = postgres.SafetyRepo{Pool: env.Pool}
	}
	return safety.NewService(d)
}
