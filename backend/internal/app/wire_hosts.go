package app

import (
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/hosts"
	"dashuri/backend/internal/wiring"
)

// wireHosts builds the hosts module from shared infrastructure. KYC uses the
// manual provider (a moderator decides) until a vendor is chosen.
func wireHosts(env wiring.Env) *hosts.Service {
	d := hosts.Deps{Rules: env.Rules, KYC: hosts.ManualKYC{}, Clock: env.Clock}
	if env.Pool != nil {
		d.Repo = postgres.HostsRepo{Pool: env.Pool, Tx: env.Tx}
	}
	return hosts.NewService(d)
}
