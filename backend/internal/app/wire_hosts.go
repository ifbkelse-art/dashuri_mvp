package app

import (
	"dashuri/backend/internal/modules/hosts"
	"dashuri/backend/internal/wiring"
)

// wireHosts builds the hosts module from shared infrastructure.
func wireHosts(env wiring.Env) *hosts.Service {
	return hosts.NewService(hosts.Deps{Rules: env.Rules})
}
