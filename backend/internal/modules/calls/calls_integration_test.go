//go:build integration

package calls_test

import (
	"context"
	"encoding/json"
	"errors"
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
	"dashuri/backend/internal/testsupport/pgtest"
)

// fakeVideo is the integration-test VideoProvider: it records calls and
// accepts webhooks whose body is a JSON array of ProviderEvent when the
// X-Fake-Signature header is "ok".
type fakeVideo struct {
	mu      sync.Mutex
	created []string
	ended   []string
}

func (f *fakeVideo) CreateCall(_ context.Context, id, _, _ string) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.created = append(f.created, id)
	return id, nil
}
func (f *fakeVideo) IssueToken(_ context.Context, u, c string, ttl time.Duration) (string, time.Time, error) {
	return "tok:" + u + ":" + c, time.Now().Add(ttl), nil
}
func (f *fakeVideo) EndCall(_ context.Context, id string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.ended = append(f.ended, id)
	return nil
}
func (f *fakeVideo) VerifyWebhook(raw []byte, h map[string]string) ([]calls.ProviderEvent, error) {
	if h["X-Fake-Signature"] != "ok" {
		return nil, &apperr.Error{Kind: apperr.KindUnauthenticated, Code: "invalid_signature"}
	}
	var evs []calls.ProviderEvent
	return evs, json.Unmarshal(raw, &evs)
}

type testClock struct {
	mu sync.Mutex
	t  time.Time
}

func (c *testClock) Now() time.Time  { c.mu.Lock(); defer c.mu.Unlock(); return c.t }
func (c *testClock) Set(t time.Time) { c.mu.Lock(); c.t = t; c.mu.Unlock() }
func principal(id string) auth.Principal {
	return auth.Principal{UserID: id, Status: "active", AgeEligible: true}
}

type env struct {
	api, admin *pgxpool.Pool
	svc        *calls.Service
	video      *fakeVideo
	clock      *testClock
	ledger     postgres.LedgerStore
}

func setup(t *testing.T) env {
	api, admin := pgtest.Pools(t)
	e := env{api: api, admin: admin, video: &fakeVideo{}, clock: &testClock{t: time.Now().UTC()}, ledger: postgres.LedgerStore{Pool: api}}
	e.svc = calls.NewService(calls.Deps{
		Rules: economy.Founder(), Video: e.video, Clock: e.clock, ProviderName: "stream", APIKey: "pk",
		Repo: postgres.CallsRepo{Pool: api, Tx: db.TxManager{Pool: api}},
	})
	return e
}

func (e env) host(t *testing.T, rate int64) string {
	t.Helper()
	id := pgtest.NewUser(t, e.admin, true, "customer", "host")
	if _, err := e.admin.Exec(context.Background(), `insert into hosting.hosts
		(user_id, state, kyc_state, rate_per_minute, is_available, last_heartbeat_at, free_call_opt_in)
		values ($1, 'approved', 'approved', $2, true, now(), true)`, id, rate); err != nil {
		t.Fatal(err)
	}
	return id
}

func (e env) customer(t *testing.T, diamonds int64) string {
	t.Helper()
	id := pgtest.NewUser(t, e.admin, true)
	if diamonds > 0 {
		if _, _, err := e.ledger.Post(context.Background(), ledger.PurchaseCredit(id, pgtest.UUID(), "tok-"+pgtest.UUID(), diamonds, "2026-11-17-founder", time.Now())); err != nil {
			t.Fatal(err)
		}
	}
	return id
}

