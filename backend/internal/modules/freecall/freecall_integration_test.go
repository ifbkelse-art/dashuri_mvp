//go:build integration

package freecall_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/calls"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/freecall"
	"dashuri/backend/internal/modules/ledger"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/testsupport/callstest"
	"dashuri/backend/internal/testsupport/pgtest"
)

// fakeIntegrity accepts any token; the token doubles as the device binding.
type fakeIntegrity struct{}

func (fakeIntegrity) Verify(_ context.Context, tok string) (freecall.IntegrityVerdict, error) {
	return freecall.IntegrityVerdict{DeviceBinding: tok}, nil
}

func str(s string) *string { return &s }

func TestFreeCallHostCapAndCardRules(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	if _, err := admin.Exec(ctx, `alter table auth.users add column if not exists phone text`); err != nil {
		t.Fatal(err)
	}
	callSvc := callstest.Calls(api, &callstest.Video{})
	repo := postgres.FreecallRepo{Pool: api, Tx: db.TxManager{Pool: api}}
	svc := freecall.NewService(freecall.Deps{Rules: economy.Founder(), Enabled: true, Integrity: fakeIntegrity{}, Repo: repo, Calls: callSvc})
	// Make sure no other opted-in host from earlier tests is eligible.
	if _, err := admin.Exec(ctx, `update hosting.hosts set free_call_opt_in = false`); err != nil {
		t.Fatal(err)
	}
	host := callstest.Host(t, admin, 1000)

	newUser := func(i int, phone bool) string {
		u := pgtest.NewUser(t, admin, true)
		if phone {
			if _, err := admin.Exec(ctx, `update auth.users set phone = $2 where id = $1`, u, fmt.Sprintf("91%010d%s", i, u[:4])); err != nil {
				t.Fatal(err)
			}
		}
		return u
	}
	request := func(u, tok string) (freecall.FreeCallRequest, error) {
		return svc.RequestFreeCall(ctx, callstest.Principal(u), freecall.FreeCallRequestBody{PlayIntegrityToken: str(tok)}, "android")
	}

	// Platform, phone and configuration rules.
	u0 := newUser(0, true)
	if _, err := svc.RequestFreeCall(ctx, callstest.Principal(u0), freecall.FreeCallRequestBody{PlayIntegrityToken: str("x")}, "ios"); callstest.Rule(err) != "free_call_unavailable_on_platform" {
		t.Fatalf("ios: %v", err)
	}
	if c, _ := svc.GetFreeCallCard(ctx, callstest.Principal(u0), "ios"); c.Status != "unavailable_on_platform" {
		t.Fatalf("ios card %+v", c)
	}
	if _, err := request(newUser(99, false), "dev-nophone"); callstest.Rule(err) != "phone_required" {
		t.Fatalf("no phone: %v", err)
	}
	noIntegrity := freecall.NewService(freecall.Deps{Rules: economy.Founder(), Enabled: true, Repo: repo, Calls: callSvc})
	if _, err := noIntegrity.RequestFreeCall(ctx, callstest.Principal(u0), freecall.FreeCallRequestBody{PlayIntegrityToken: str("x")}, "android"); callstest.Rule(err) != "integrity_not_configured" {
		t.Fatalf("integrity: %v", err)
	}

	// A free call that never connects gives the card (and the host slot) back.
	r, err := request(u0, "dev-0")
	if err != nil || r.Status != "matched" || r.CallId == nil {
		t.Fatalf("%+v %v", r, err)
	}
	if _, err := callSvc.DeclineCall(ctx, callstest.Principal(host), *r.CallId); err != nil {
		t.Fatal(err)
	}
	if c, _ := svc.GetFreeCallCard(ctx, callstest.Principal(u0), "android"); c.Status != "available" {
		t.Fatalf("card after declined free call: %+v", c)
	}

	// 20 connected free calls exhaust the host's daily cap.
	users := []string{u0}
	for i := 1; i < 21; i++ {
		users = append(users, newUser(i, true))
	}
	for i := 0; i < 20; i++ {
		r, err := request(users[i], fmt.Sprintf("dev-%d", i))
		if err != nil || r.Status != "matched" {
			t.Fatalf("call %d: %+v %v", i, r, err)
		}
		callstest.Joined(t, callSvc, *r.CallId, time.Now().Add(-61*time.Second), users[i], host)
		s, err := callSvc.EndCall(ctx, callstest.Principal(users[i]), *r.CallId, calls.EndCallRequest{Reason: "hangup"})
		if err != nil || s.Phase != "ended" || !s.IsFreeCall || s.DiamondsCharged != 0 || s.BilledSeconds != 60 {
			t.Fatalf("end %d: %+v %v", i, s, err)
		}
		got, _ := svc.GetFreeCallRequest(ctx, callstest.Principal(users[i]), r.RequestId)
		if got.Status != "matched" {
			t.Fatalf("request status %s", got.Status)
		}
	}
	r21, err := request(users[20], "dev-20")
	if err != nil || r21.Status != "no_host_available" || r21.CallId != nil {
		t.Fatalf("21st: %+v %v", r21, err)
	}
	if c, _ := svc.GetFreeCallCard(ctx, callstest.Principal(users[20]), "android"); c.Status != "available" {
		t.Fatalf("21st card %+v", c)
	}
	var count int
	_ = api.QueryRow(ctx, `select count from freecall.host_daily_counts where host_id = $1`, host).Scan(&count)
	beans, _ := (postgres.LedgerStore{Pool: api}).Balance(ctx, ledger.User(host, ledger.UserBeanHeld), ledger.Bean)
	if count != 20 || beans != 20*2000 {
		t.Fatalf("count=%d beans=%d", count, beans)
	}

	// One card per account and per device.
	if _, err := request(users[0], "dev-0"); callstest.Rule(err) != "card_already_used" {
		t.Fatalf("reuse: %v", err)
	}
	if c, _ := svc.GetFreeCallCard(ctx, callstest.Principal(users[0]), "android"); c.Status != "used" || c.UsedAt == nil {
		t.Fatalf("used card %+v", c)
	}
	if _, err := request(newUser(50, true), "dev-3"); callstest.Rule(err) != "device_already_used" {
		t.Fatalf("device reuse: %v", err)
	}
	// Other users cannot read a request.
	if _, err := svc.GetFreeCallRequest(ctx, callstest.Principal(users[1]), r21.RequestId); callstest.Rule(err) != "not_found" {
		t.Fatalf("foreign request: %v", err)
	}
}

