package app

import (
	"dashuri/backend/internal/modules/accounts"
	"dashuri/backend/internal/wiring"
)

// wireAccounts builds the accounts module from shared infrastructure.
func wireAccounts(env wiring.Env) *accounts.Service {
	return accounts.NewService(accounts.Deps{})
}
