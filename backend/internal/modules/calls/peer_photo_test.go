package calls

import (
	"context"
	"testing"
)

type peerOnlyRepo struct {
	Repository
	peers map[string]Peer
}

func (r peerOnlyRepo) Peers(context.Context, []string) (map[string]Peer, error) {
	out := map[string]Peer{}
	for k, v := range r.peers {
		out[k] = v
	}
	return out, nil
}

type fakePhotos map[string]string

func (f fakePhotos) FirstPhotoURLs(context.Context, []string) map[string]string { return f }

func TestPeersFillPhotoURL(t *testing.T) {
	repo := peerOnlyRepo{peers: map[string]Peer{"a": {UserID: "a", DisplayName: "A"}, "b": {UserID: "b", DisplayName: "B"}}}
	s := &Service{deps: Deps{Repo: repo, Photos: fakePhotos{"a": "https://signed/a.jpg"}}}
	got, err := s.peers(context.Background(), []string{"a", "b"})
	if err != nil || got["a"].PhotoURL == nil || *got["a"].PhotoURL != "https://signed/a.jpg" || got["b"].PhotoURL != nil {
		t.Fatalf("%+v %v", got, err)
	}
	// Without a photo port the URL stays null.
	s = &Service{deps: Deps{Repo: repo}}
	if got, _ := s.peers(context.Background(), []string{"a"}); got["a"].PhotoURL != nil {
		t.Fatal("photo url without port")
	}
}
