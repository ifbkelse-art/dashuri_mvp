package app

import (
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/wallet"
	"dashuri/backend/internal/wiring"
)

// wireWallet builds the wallet module from shared infrastructure.
func wireWallet(env wiring.Env) *wallet.Service {
	d := wallet.Deps{}
	if env.Pool != nil {
		d.Repo = postgres.WalletRepo{Pool: env.Pool}
	}
	return wallet.NewService(d)
}
