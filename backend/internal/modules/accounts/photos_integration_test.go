//go:build integration

package accounts_test

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/accounts"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

// objStore is a fake bucket: only paths in objects exist.
type objStore struct {
	mu      sync.Mutex
	objects map[string]bool
	deleted []string
	listErr error
}

func (o *objStore) Configured() bool { return true }
func (o *objStore) SignUpload(_ context.Context, path string) (string, error) {
	return "https://storage.test/upload/" + path, nil
}
func (o *objStore) SignRead(_ context.Context, paths []string, _ time.Duration) map[string]string {
	o.mu.Lock()
	defer o.mu.Unlock()
	out := map[string]string{}
	for _, p := range paths {
		if o.objects[p] {
			out[p] = "https://storage.test/read/" + p
		}
	}
	return out
}
func (o *objStore) List(_ context.Context, prefix string, _ int) ([]string, error) {
	o.mu.Lock()
	defer o.mu.Unlock()
	if o.listErr != nil {
		return nil, o.listErr
	}
	var out []string
	for p := range o.objects {
		if strings.HasPrefix(p, prefix) {
			out = append(out, p)
		}
	}
	return out, nil
}
func (o *objStore) Delete(_ context.Context, path string) error {
	o.mu.Lock()
	defer o.mu.Unlock()
	o.deleted = append(o.deleted, path)
	delete(o.objects, path)
	return nil
}

