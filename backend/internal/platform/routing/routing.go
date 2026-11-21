// Package routing holds the middleware stack every module registers with.
package routing

import (
	"net/http"

	"dashuri/backend/internal/platform/idempotency"
)

// Stack is passed to each module's Routes function.
type Stack struct {
	// User wraps handlers that need an authenticated user (token verified,
	// roles loaded from the database, per-user rate limit).
	User func(http.HandlerFunc) http.Handler
	// Webhook wraps provider callbacks: no user auth; the handler verifies
	// the provider signature or OIDC token itself.
	Webhook func(http.HandlerFunc) http.Handler
	// Idempotency stores Idempotency-Key outcomes.
	Idempotency idempotency.Store
}
