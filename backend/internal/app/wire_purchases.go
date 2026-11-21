package app

import (
	"dashuri/backend/internal/modules/purchases"
	"dashuri/backend/internal/wiring"
)

// wirePurchases builds the purchases module from shared infrastructure.
func wirePurchases(env wiring.Env) *purchases.Service {
	return purchases.NewService(purchases.Deps{Rules: env.Rules, PackageName: env.Config.PlayPackageName})
}
