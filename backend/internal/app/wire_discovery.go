package app

import (
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/discovery"
	"dashuri/backend/internal/wiring"
)

// wireDiscovery builds the discovery module from shared infrastructure.
func wireDiscovery(env wiring.Env) *discovery.Service {
	d := discovery.Deps{Photos: profilePhotoStorage(env), Rules: env.Rules, Clock: env.Clock}
	if env.Pool != nil {
		d.Repo = postgres.DiscoveryRepo{Pool: env.Pool}
	}
	return discovery.NewService(d)
}
