package app

import (
	"dashuri/backend/internal/modules/admin"
	"dashuri/backend/internal/wiring"
)

// wireAdmin builds the admin module from shared infrastructure.
func wireAdmin(env wiring.Env) *admin.Service {
	return admin.NewService(admin.Deps{})
}
