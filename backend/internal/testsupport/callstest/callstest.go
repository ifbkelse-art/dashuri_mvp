//go:build integration

// Package callstest holds shared fakes and fixtures for the BE-calls
// integration tests (calls, freecall, moderation, hosts).
package callstest

import (
	"context"
	"encoding/json"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/calls"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

// Video is a fake VideoProvider; webhooks are JSON arrays of ProviderEvent
// accepted when X-Fake-Signature is "ok".
type Video struct {
	mu    sync.Mutex
	Ended []string
}

func (f *Video) CreateCall(_ context.Context, id, _, _ string) (string, error) { return id, nil }
func (f *Video) IssueToken(_ context.Context, u, c string, ttl time.Duration) (string, time.Time, error) {
	return "tok", time.Now().Add(ttl), nil
}
func (f *Video) EndCall(_ context.Context, id string) error {
	f.mu.Lock()
	f.Ended = append(f.Ended, id)
	f.mu.Unlock()
	return nil
}
func (f *Video) VerifyWebhook(raw []byte, h map[string]string) ([]calls.ProviderEvent, error) {
	if h["X-Fake-Signature"] != "ok" {
		return nil, &apperr.Error{Kind: apperr.KindUnauthenticated, Code: "invalid_signature"}
	}
	var evs []calls.ProviderEvent
	return evs, json.Unmarshal(raw, &evs)
}

// Principal returns an active, age-eligible principal.
func Principal(id string, roles ...auth.Role) auth.Principal {
	return auth.Principal{UserID: id, Status: "active", AgeEligible: true, Roles: roles}
}

// Calls builds a calls service on the api pool with the fake provider.
func Calls(api *pgxpool.Pool, v *Video) *calls.Service {
	return calls.NewService(calls.Deps{Rules: economy.Founder(), Video: v, ProviderName: "stream",
		Repo: postgres.CallsRepo{Pool: api, Tx: db.TxManager{Pool: api}}})
}

// Host creates an approved, available, free-call-opted-in host.
func Host(t *testing.T, admin *pgxpool.Pool, rate int64) string {
	t.Helper()
	id := pgtest.NewUser(t, admin, true, "customer", "host")
	if _, err := admin.Exec(context.Background(), `insert into hosting.hosts
		(user_id, state, kyc_state, rate_per_minute, is_available, last_heartbeat_at, free_call_opt_in, verification_status)
		values ($1, 'approved', 'approved', $2::bigint, true, now(), true, case when $2::bigint > 3000 then 'verified' else 'not_applied' end)`, id, rate); err != nil {
		t.Fatal(err)
	}
	identitytest.EligibleForRate(t, admin, id, rate)
	return id
}

// Fund credits purchased Diamonds.
func Fund(t *testing.T, api *pgxpool.Pool, user string, diamonds int64) {
	t.Helper()
	if _, _, err := (postgres.LedgerStore{Pool: api}).Post(context.Background(),
		ledger.PurchaseCredit(user, pgtest.UUID(), "tok-"+pgtest.UUID(), diamonds, "2026-11-17-founder", time.Now())); err != nil {
		t.Fatal(err)
	}
}

// Joined posts "participant joined" webhooks for both users at `at`.
func Joined(t *testing.T, svc *calls.Service, callID string, at time.Time, users ...string) {
	t.Helper()
	var evs []calls.ProviderEvent
	for _, u := range users {
		evs = append(evs, calls.ProviderEvent{EventID: pgtest.UUID(), ProviderCallID: callID, UserID: u, Kind: calls.EventJoined, At: at})
	}
	raw, _ := json.Marshal(evs)
	if err := svc.VideoProviderWebhook(context.Background(), "stream", raw, map[string]string{"X-Fake-Signature": "ok"}); err != nil {
		t.Fatal(err)
	}
}

// Rule returns the apperr code.
func Rule(err error) string {
	if e := apperr.As(err); e != nil {
		return e.Code
	}
	return ""
}