func (e env) balance(t *testing.T, user string, k ledger.AccountKind, c ledger.Currency) int64 {
	t.Helper()
	b, err := e.ledger.Balance(context.Background(), ledger.User(user, k), c)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func (e env) webhook(t *testing.T, evs ...calls.ProviderEvent) {
	t.Helper()
	raw, _ := json.Marshal(evs)
	if err := e.svc.VideoProviderWebhook(context.Background(), "stream", raw, map[string]string{"X-Fake-Signature": "ok"}); err != nil {
		t.Fatal(err)
	}
}

func joined(callID, user string, at time.Time) calls.ProviderEvent {
	return calls.ProviderEvent{EventID: pgtest.UUID(), ProviderCallID: callID, UserID: user, Kind: calls.EventJoined, At: at}
}

func rule(err error) string {
	if e := apperr.As(err); e != nil {
		return e.Code
	}
	return ""
}

// startActiveCall runs request → accept → credentials → both joined at t0.
func (e env) startActiveCall(t *testing.T, customer, host string, t0 time.Time) calls.CallSession {
	t.Helper()
	ctx := context.Background()
	e.clock.Set(t0)
	s, err := e.svc.RequestCall(ctx, principal(customer), calls.CallRequestBody{HostUserId: host})
	if err != nil {
		t.Fatal(err)
	}
	if s.Phase != "ringing" || s.Role != "caller" {
		t.Fatalf("request: %+v", s)
	}
	if s, err = e.svc.AcceptCall(ctx, principal(host), s.CallId); err != nil || s.Phase != "accepted" {
		t.Fatalf("accept: %+v %v", s, err)
	}
	cr, err := e.svc.GetCallCredentials(ctx, principal(customer), s.CallId)
	if err != nil || cr.ProviderCallId != s.CallId || cr.APIKey != "pk" || cr.UserToken == "" {
		t.Fatalf("credentials: %+v %v", cr, err)
	}
	e.webhook(t, joined(s.CallId, customer, t0), joined(s.CallId, host, t0))
	got, err := e.svc.GetCall(ctx, principal(customer), s.CallId)
	if err != nil || got.Phase != "active" || got.StartedAt == nil || !got.StartedAt.Equal(t0) ||
		got.ModerationWindowEndsAt == nil || !got.ModerationWindowEndsAt.Equal(t0.Add(180*time.Second)) {
		t.Fatalf("active: %+v %v", got, err)
	}
	return got
}

func TestFullPaidCallSettlesExactAmounts(t *testing.T) {
	e := setup(t)
	ctx := context.Background()
	host := e.host(t, 4000)
	cust := e.customer(t, 10000)
	t0 := time.Now().UTC().Truncate(time.Second)
	s := e.startActiveCall(t, cust, host, t0)

	var reserved int64
	if err := e.api.QueryRow(ctx, `select amount from ledger.diamond_reservations where call_id = $1 and status = 'active'`, s.CallId).Scan(&reserved); err != nil || reserved != 8000 {
		t.Fatalf("reservation %d %v (want 120 s = 8000)", reserved, err)
	}
	// Strangers cannot see the call.
	if _, err := e.svc.GetCall(ctx, principal(pgtest.UUID()), s.CallId); rule(err) != "not_found" {
		t.Fatalf("stranger: %v", err)
	}

	e.clock.Set(t0.Add(65 * time.Second))
	out, err := e.svc.EndCall(ctx, principal(cust), s.CallId, calls.EndCallRequest{Reason: "hangup"})
	if err != nil {
		t.Fatal(err)
	}
	if out.Phase != "ended" || out.BilledSeconds != 65 || out.DiamondsCharged != 4333 {
		t.Fatalf("end: %+v", out)
	}
	if got := e.balance(t, cust, ledger.UserDiamondPurchased, ledger.Diamond); got != 10000-4333 {
		t.Fatalf("customer diamonds %d", got)
	}
	if got := e.balance(t, host, ledger.UserBeanHeld, ledger.Bean); got != 2599 {
		t.Fatalf("host beans %d", got)
	}
	var beans, xp int64
	var status string
	if err := e.api.QueryRow(ctx, `select s.beans_earned, r.status, x.xp_delta from calls.settlements s
		join ledger.diamond_reservations r on r.call_id = s.call_id
		join ledger.xp_events x on x.source_id = 'call:' || s.call_id::text
		where s.call_id = $1`, s.CallId).Scan(&beans, &status, &xp); err != nil || beans != 2599 || status != "settled" || xp != 2599 {
		t.Fatalf("settlement row %d %s %d %v", beans, status, xp, err)
	}
	// Idempotent replay: same result, no second charge.
	e.clock.Set(t0.Add(500 * time.Second))
	again, err := e.svc.EndCall(ctx, principal(host), s.CallId, calls.EndCallRequest{Reason: "hangup"})
	if err != nil || again.DiamondsCharged != 4333 || again.BilledSeconds != 65 {
		t.Fatalf("replay %+v %v", again, err)
	}
	if got := e.balance(t, cust, ledger.UserDiamondPurchased, ledger.Diamond); got != 5667 {
		t.Fatalf("charged twice: %d", got)
	}
	// History lists it with peer info.
	page, err := e.svc.ListCallHistory(ctx, principal(host), calls.PageRequest{Limit: 10})
	if err != nil || len(page.Items) != 1 || page.Items[0].Role != "receiver" || page.Items[0].Peer == nil || page.Items[0].Peer.UserID != cust {
		t.Fatalf("history %+v %v", page, err)
	}
}

func TestInsufficientBalanceRefused(t *testing.T) {
	e := setup(t)
	host := e.host(t, 4000)
	cust := e.customer(t, 3999) // 59.98 s at 4,000 D/min
	_, err := e.svc.RequestCall(context.Background(), principal(cust), calls.CallRequestBody{HostUserId: host})
	if rule(err) != "insufficient_diamonds" {
		t.Fatalf("want insufficient_diamonds, got %v", err)
	}
	if _, err := e.svc.RequestCall(context.Background(), principal(host), calls.CallRequestBody{HostUserId: host}); rule(err) != "self_call" {
		t.Fatalf("self call: %v", err)
	}
}

func TestParallelRequestsProduceOneLiveCall(t *testing.T) {
	e := setup(t)
	host := e.host(t, 1000)
	custs := make([]string, 50)
	for i := range custs {
		custs[i] = e.customer(t, 5000)
	}
	var wg sync.WaitGroup
	var mu sync.Mutex
	ok, busy := 0, 0
	for _, c := range custs {
		wg.Add(1)
		go func(c string) {
			defer wg.Done()
			_, err := e.svc.RequestCall(context.Background(), principal(c), calls.CallRequestBody{HostUserId: host})
			mu.Lock()
			defer mu.Unlock()
			switch {
			case err == nil:
				ok++
			case rule(err) == "host_busy":
				busy++
			default:
				t.Errorf("unexpected: %v", err)
			}
		}(c)
	}
	wg.Wait()
	var live int
	_ = e.api.QueryRow(context.Background(), `select count(*) from calls.calls where receiver_id = $1 and phase = 'ringing'`, host).Scan(&live)
	if ok != 1 || busy != 49 || live != 1 {
		t.Fatalf("ok=%d busy=%d live=%d", ok, busy, live)
	}
	// The same caller twice in parallel → one live call.
	host2 := e.host(t, 1000)
	cust := e.customer(t, 50000)
	var wins int
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if _, err := e.svc.RequestCall(context.Background(), principal(cust), calls.CallRequestBody{HostUserId: host2}); err == nil {
				mu.Lock()
				wins++
				mu.Unlock()
			} else if r := rule(err); r != "caller_in_call" && r != "host_busy" {
				t.Errorf("unexpected: %v", err)
			}
		}()
	}
	wg.Wait()
	if wins != 1 {
		t.Fatalf("same caller: %d live calls", wins)
	}
}

