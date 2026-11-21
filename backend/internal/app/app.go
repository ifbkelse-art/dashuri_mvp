// Package app is the composition root: it builds every module with its
// dependencies and mounts them on one router (modular monolith, ADR-003).
package app

import (
	"context"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/accounts"
	"dashuri/backend/internal/modules/admin"
	"dashuri/backend/internal/modules/calls"
	"dashuri/backend/internal/modules/chat"
	"dashuri/backend/internal/modules/discovery"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/freecall"
	"dashuri/backend/internal/modules/hosts"
	"dashuri/backend/internal/modules/levels"
	"dashuri/backend/internal/modules/moderation"
	"dashuri/backend/internal/modules/notifications"
	"dashuri/backend/internal/modules/payouts"
	"dashuri/backend/internal/modules/purchases"
	"dashuri/backend/internal/modules/safety"
	"dashuri/backend/internal/modules/wallet"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/config"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/ratelimit"
	"dashuri/backend/internal/platform/routing"
)

// New builds the HTTP handler. pool may be nil in development without a database.
func New(cfg config.Config, pool *pgxpool.Pool) http.Handler {
	rules := economy.Founder() // TODO: load the active rule set from economy.rule_sets
	verifier := auth.JWKSVerifier{JWKSURL: cfg.SupabaseJWKSURL, Issuer: cfg.SupabaseIssuer, Audience: "authenticated"}
	limiter := ratelimit.NewTokenBucket(5, 20)
	authMW := auth.Middleware(verifier, postgres.RoleSource{Pool: pool})

	stack := routing.Stack{
		User: func(h http.HandlerFunc) http.Handler {
			return authMW(ratelimit.PerUser(limiter, h))
		},
		Webhook:     func(h http.HandlerFunc) http.Handler { return h },
		Idempotency: postgres.IdempotencyStore{Pool: pool},
	}

	mux := http.NewServeMux()
	accounts.Routes(mux, accounts.NewService(accounts.Deps{}), stack)
	levels.Routes(mux, levels.NewService(levels.Deps{Rules: rules}), stack)
	discovery.Routes(mux, discovery.NewService(discovery.Deps{}), stack)
	hosts.Routes(mux, hosts.NewService(hosts.Deps{Rules: rules}), stack)
	payouts.Routes(mux, payouts.NewService(payouts.Deps{Rules: rules, Enabled: cfg.PayoutsEnabled}), stack)
	freecall.Routes(mux, freecall.NewService(freecall.Deps{Rules: rules, Enabled: cfg.FreeCallEnabled}), stack)
	calls.Routes(mux, calls.NewService(calls.Deps{Rules: rules}), stack)
	chat.Routes(mux, chat.NewService(chat.Deps{}), stack)
	wallet.Routes(mux, wallet.NewService(wallet.Deps{}), stack)
	purchases.Routes(mux, purchases.NewService(purchases.Deps{Rules: rules, PackageName: cfg.PlayPackageName}), stack)
	safety.Routes(mux, safety.NewService(safety.Deps{}), stack)
	notifications.Routes(mux, notifications.NewService(notifications.Deps{}), stack)
	moderation.Routes(mux, moderation.NewService(moderation.Deps{}), stack)
	admin.Routes(mux, admin.NewService(admin.Deps{}), stack)

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if pool == nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := pool.Ping(ctx); err != nil {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		w.WriteHeader(http.StatusOK)
	})

	return httpx.Chain(mux, httpx.Recover, httpx.WithRequestID, httpx.AccessLog)
}
