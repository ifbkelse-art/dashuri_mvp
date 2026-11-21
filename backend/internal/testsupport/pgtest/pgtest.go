//go:build integration

// Package pgtest gives integration tests a pool connected as `api_service`
// and admin helpers for fixtures. Run via scripts/test-backend-integration.sh.
package pgtest

import (
	"context"
	"crypto/rand"
	"fmt"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Pools returns (api_service pool, admin pool). Skips when not configured.
func Pools(t *testing.T) (*pgxpool.Pool, *pgxpool.Pool) {
	t.Helper()
	url, admin := os.Getenv("DASHURI_TEST_DATABASE_URL"), os.Getenv("DASHURI_TEST_ADMIN_URL")
	if url == "" || admin == "" {
		t.Skip("integration database not configured; use scripts/test-backend-integration.sh")
	}
	ctx := context.Background()
	api, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	adm, err := pgxpool.New(ctx, admin)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { api.Close(); adm.Close() })
	return api, adm
}

// UUID returns a random v4 UUID.
func UUID() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	b[6] = b[6]&0x0f | 0x40
	b[8] = b[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

// NewUser creates an auth.users row and an identity.accounts row.
// roles defaults to {customer}; ageEligible marks the 18+ gate as passed.
func NewUser(t *testing.T, admin *pgxpool.Pool, ageEligible bool, roles ...string) string {
	t.Helper()
	if len(roles) == 0 {
		roles = []string{"customer"}
	}
	id := UUID()
	ctx := context.Background()
	if _, err := admin.Exec(ctx, `insert into auth.users (id) values ($1)`, id); err != nil {
		t.Fatal(err)
	}
	if _, err := admin.Exec(ctx, `insert into identity.accounts (id, roles, age_eligible, age_method, date_of_birth)
		values ($1, $2, $3, case when $3 then 'self_declared' end, case when $3 then date '1995-01-01' end)`, id, roles, ageEligible); err != nil {
		t.Fatal(err)
	}
	return id
}
