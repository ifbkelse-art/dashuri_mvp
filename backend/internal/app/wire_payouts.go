package app

import (
	"dashuri/backend/internal/modules/payouts"
	"dashuri/backend/internal/wiring"
)

// wirePayouts builds the payouts module from shared infrastructure.
func wirePayouts(env wiring.Env) *payouts.Service {
	return payouts.NewService(payouts.Deps{Rules: env.Rules, Enabled: env.Config.PayoutsEnabled})
}