func TestParallelEndAndStaleSweepSettleOnce(t *testing.T) {
	e := setup(t)
	ctx := context.Background()
	host := e.host(t, 4000)
	cust := e.customer(t, 10000)
	t0 := time.Now().UTC().Truncate(time.Second)
	s := e.startActiveCall(t, cust, host, t0)
	left := func(u string) calls.ProviderEvent {
		return calls.ProviderEvent{EventID: pgtest.UUID(), ProviderCallID: s.CallId, UserID: u, Kind: calls.EventLeft, At: t0.Add(65 * time.Second)}
	}
	e.clock.Set(t0.Add(66 * time.Second))
	e.webhook(t, left(host))
	e.clock.Set(t0.Add(200 * time.Second)) // nobody live for 135 s → stale
	var wg sync.WaitGroup
	for i := 0; i < 10; i++ {
		wg.Add(2)
		go func() {
			defer wg.Done()
			if _, err := e.svc.EndCall(ctx, principal(cust), s.CallId, calls.EndCallRequest{Reason: "hangup"}); err != nil {
				t.Error(err)
			}
		}()
		go func() {
			defer wg.Done()
			if _, err := e.svc.Sweep(ctx, e.clock.Now()); err != nil {
				t.Error(err)
			}
		}()
	}
	wg.Wait()
	var entries, settlements int
	_ = e.api.QueryRow(ctx, `select count(*) from ledger.journal_entries where reference = $1`, s.CallId).Scan(&entries)
	_ = e.api.QueryRow(ctx, `select count(*) from calls.settlements where call_id = $1`, s.CallId).Scan(&settlements)
	if entries != 1 || settlements != 1 {
		t.Fatalf("entries=%d settlements=%d", entries, settlements)
	}
	if got := e.balance(t, cust, ledger.UserDiamondPurchased, ledger.Diamond); got != 10000-4333 {
		t.Fatalf("customer diamonds %d (want 65 s billed once)", got)
	}
}

