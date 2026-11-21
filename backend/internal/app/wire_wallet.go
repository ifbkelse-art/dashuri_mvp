package app

import (
	"dashuri/backend/internal/modules/wallet"
	"dashuri/backend/internal/wiring"
)

// wireWallet builds the wallet module from shared infrastructure.
func wireWallet(env wiring.Env) *wallet.Service {
	return wallet.NewService(wallet.Deps{})
}