func TestPhotoSlotsDeleteAndModeration(t *testing.T) {
	api, admin := pgtest.Pools(t)
	ctx := context.Background()
	store := &objStore{objects: map[string]bool{}}
	s := accounts.NewService(accounts.Deps{Repo: postgres.AccountsRepo{Pool: api}, Storage: store, Rules: economy.Founder()})

	u := pgtest.NewUser(t, admin, true)
	identitytest.Profile(t, admin, u, "Uma", nil, nil)
	pu := identitytest.Principal(u)
	add := func(user, status string, age time.Duration, uploaded bool) string {
		t.Helper()
		var id, path string
		err := admin.QueryRow(ctx, `
			insert into identity.profile_photos (user_id, storage_path, status, position, created_at)
			values ($1::uuid, $1::text || '/' || gen_random_uuid()::text || '.jpg', $2,
			        (select coalesce(max(position) + 1, 0) from identity.profile_photos where user_id = $1::uuid),
			        now() - make_interval(secs => $3))
			returning id, storage_path`, user, status, age.Seconds()).Scan(&id, &path)
		if err != nil {
			t.Fatal(err)
		}
		if uploaded {
			store.mu.Lock()
			store.objects[path] = true
			store.mu.Unlock()
		}
		return id
	}

	// 3 abandoned tickets (old, never uploaded), 1 old uploaded, 2 fresh tickets = 6.
	for i := 0; i < 3; i++ {
		add(u, "pending_review", 3*time.Hour, false)
	}
	oldUploaded := add(u, "pending_review", 3*time.Hour, true)
	add(u, "pending_review", 10*time.Minute, false)
	add(u, "pending_review", 10*time.Minute, false)
	if _, err := s.RequestPhotoUpload(ctx, pu, accounts.PhotoUploadTicketRequest{ContentType: "image/jpeg"}); err != nil {
		t.Fatalf("abandoned tickets must free slots: %v", err)
	}
	var n int
	_ = admin.QueryRow(ctx, `select count(*) from identity.profile_photos where user_id = $1`, u).Scan(&n)
	if n != 4 {
		t.Fatalf("rows after cleanup: %d (want 3 kept + 1 new)", n)
	}

	// Storage unreachable: every pending photo counts (conservative).
	v := pgtest.NewUser(t, admin, true)
	for i := 0; i < accounts.MaxPhotos; i++ {
		add(v, "pending_review", 3*time.Hour, false)
	}
	store.listErr = errors.New("storage down")
	if _, err := s.RequestPhotoUpload(ctx, identitytest.Principal(v), accounts.PhotoUploadTicketRequest{ContentType: "image/jpeg"}); rule(err) != "photo_limit_reached" {
		t.Fatalf("unknown storage state: %v", err)
	}
	store.listErr = nil
	// Deleting one frees a slot and removes the object.
	vPhoto := add(v, "rejected", time.Hour, true)
	if err := s.DeleteMyPhoto(ctx, pu, vPhoto); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("delete someone else's photo: %v", err)
	}
	var vPending string
	_ = admin.QueryRow(ctx, `select id from identity.profile_photos where user_id = $1 and status = 'pending_review' limit 1`, v).Scan(&vPending)
	if err := s.DeleteMyPhoto(ctx, identitytest.Principal(v), vPending); err != nil {
		t.Fatal(err)
	}
	if len(store.deleted) != 1 || !strings.HasPrefix(store.deleted[0], v+"/") {
		t.Fatalf("storage delete: %v", store.deleted)
	}
	store.listErr = errors.New("storage down")
	if _, err := s.RequestPhotoUpload(ctx, identitytest.Principal(v), accounts.PhotoUploadTicketRequest{ContentType: "image/png"}); err != nil {
		t.Fatalf("after delete: %v", err)
	}
	store.listErr = nil
	if err := s.DeleteMyPhoto(ctx, identitytest.Principal(v), vPending); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("second delete: %v", err)
	}

	// Moderation queue and decisions.
	mod := pgtest.NewUser(t, admin, true, "customer", "moderator")
	pm := auth.Principal{UserID: mod, Roles: []auth.Role{auth.RoleModerator}, Status: "active", AgeEligible: true}
	if _, err := s.ListPendingPhotos(ctx, pu, "", 10); apperr.As(err).Kind != apperr.KindForbidden {
		t.Fatalf("customer queue: %v", err)
	}
	seen := map[string]*string{}
	var last time.Time
	cursor := ""
	for i := 0; i < 1000; i++ {
		page, err := s.ListPendingPhotos(ctx, pm, cursor, 3)
		if err != nil {
			t.Fatal(err)
		}
		for _, it := range page.Items {
			if it.CreatedAt.Before(last) {
				t.Fatal("queue not oldest first")
			}
			last = it.CreatedAt
			if it.UserId == u {
				seen[it.PhotoId] = it.ReadUrl
			}
		}
		if page.NextCursor == nil {
			break
		}
		cursor = *page.NextCursor
	}
	if len(seen) != 4 || seen[oldUploaded] == nil {
		t.Fatalf("queue for u: %v", seen)
	}
	var notUploaded string
	for id, url := range seen {
		if url == nil {
			notUploaded = id
			break
		}
	}
	if _, err := s.DecidePhoto(ctx, pm, notUploaded, accounts.PhotoDecisionRequest{Decision: "approve"}); rule(err) != "photo_not_uploaded" {
		t.Fatalf("approve missing object: %v", err)
	}
	d, err := s.DecidePhoto(ctx, pm, oldUploaded, accounts.PhotoDecisionRequest{Decision: "approve"})
	if err != nil || d.Status != "approved" {
		t.Fatalf("approve: %+v %v", d, err)
	}
	if _, err := s.DecidePhoto(ctx, pm, oldUploaded, accounts.PhotoDecisionRequest{Decision: "reject"}); rule(err) != "photo_not_pending" {
		t.Fatalf("decide twice: %v", err)
	}
	reason := "not a photo of a person"
	if d, err := s.DecidePhoto(ctx, pm, notUploaded, accounts.PhotoDecisionRequest{Decision: "reject", Reason: &reason}); err != nil || d.Status != "rejected" {
		t.Fatalf("reject: %+v %v", d, err)
	}
	if _, err := s.DecidePhoto(ctx, pm, pgtest.UUID(), accounts.PhotoDecisionRequest{Decision: "reject"}); apperr.As(err).Kind != apperr.KindNotFound {
		t.Fatalf("unknown photo: %v", err)
	}
	var audits int
	_ = admin.QueryRow(ctx, `select count(*) from audit.events where actor = $1 and action in ('photo.approved','photo.rejected','photos.review_queue_viewed')`, mod).Scan(&audits)
	if audits < 3 {
		t.Fatalf("audit rows %d", audits)
	}
	var reasonLogged string
	_ = admin.QueryRow(ctx, `select details->>'reason' from audit.events where actor = $1 and action = 'photo.rejected' and target = $2`, mod, notUploaded).Scan(&reasonLogged)
	if reasonLogged != reason {
		t.Fatalf("reason %q", reasonLogged)
	}

	// The approved photo is now public.
	viewer := identitytest.Principal(pgtest.NewUser(t, admin, true))
	prof, err := s.GetProfile(ctx, viewer, u)
	if err != nil || len(prof.PhotoUrls) != 1 || !strings.Contains(prof.PhotoUrls[0], "/read/"+u+"/") {
		t.Fatalf("public photos: %+v %v", prof, err)
	}
}
