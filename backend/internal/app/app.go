// Package app is the composition root: it builds every module with its
// dependencies and mounts them on one router (modular monolith, ADR-003).
// Each module is constructed in its own wire_<module>.go file.
package app

import (
	"context"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/adapters/supabase"
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
	"dashuri/backend/internal/platform/clock"
	"dashuri/backend/internal/platform/config"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/platform/httpx"
	"dashuri/backend/internal/platform/ratelimit"
	"dashuri/backend/internal/platform/routing"
	"dashuri/backend/internal/wiring"
)

// New builds the HTTP handler. pool may be nil in development without a database.
func New(cfg config.Config, pool *pgxpool.Pool) http.Handler {
	env := wiring.Env{
		Config:   cfg,
		Pool:     pool,
		Tx:       db.TxManager{Pool: pool},
		Rules:    economy.Founder(),
		Clock:    clock.System{},
		Realtime: supabase.Publisher{BaseURL: cfg.SupabaseURL, APIKey: cfg.RealtimeAPIKey},
		HTTP:     &http.Client{Timeout: 15 * time.Second},
	}
	verifier := &auth.JWKSVerifier{
		JWKSURL: cfg.SupabaseJWKSURL, Issuer: cfg.SupabaseIssuer, Audience: "authenticated",
		DevHS256Secret: cfg.SupabaseDevJWTSecret,
	}
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
	accounts.Routes(mux, wireAccounts(env), stack)
	levels.Routes(mux, wireLevels(env), stack)
	discovery.Routes(mux, wireDiscovery(env), stack)
	hosts.Routes(mux, wireHosts(env), stack)
	payouts.Routes(mux, wirePayouts(env), stack)
	freecall.Routes(mux, wireFreecall(env), stack)
	calls.Routes(mux, wireCalls(env), stack)
	chat.Routes(mux, wireChat(env), stack)
	wallet.Routes(mux, wireWallet(env), stack)
	purchases.Routes(mux, wirePurchases(env), stack)
	safety.Routes(mux, wireSafety(env), stack)
	notifications.Routes(mux, wireNotifications(env), stack)
	moderation.Routes(mux, wireModeration(env), stack)
	admin.Routes(mux, wireAdmin(env), stack)
	// MVP modules added after the foundation scaffold are mounted below.
	mountMVPModules(mux, env, stack)

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