func TestRingTimeoutAndDeclineReleaseReservation(t *testing.T) {
	e := setup(t)
	ctx := context.Background()
	host := e.host(t, 1000)
	cust := e.customer(t, 5000)
	t0 := time.Now().UTC()
	e.clock.Set(t0)
	s, err := e.svc.RequestCall(ctx, principal(cust), calls.CallRequestBody{HostUserId: host})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := e.svc.AcceptCall(ctx, principal(cust), s.CallId); err == nil {
		t.Fatal("caller must not accept")
	}
	if _, err := e.svc.Sweep(ctx, t0.Add(31*time.Second)); err != nil {
		t.Fatal(err)
	}
	got, _ := e.svc.GetCall(ctx, principal(cust), s.CallId)
	if got.Phase != "missed" {
		t.Fatalf("phase %s", got.Phase)
	}
	var st string
	_ = e.api.QueryRow(ctx, `select status from ledger.diamond_reservations where call_id = $1`, s.CallId).Scan(&st)
	if st != "released" {
		t.Fatalf("reservation %s", st)
	}
	// Decline.
	s2, err := e.svc.RequestCall(ctx, principal(cust), calls.CallRequestBody{HostUserId: host})
	if err != nil {
		t.Fatal(err)
	}
	if d, err := e.svc.DeclineCall(ctx, principal(host), s2.CallId); err != nil || d.Phase != "declined" {
		t.Fatalf("decline %+v %v", d, err)
	}
	// Connect timeout: accepted, never active → failed, no charge.
	s3, err := e.svc.RequestCall(ctx, principal(cust), calls.CallRequestBody{HostUserId: host})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := e.svc.AcceptCall(ctx, principal(host), s3.CallId); err != nil {
		t.Fatal(err)
	}
	if _, err := e.svc.Sweep(ctx, t0.Add(46*time.Second)); err != nil {
		t.Fatal(err)
	}
	if got, _ := e.svc.GetCall(ctx, principal(cust), s3.CallId); got.Phase != "failed" || got.DiamondsCharged != 0 {
		t.Fatalf("connect timeout %+v", got)
	}
	if b := e.balance(t, cust, ledger.UserDiamondPurchased, ledger.Diamond); b != 5000 {
		t.Fatalf("charged %d", 5000-b)
	}
}

func TestLowBalanceEndsCallAtZero(t *testing.T) {
	e := setup(t)
	ctx := context.Background()
	host := e.host(t, 6000)
	cust := e.customer(t, 6500) // 65 s at 6,000 D/min
	t0 := time.Now().UTC().Truncate(time.Second)
	s := e.startActiveCall(t, cust, host, t0)
	e.clock.Set(t0.Add(40 * time.Second))
	if _, err := e.svc.Sweep(ctx, e.clock.Now()); err != nil {
		t.Fatal(err)
	}
	var notified *time.Time
	_ = e.api.QueryRow(ctx, `select low_balance_notified_at from calls.calls where id = $1`, s.CallId).Scan(&notified)
	if notified == nil {
		t.Fatal("low balance warning not sent at 25 s remaining")
	}
	e.clock.Set(t0.Add(66 * time.Second))
	if _, err := e.svc.Sweep(ctx, e.clock.Now()); err != nil {
		t.Fatal(err)
	}
	got, _ := e.svc.GetCall(ctx, principal(cust), s.CallId)
	if got.Phase != "ended" || got.EndReason == nil || *got.EndReason != "low_balance" || got.DiamondsCharged != 6500 {
		t.Fatalf("%+v", got)
	}
	if b := e.balance(t, cust, ledger.UserDiamondPurchased, ledger.Diamond); b != 0 {
		t.Fatalf("balance %d", b)
	}
	if !errors.Is(nil, nil) {
		t.Fatal()
	}
}
