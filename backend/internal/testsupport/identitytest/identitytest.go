//go:build integration

// Package identitytest holds fixtures for the BE-identity integration tests
// (profiles, hosts, calls, Bean balances). Fixtures use the admin pool.
package identitytest

import (
	"context"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/testsupport/pgtest"
)

// Principal builds an active, age-eligible caller.
func Principal(userID string) auth.Principal {
	return auth.Principal{UserID: userID, Roles: []auth.Role{auth.RoleCustomer}, Status: "active", AgeEligible: true}
}

func exec(t *testing.T, admin *pgxpool.Pool, sql string, args ...any) {
	t.Helper()
	if _, err := admin.Exec(context.Background(), sql, args...); err != nil {
		t.Fatalf("fixture: %v\n%s", err, sql)
	}
}

// Profile creates a profile.
func Profile(t *testing.T, admin *pgxpool.Pool, userID, name string, languages []string, cityID *string) {
	t.Helper()
	if languages == nil {
		languages = []string{}
	}
	exec(t, admin, `insert into identity.profiles (user_id, display_name, languages, city_id, gender) values ($1, $2, $3, $4, 'woman')`,
		userID, name, languages, cityID)
}

// Host makes the user an approved host. online sets is_available with a
// fresh heartbeat.
func Host(t *testing.T, admin *pgxpool.Pool, userID string, rate int64, online bool) {
	t.Helper()
	exec(t, admin, `insert into hosting.hosts (user_id, state, kyc_state, rate_per_minute, is_available, last_heartbeat_at, approved_at)
		values ($1, 'approved', 'approved', $2, $3, case when $3 then now() end, now())`, userID, rate, online)
}

// Block inserts a block.
func Block(t *testing.T, admin *pgxpool.Pool, blocker, blocked string) {
	t.Helper()
	exec(t, admin, `insert into safety.blocks (blocker_id, blocked_id) values ($1, $2)`, blocker, blocked)
}

// Call inserts a call in the given phase. endedAgo applies to terminal phases.
func Call(t *testing.T, admin *pgxpool.Pool, caller, receiver, phase string, billedSeconds int64, endedAgo time.Duration) string {
	t.Helper()
	var id string
	err := admin.QueryRow(context.Background(), `
		insert into calls.calls (caller_id, receiver_id, phase, rate_per_minute, rule_set_version, billed_seconds,
		                         created_at, ended_at)
		values ($1, $2, $3, 500, (select version from economy.rule_sets order by effective_from limit 1), $4,
		        now() - make_interval(secs => $5) - interval '5 minutes',
		        case when $3 in ('ended','declined','missed','failed') then now() - make_interval(secs => $5) end)
		returning id`, caller, receiver, phase, billedSeconds, endedAgo.Seconds()).Scan(&id)
	if err != nil {
		t.Fatalf("fixture call: %v", err)
	}
	return id
}

// Beans credits held Beans through a real, balanced ledger entry (a free
// call compensation), so the ledger stays reconcilable for other tests.
func Beans(t *testing.T, admin *pgxpool.Pool, userID string, amount int64) {
	t.Helper()
	e := ledger.FreeCallCompensation(newID(), userID, amount, economy.Founder().Version, time.Now())
	if _, _, err := (postgres.LedgerStore{Pool: admin}).Post(context.Background(), e); err != nil {
		t.Fatalf("fixture beans: %v", err)
	}
}

func newID() string { return pgtest.UUID() }

// XP adds an XP event.
func XP(t *testing.T, admin *pgxpool.Pool, userID string, xp int64) {
	t.Helper()
	exec(t, admin, `insert into ledger.xp_events (user_id, source_type, source_id, xp_delta) values ($1, 'purchase', gen_random_uuid()::text, $2)`, userID, xp)
}
