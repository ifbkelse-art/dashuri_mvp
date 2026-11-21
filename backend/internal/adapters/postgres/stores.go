// Package postgres holds Postgres implementations of platform ports.
// NOT IMPLEMENTED: each method documents the SQL contract it must meet.
package postgres

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/idempotency"
)

// IdempotencyStore uses platform.idempotency_keys.
type IdempotencyStore struct{ Pool *pgxpool.Pool }

var _ idempotency.Store = IdempotencyStore{}

// Begin: INSERT (scope, key, request_hash, expires_at) ON CONFLICT DO NOTHING
// RETURNING; if no row returned, SELECT the existing row.
func (IdempotencyStore) Begin(context.Context, string, string, string, time.Duration) (*idempotency.Record, bool, error) {
	return nil, false, apperr.NotImplemented("idempotency store")
}

// Complete: UPDATE … SET status, body, completed_at WHERE scope AND key.
func (IdempotencyStore) Complete(context.Context, string, string, int, []byte) error {
	return apperr.NotImplemented("idempotency store")
}

// Release: DELETE the in-progress row.
func (IdempotencyStore) Release(context.Context, string, string) error {
	return apperr.NotImplemented("idempotency store")
}

// RoleSource reads identity.accounts (roles, status). Suspended or deleted
// accounts must be refused here.
type RoleSource struct{ Pool *pgxpool.Pool }

var _ auth.RoleSource = RoleSource{}

func (RoleSource) Roles(context.Context, string) ([]auth.Role, error) {
	return nil, apperr.NotImplemented("role source")
}
