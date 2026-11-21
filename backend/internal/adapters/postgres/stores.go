// Package postgres holds the Postgres implementations of platform and module
// ports. Every query runs as the least-privilege `api_service` role.
package postgres

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/idempotency"
)

// IdempotencyStore uses platform.idempotency_keys.
type IdempotencyStore struct{ Pool *pgxpool.Pool }

var _ idempotency.Store = IdempotencyStore{}

// Begin atomically claims (scope, key). Expired rows are replaced.
func (s IdempotencyStore) Begin(ctx context.Context, scope, key, hash string, ttl time.Duration) (*idempotency.Record, bool, error) {
	if s.Pool == nil {
		return nil, false, apperr.Unavailable("database_unavailable", "database not configured")
	}
	tag, err := s.Pool.Exec(ctx, `
		insert into platform.idempotency_keys (scope, key, request_hash, expires_at)
		values ($1, $2, $3, now() + make_interval(secs => $4))
		on conflict (scope, key) do update
		   set request_hash = excluded.request_hash, status = null, body = null,
		       completed = false, created_at = now(), expires_at = excluded.expires_at
		 where platform.idempotency_keys.expires_at < now()`,
		scope, key, hash, ttl.Seconds())
	if err != nil {
		return nil, false, apperr.Internal(err)
	}
	if tag.RowsAffected() == 1 {
		return nil, true, nil
	}
	var rec idempotency.Record
	var status *int
	err = s.Pool.QueryRow(ctx, `
		select request_hash, status, coalesce(body, ''::bytea), completed
		  from platform.idempotency_keys where scope = $1 and key = $2`, scope, key).
		Scan(&rec.RequestHash, &status, &rec.Body, &rec.Completed)
	if errors.Is(err, pgx.ErrNoRows) {
		// Released between the insert and the read: let the client retry.
		return nil, false, apperr.Conflict("request_in_progress", "retry the request")
	}
	if err != nil {
		return nil, false, apperr.Internal(err)
	}
	if status != nil {
		rec.Status = *status
	}
	return &rec, false, nil
}

// Complete stores the outcome.
func (s IdempotencyStore) Complete(ctx context.Context, scope, key string, status int, body []byte) error {
	_, err := s.Pool.Exec(ctx, `
		update platform.idempotency_keys set status = $3, body = $4, completed = true
		 where scope = $1 and key = $2`, scope, key, status, body)
	return err
}

// Release removes an in-progress claim after a server error.
func (s IdempotencyStore) Release(ctx context.Context, scope, key string) error {
	_, err := s.Pool.Exec(ctx, `delete from platform.idempotency_keys where scope = $1 and key = $2 and not completed`, scope, key)
	return err
}

// RoleSource reads identity.accounts. The first authenticated request of a
// new Supabase user provisions the account row (roles = customer).
type RoleSource struct{ Pool *pgxpool.Pool }

var _ auth.RoleSource = RoleSource{}

func (s RoleSource) Account(ctx context.Context, userID string) (auth.Account, error) {
	if s.Pool == nil {
		return auth.Account{}, apperr.Unavailable("database_unavailable", "database not configured")
	}
	var roles []string
	var a auth.Account
	if _, err := s.Pool.Exec(ctx, `insert into identity.accounts (id) values ($1) on conflict (id) do nothing`, userID); err != nil {
		if IsForeignKeyViolation(err) {
			// Token is valid but the auth user no longer exists.
			return auth.Account{}, apperr.Unauthenticated("unknown user")
		}
		return auth.Account{}, apperr.Internal(err)
	}
	err := s.Pool.QueryRow(ctx, `select roles, status, age_eligible from identity.accounts where id = $1`, userID).
		Scan(&roles, &a.Status, &a.AgeEligible)
	if err != nil {
		return auth.Account{}, apperr.Internal(err)
	}
	// Suspended and banned accounts are refused by auth.Middleware except on
	// the few routes needed to read the decision and appeal it.
	switch a.Status {
	case "deleted":
		return auth.Account{}, apperr.Forbidden("account_deleted", "this account has been deleted")
	}
	for _, r := range roles {
		a.Roles = append(a.Roles, auth.Role(r))
	}
	return a, nil
}