// S4: the host is compensated only for an eligible free-call minute. A free
// call the customer ends after 20 connected seconds pays nothing, and the
// card stays used (it connected).
func TestShortFreeCallIsNotCompensated(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	if _, err := admin.Exec(ctx, `alter table auth.users add column if not exists phone text`); err != nil {
		t.Fatal(err)
	}
	if _, err := admin.Exec(ctx, `update hosting.hosts set free_call_opt_in = false`); err != nil {
		t.Fatal(err)
	}
	callSvc := callstest.Calls(api, &callstest.Video{})
	repo := postgres.FreecallRepo{Pool: api, Tx: db.TxManager{Pool: api}}
	svc := freecall.NewService(freecall.Deps{Rules: economy.Founder(), Enabled: true, Integrity: fakeIntegrity{}, Repo: repo, Calls: callSvc})
	host := callstest.Host(t, admin, 1000)
	u := pgtest.NewUser(t, admin, true)
	if _, err := admin.Exec(ctx, `update auth.users set phone = $2 where id = $1`, u, "91"+u[:10]); err != nil {
		t.Fatal(err)
	}
	r, err := svc.RequestFreeCall(ctx, callstest.Principal(u), freecall.FreeCallRequestBody{PlayIntegrityToken: str("short-" + u)}, "android")
	if err != nil || r.CallId == nil {
		t.Fatalf("%+v %v", r, err)
	}
	callstest.Joined(t, callSvc, *r.CallId, time.Now().Add(-20*time.Second), u, host)
	s, err := callSvc.EndCall(ctx, callstest.Principal(u), *r.CallId, calls.EndCallRequest{Reason: "hangup"})
	if err != nil || s.Phase != "ended" {
		t.Fatalf("end: %+v %v", s, err)
	}
	beans, _ := (postgres.LedgerStore{Pool: api}).Balance(ctx, ledger.User(host, ledger.UserBeanHeld), ledger.Bean)
	if beans != 0 {
		t.Fatalf("short free call compensated host with %d Beans", beans)
	}
	if c, _ := svc.GetFreeCallCard(ctx, callstest.Principal(u), "android"); c.Status != "used" {
		t.Fatalf("card after connected short call: %+v", c)
	}
}
