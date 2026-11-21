//go:build integration

package discovery_test

import (
	"context"
	"testing"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/discovery"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

// mine keeps only the hosts created by this test (the database is shared).
func mine(items []discovery.HostCard, ids map[string]string) []string {
	var out []string
	for _, c := range items {
		if name, ok := ids[c.UserId]; ok {
			out = append(out, name)
		}
	}
	return out
}

func eq(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func TestDiscoveryFiltersBlocksAndPagination(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	s := discovery.NewService(discovery.Deps{Repo: postgres.DiscoveryRepo{Pool: api}, Rules: economy.Founder()})
	pune := "pune"

	viewer := pgtest.NewUser(t, admin, true)
	identitytest.Profile(t, admin, viewer, "Viewer", nil, nil)
	identitytest.Host(t, admin, viewer, 500, true) // the caller themself is never listed

	ids := map[string]string{}
	mk := func(name string, rate int64, online bool, langs []string, city *string) string {
		id := pgtest.NewUser(t, admin, true, "customer", "host")
		identitytest.Profile(t, admin, id, name, langs, city)
		identitytest.Host(t, admin, id, rate, online)
		ids[id] = name
		return id
	}
	a := mk("A", 800, true, []string{"hi"}, nil)
	mk("B", 600, true, []string{"en"}, &pune)
	off := mk("C-offline", 900, false, []string{"hi"}, nil)
	blockedByMe := mk("D-blocked", 700, true, []string{"hi"}, nil)
	blocksMe := mk("E-blocks-me", 700, true, []string{"hi"}, nil)
	busy := mk("F-busy", 700, false, []string{"ta"}, nil)
	identitytest.Block(t, admin, viewer, blockedByMe)
	identitytest.Block(t, admin, blocksMe, viewer)
	identitytest.Call(t, admin, pgtest.NewUser(t, admin, true), busy, "active", 0, 0)
	identitytest.XP(t, admin, a, 50000) // A ranks above B on level
	if _, err := admin.Exec(ctx, `update identity.accounts set age_method = 'kyc_verified', date_of_birth = '1998-06-15' where id = $1`, a); err != nil {
		t.Fatal(err)
	}

	p := identitytest.Principal(viewer)
	list := func(req discovery.ListRequest) []string {
		t.Helper()
		var all []discovery.HostCard
		for i := 0; i < 50; i++ {
			page, err := s.ListAvailableHosts(ctx, p, req)
			if err != nil {
				t.Fatal(err)
			}
			all = append(all, page.Items...)
			if page.NextCursor == nil {
				break
			}
			req.Cursor = *page.NextCursor
		}
		return mine(all, ids)
	}
	if got := list(discovery.ListRequest{Limit: 100}); !eq(got, []string{"A", "B", "F-busy"}) {
		t.Fatalf("recommended: %v", got)
	}
	// Same order when walking one card per page (keyset pagination).
	if got := list(discovery.ListRequest{Limit: 1}); !eq(got, []string{"A", "B", "F-busy"}) {
		t.Fatalf("paged recommended: %v", got)
	}
	if got := list(discovery.ListRequest{Limit: 2, Sort: "rate_low"}); !eq(got, []string{"B", "F-busy", "A"}) {
		t.Fatalf("rate_low: %v", got)
	}
	if got := list(discovery.ListRequest{Limit: 2, Sort: "rate_high"}); !eq(got, []string{"A", "F-busy", "B"}) {
		t.Fatalf("rate_high: %v", got)
	}
	if got := list(discovery.ListRequest{Limit: 20, Language: "hi"}); !eq(got, []string{"A"}) {
		t.Fatalf("language hi: %v", got)
	}
	if got := list(discovery.ListRequest{Limit: 20, CityID: "pune"}); !eq(got, []string{"B"}) {
		t.Fatalf("city pune: %v", got)
	}

	page, _ := s.ListAvailableHosts(ctx, p, discovery.ListRequest{Limit: 100})
	for _, c := range page.Items {
		switch c.UserId {
		case a:
			if c.Availability != "available" || c.Level != 2 || c.Age == nil || *c.Age < 27 || !c.IsVerified {
				t.Fatalf("A card: %+v", c)
			}
		case busy:
			if c.Availability != "busy" {
				t.Fatalf("busy card: %+v", c)
			}
		}
	}

	d, err := s.GetHost(ctx, p, off)
	if err != nil || d.Availability != "offline" || d.DisplayName != "C-offline" {
		t.Fatalf("offline detail: %+v %v", d, err)
	}
	for _, id := range []string{blockedByMe, blocksMe, viewer + "x", pgtest.UUID()} {
		if _, err := s.GetHost(ctx, p, id); apperr.As(err).Kind != apperr.KindNotFound {
			t.Errorf("detail %s: want 404, got %v", ids[id], err)
		}
	}

	other := pgtest.NewUser(t, admin, true)
	mineCount, _ := s.GetSummary(ctx, p)
	otherCount, _ := s.GetSummary(ctx, identitytest.Principal(other))
	// other sees D and E (no blocks) and the viewer's own online host card.
	if otherCount.OnlineCount-mineCount.OnlineCount != 3 {
		t.Fatalf("summary: viewer %d other %d", mineCount.OnlineCount, otherCount.OnlineCount)
	}
	if _, err := s.ListAvailableHosts(ctx, p, discovery.ListRequest{Limit: 5, Sort: "rate_low", Cursor: "garbage"}); apperr.As(err).Kind != apperr.KindValidation {
		t.Fatalf("bad cursor: %v", err)
	}
}
