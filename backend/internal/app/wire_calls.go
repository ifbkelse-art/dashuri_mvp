package app

import (
	"dashuri/backend/internal/modules/calls"
	"dashuri/backend/internal/wiring"
)

// wireCalls builds the calls module from shared infrastructure.
func wireCalls(env wiring.Env) *calls.Service {
	return calls.NewService(calls.Deps{Rules: env.Rules})
}
