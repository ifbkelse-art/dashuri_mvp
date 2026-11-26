package app

import (
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/admin"
	"dashuri/backend/internal/wiring"
)

// wireAdmin builds the admin (finance) module from shared infrastructure.
func wireAdmin(env wiring.Env) *admin.Service { return NewAdminService(env) }

// NewAdminService is also used by the reconcile-ledger job.
func NewAdminService(env wiring.Env) *admin.Service {
	d := admin.Deps{Rules: env.Rules, Clock: env.Clock, PayoutsEnabled: env.Config.PayoutsEnabled}
	if env.Pool != nil {
		d.Repo = postgres.AdminRepo{Pool: env.Pool, Tx: env.Tx}
		d.Console = postgres.AdminConsoleRepo{Pool: env.Pool}
	}
	return admin.NewService(d)
}
