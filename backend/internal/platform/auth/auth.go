// Package auth authenticates requests and carries the caller's identity.
//
// Identity: Supabase Auth issues the access token (phone OTP). The API
// verifies the JWT signature against the project's JWKS (asymmetric signing
// keys), issuer, audience and expiry. Authorisation (roles, host status,
// restrictions, age eligibility) is decided from OUR database, never from
// client-supplied claims.
package auth

import (
	"context"
	"net/http"
	"strings"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/httpx"
)

// Role values stored in accounts.roles.
type Role string

const (
	RoleCustomer  Role = "customer"
	RoleHost      Role = "host"
	RoleModerator Role = "moderator"
	RoleAdmin     Role = "admin"
	RoleFinance   Role = "finance"
)

// Principal is the authenticated caller.
type Principal struct {
	UserID string
	Roles  []Role
	// Status is identity.accounts.status: active or restricted (suspended,
	// banned and deleted accounts never get a principal).
	Status      string
	AgeEligible bool
}

// Restricted reports an enforcement restriction (no calls, no messaging).
func (p Principal) Restricted() bool {
	return p.Status == "restricted" || p.Status == "suspended" || p.Status == "banned"
}

// Account is what a RoleSource loads for a verified user.
type Account struct {
	Roles       []Role
	Status      string
	AgeEligible bool
}

func (p Principal) Has(r Role) bool {
	for _, x := range p.Roles {
		if x == r {
			return true
		}
	}
	return false
}

// TokenVerifier validates an access token and returns the subject (user id).
type TokenVerifier interface {
	Verify(ctx context.Context, token string) (subject string, err error)
}

// RoleSource loads roles and restrictions for a user from the database. It
// provisions the account row on first use (the Supabase user already exists)
// and returns a Forbidden error for suspended, banned or deleted accounts.
type RoleSource interface {
	Account(ctx context.Context, userID string) (Account, error)
}

type ctxKey int

const principalKey ctxKey = iota

// FromContext returns the principal set by Middleware.
func FromContext(ctx context.Context) (Principal, bool) {
	p, ok := ctx.Value(principalKey).(Principal)
	return p, ok
}

// WithPrincipal is for tests and internal jobs.
func WithPrincipal(ctx context.Context, p Principal) context.Context {
	return context.WithValue(ctx, principalKey, p)
}

// Middleware requires a valid bearer token on every request it wraps and
// refuses suspended or banned accounts.
func Middleware(v TokenVerifier, roles RoleSource) func(http.Handler) http.Handler {
	return middleware(v, roles, false)
}

// MiddlewareAllowingSuspended is Middleware for the routes a suspended or
// banned user still needs: account status, enforcement notices and appeals.
func MiddlewareAllowingSuspended(v TokenVerifier, roles RoleSource) func(http.Handler) http.Handler {
	return middleware(v, roles, true)
}

func middleware(v TokenVerifier, roles RoleSource, allowSuspended bool) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			raw, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
			if !ok || raw == "" {
				httpx.WriteError(w, r, apperr.Unauthenticated("missing bearer token"))
				return
			}
			sub, err := v.Verify(r.Context(), raw)
			if err != nil {
				httpx.WriteError(w, r, apperr.Unauthenticated("invalid token"))
				return
			}
			acct, err := roles.Account(r.Context(), sub)
			if err != nil {
				httpx.WriteError(w, r, err)
				return
			}
			if !allowSuspended && (acct.Status == "suspended" || acct.Status == "banned") {
				httpx.WriteError(w, r, apperr.Forbidden("account_"+acct.Status, "this account is "+acct.Status))
				return
			}
			p := Principal{UserID: sub, Roles: acct.Roles, Status: acct.Status, AgeEligible: acct.AgeEligible}
			next.ServeHTTP(w, r.WithContext(context.WithValue(r.Context(), principalKey, p)))
		})
	}
}

// Require returns 403 unless the principal has one of the roles.
func Require(next http.HandlerFunc, any ...Role) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		p, ok := FromContext(r.Context())
		if !ok {
			httpx.WriteError(w, r, apperr.Unauthenticated("no principal"))
			return
		}
		for _, role := range any {
			if p.Has(role) {
				next(w, r)
				return
			}
		}
		httpx.WriteError(w, r, apperr.Forbidden("role_required", "insufficient role"))
	}
}
