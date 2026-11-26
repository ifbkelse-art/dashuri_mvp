package app

import (
	"log/slog"

	"dashuri/backend/internal/adapters/cashfree"
	"dashuri/backend/internal/adapters/googleplay"
	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/purchases"
	"dashuri/backend/internal/wiring"
)

// wirePurchases builds the purchases module from shared infrastructure.
func wirePurchases(env wiring.Env) *purchases.Service { return NewPurchasesService(env) }

// NewPurchasesService is also used by the money jobs (internal/jobs/money.go).
// Missing credentials leave the rail's port nil, and the service answers
// 503 play_not_configured / cashfree_not_configured.
func NewPurchasesService(env wiring.Env) *purchases.Service {
	cfg := env.Config
	d := purchases.Deps{
		Rules: env.Rules, Clock: env.Clock, PackageName: cfg.PlayPackageName,
		CashfreeEnabled: cfg.CashfreeEnabled, CashfreeReturnURL: cfg.CashfreeReturnURL,
	}
	if env.Pool != nil {
		d.Repo = postgres.PurchasesRepo{Pool: env.Pool, Tx: env.Tx, Rules: env.Rules}
	}
	if env.Realtime != nil {
		d.Events = env.Realtime
	}
	if cfg.GoogleCredentialsFile != "" && cfg.PlayPackageName != "" {
		c, err := googleplay.NewFromFile(cfg.GoogleCredentialsFile, env.HTTP)
		if err != nil {
			slog.Error("google play not configured", "err", err)
		} else {
			d.Play = c
		}
	}
	if cfg.PlayRTDNAudience != "" && cfg.PlayRTDNServiceAccount != "" {
		d.Push = &googleplay.PushVerifier{Audience: cfg.PlayRTDNAudience, Email: cfg.PlayRTDNServiceAccount}
	}
	if cfg.CashfreeClientID != "" && cfg.CashfreeClientSecret != "" {
		d.Cashfree = cashfree.New(cfg.CashfreeEnv, cfg.CashfreeClientID, cfg.CashfreeClientSecret, cfg.CashfreeAPIVersion, env.HTTP)
	}
	return purchases.NewService(d)
}
