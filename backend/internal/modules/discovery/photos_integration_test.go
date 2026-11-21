//go:build integration

package discovery_test

import (
	"context"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/discovery"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

type signer struct{}

func (signer) SignRead(_ context.Context, paths []string, _ time.Duration) map[string]string {
	out := map[string]string{}
	for _, p := range paths {
		out[p] = "https://signed/" + p
	}
	return out
}

func TestHostDetailPhotoURLsInOrder(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	s := discovery.NewService(discovery.Deps{Repo: postgres.DiscoveryRepo{Pool: api}, Photos: signer{}, Rules: economy.Founder()})
	host := pgtest.NewUser(t, admin, true, "customer", "host")
	identitytest.Profile(t, admin, host, "Host", []string{"hi"}, nil)
	identitytest.Host(t, admin, host, 700, false)
	if _, err := admin.Exec(ctx, `insert into identity.profile_photos (user_id, storage_path, status, position) values
		($1::uuid, $1::text || '/second.jpg', 'approved', 2),
		($1::uuid, $1::text || '/first.jpg', 'approved', 1),
		($1::uuid, $1::text || '/pending.jpg', 'pending_review', 0),
		($1::uuid, $1::text || '/rejected.jpg', 'rejected', 3)`, host); err != nil {
		t.Fatal(err)
	}
	d, err := s.GetHost(ctx, identitytest.Principal(pgtest.NewUser(t, admin, true)), host)
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"https://signed/" + host + "/first.jpg", "https://signed/" + host + "/second.jpg"}
	if len(d.PhotoUrls) != 2 || d.PhotoUrls[0] != want[0] || d.PhotoUrls[1] != want[1] || d.PhotoUrl == nil || *d.PhotoUrl != want[0] {
		t.Fatalf("photos: %v %v", d.PhotoUrls, d.PhotoUrl)
	}
}
