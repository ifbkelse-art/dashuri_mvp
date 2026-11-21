package app

import (
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/location"
	"dashuri/backend/internal/wiring"
)

// wireLocation builds the coarse-location module (founder decision F4).
func wireLocation(env wiring.Env) *location.Service {
	d := location.Deps{}
	if env.Pool != nil {
		d.Repo = postgres.LocationRepo{Pool: env.Pool}
	}
	return location.NewService(d)
}
