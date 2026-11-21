package app

import (
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/payouts"
	"dashuri/backend/internal/wiring"
)

// wirePayouts builds the payouts module from shared infrastructure.
// No PayoutProvider adapter exists: none has been chosen (R3-7), so
// PAYOUTS_ENABLED must stay false and requests return 503 payouts_not_enabled.
func wirePayouts(env wiring.Env) *payouts.Service {
	d := payouts.Deps{Rules: env.Rules, Enabled: env.Config.PayoutsEnabled, Clock: env.Clock}
	if env.Pool != nil {
		d.Repo = postgres.PayoutsRepo{Pool: env.Pool, Tx: env.Tx}
	}
	return payouts.NewService(d)
}
