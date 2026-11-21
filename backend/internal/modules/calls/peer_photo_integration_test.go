//go:build integration

package calls_test

import (
	"context"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/calls"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

type photoSigner struct{}

func (photoSigner) SignRead(_ context.Context, paths []string, _ time.Duration) map[string]string {
	out := map[string]string{}
	for _, p := range paths {
		out[p] = "https://signed/" + p
	}
	return out
}

func TestCallPeerPhotoURL(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	s := calls.NewService(calls.Deps{
		Rules: economy.Founder(), Repo: postgres.CallsRepo{Pool: api, Tx: db.TxManager{Pool: api}}, Video: &fakeVideo{}, ProviderName: "fake",
		Photos: postgres.ProfilePhotoURLs{Pool: api, Signer: photoSigner{}},
	})
	caller, host := pgtest.NewUser(t, admin, true), pgtest.NewUser(t, admin, true, "customer", "host")
	identitytest.Profile(t, admin, host, "Host", nil, nil)
	identitytest.Profile(t, admin, caller, "Caller", nil, nil)
	if _, err := admin.Exec(ctx, `insert into identity.profile_photos (user_id, storage_path, status, position) values
		($1::uuid, $1::text || '/pending.jpg', 'pending_review', 0),
		($1::uuid, $1::text || '/main.jpg', 'approved', 1),
		($1::uuid, $1::text || '/later.jpg', 'approved', 2)`, host); err != nil {
		t.Fatal(err)
	}
	callID := identitytest.Call(t, admin, caller, host, "ended", 60, time.Minute)

	sess, err := s.GetCall(ctx, identitytest.Principal(caller), callID)
	if err != nil || sess.Peer == nil || sess.Peer.DisplayName != "Host" || sess.Peer.PhotoURL == nil ||
		*sess.Peer.PhotoURL != "https://signed/"+host+"/main.jpg" {
		t.Fatalf("caller view: %+v %v", sess.Peer, err)
	}
	// The host's view: the caller has no approved photo → null.
	sess, err = s.GetCall(ctx, identitytest.Principal(host), callID)
	if err != nil || sess.Peer == nil || sess.Peer.PhotoURL != nil {
		t.Fatalf("host view: %+v %v", sess.Peer, err)
	}
}
