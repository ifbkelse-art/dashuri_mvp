package app

import (
	"dashuri/backend/internal/modules/safety"
	"dashuri/backend/internal/wiring"
)

// wireSafety builds the safety module from shared infrastructure.
func wireSafety(env wiring.Env) *safety.Service {
	return safety.NewService(safety.Deps{})
}
