package app

import (
	"dashuri/backend/internal/modules/discovery"
	"dashuri/backend/internal/wiring"
)

// wireDiscovery builds the discovery module from shared infrastructure.
func wireDiscovery(env wiring.Env) *discovery.Service {
	return discovery.NewService(discovery.Deps{})
}
