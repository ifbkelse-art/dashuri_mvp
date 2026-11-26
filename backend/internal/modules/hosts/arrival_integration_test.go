//go:build integration

package hosts_test

// Online sessions and arrival photos against real Postgres (migration
// 20261126000100): session lifecycle, capture/confirm/validate, moderation
// paths, discovery exposure, expiry on going offline, reuse prevention,
// access control, staff decisions, reports and purge.

import (
	"bytes"
	"context"
	"errors"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"dashuri/backend/internal/adapters/postgres"
	"dashuri/backend/internal/modules/discovery"
	"dashuri/backend/internal/modules/economy"
	"dashuri/backend/internal/modules/hosts"
	"dashuri/backend/internal/modules/safety"
	"dashuri/backend/internal/platform/apperr"
	"dashuri/backend/internal/platform/auth"
	"dashuri/backend/internal/platform/db"
	"dashuri/backend/internal/testsupport/callstest"
	"dashuri/backend/internal/testsupport/identitytest"
	"dashuri/backend/internal/testsupport/pgtest"
)

// fakeArrivalStore is the private arrival bucket.
type fakeArrivalStore struct {
	mu      sync.Mutex
	objects map[string][]byte
	deleted []string
	failGet error
}

func newStore() *fakeArrivalStore { return &fakeArrivalStore{objects: map[string][]byte{}} }

func (f *fakeArrivalStore) Configured() bool { return true }
func (f *fakeArrivalStore) SignUpload(_ context.Context, path string) (string, error) {
	return "https://storage.test/upload/" + path, nil
}
func (f *fakeArrivalStore) SignRead(_ context.Context, paths []string, _ time.Duration) map[string]string {
	f.mu.Lock()
	defer f.mu.Unlock()
	out := map[string]string{}
	for _, p := range paths {
		if _, ok := f.objects[p]; ok {
			out[p] = "https://storage.test/read/" + p
		}
	}
	return out
}
func (f *fakeArrivalStore) Download(_ context.Context, path string, max int64) ([]byte, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.failGet != nil {
		return nil, f.failGet
	}
	b, ok := f.objects[path]
	if !ok {
		return nil, hosts.ErrObjectNotFound
	}
	if int64(len(b)) > max {
		return nil, hosts.ErrObjectTooLarge
	}
	return b, nil
}
func (f *fakeArrivalStore) Put(_ context.Context, path, _ string, data []byte) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.objects[path] = data
	return nil
}
func (f *fakeArrivalStore) Delete(_ context.Context, path string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	delete(f.objects, path)
	f.deleted = append(f.deleted, path)
	return nil
}

// upload simulates the client PUT to the signed URL.
func (f *fakeArrivalStore) upload(path string, data []byte) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.objects[path] = data
}

type scanner struct{ score float64 }

func (s scanner) ExplicitScore(context.Context, []byte) (float64, error) { return s.score, nil }

func jpegBytes(t *testing.T, w, h int) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	for x := range w {
		img.Set(x, x%h, color.RGBA{200, 80, 120, 255})
	}
	var b bytes.Buffer
	if err := jpeg.Encode(&b, img, &jpeg.Options{Quality: 80}); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}

type aEnv struct {
	ctx    context.Context
	api    *pgxpool.Pool
	admin  *pgxpool.Pool
	store  *fakeArrivalStore
	rules  economy.Rules
	repo   postgres.HostsRepo
	svc    *hosts.Service
	staff  auth.Principal
	disc   *discovery.Service
	viewer auth.Principal
}

func newAEnv(t *testing.T, cfg func(*hosts.ArrivalConfig)) aEnv {
	t.Helper()
	api, adm := pgtest.Pools(t)
	e := aEnv{ctx: context.Background(), api: api, admin: adm, store: newStore(), rules: economy.Founder()}
	e.repo = postgres.HostsRepo{Pool: api, Tx: db.TxManager{Pool: api}, Sessions: true}
	ac := hosts.ArrivalConfig{Enabled: true, Repo: e.repo, Store: e.store}
	if cfg != nil {
		cfg(&ac)
	}
	e.svc = hosts.NewService(hosts.Deps{Rules: e.rules, Repo: e.repo, Arrival: ac})
	e.staff = callstest.Principal(pgtest.NewUser(t, adm, true, "customer", "moderator"), auth.RoleModerator)
	e.disc = discovery.NewService(discovery.Deps{Repo: postgres.DiscoveryRepo{Pool: api, ArrivalPhotos: true},
		ArrivalPhotos: e.store, Rules: e.rules})
	e.viewer = identitytest.Principal(pgtest.NewUser(t, adm, true))
	return e
}

// offlineHost is an approved host that is offline.
func (e aEnv) offlineHost(t *testing.T) (string, auth.Principal) {
	t.Helper()
	id := pgtest.NewUser(t, e.admin, true, "customer", "host")
	identitytest.Profile(t, e.admin, id, "Riya", []string{"hi"}, nil)
	identitytest.Host(t, e.admin, id, 500, false)
	return id, callstest.Principal(id, auth.RoleHost)
}

func (e aEnv) online(t *testing.T, p auth.Principal, on bool) hosts.HostStatus {
	t.Helper()
	st, err := e.svc.SetAvailability(e.ctx, p, hosts.SetAvailabilityRequest{IsAvailable: on})
	if err != nil {
		t.Fatal(err)
	}
	return st
}

// capture runs ticket → upload → confirm.
func (e aEnv) capture(t *testing.T, p auth.Principal, data []byte) (hosts.ArrivalPhotoView, error) {
	t.Helper()
	tk, err := e.svc.CreateArrivalUpload(e.ctx, p, hosts.ArrivalUploadRequest{ContentType: "image/jpeg"})
	if err != nil {
		t.Fatal(err)
	}
	e.store.upload(p.UserID+"/"+tk.PhotoId+".jpg", data)
	return e.svc.ConfirmArrivalPhoto(e.ctx, p, tk.PhotoId)
}

func (e aEnv) card(t *testing.T, hostID string) discovery.HostDetail {
	t.Helper()
	d, err := e.disc.GetHost(e.ctx, e.viewer, hostID)
	if err != nil {
		t.Fatal(err)
	}
	return d
}

func code(err error) string {
	if a := apperr.As(err); a != nil {
		if a.Kind == apperr.KindValidation {
			for k, v := range a.Fields {
				return k + ":" + v
			}
		}
		return a.Code
	}
	if err != nil {
		return err.Error()
	}
	return ""
}

func TestOnlineSessionLifecycle(t *testing.T) {
	e := newAEnv(t, nil)
	id, p := e.offlineHost(t)
	st, _ := e.svc.GetHostStatus(e.ctx, p)
	if st.OnlineSession != nil {
		t.Fatal("offline host has a session")
	}
	st = e.online(t, p, true)
	if st.OnlineSession == nil || st.OnlineSession.StartedAt.IsZero() {
		t.Fatal("going online must open a session")
	}
	first := st.OnlineSession.Id
	// Re-sending "online" keeps the same session.
	if again := e.online(t, p, true); again.OnlineSession == nil || again.OnlineSession.Id != first {
		t.Fatal("second online toggle replaced the session")
	}
	e.online(t, p, false)
	var reason string
	if err := e.admin.QueryRow(e.ctx, `select end_reason from hosting.online_sessions where id = $1`, first).Scan(&reason); err != nil || reason != "host_offline" {
		t.Fatalf("end reason %q %v", reason, err)
	}
	st = e.online(t, p, true)
	if st.OnlineSession == nil || st.OnlineSession.Id == first {
		t.Fatal("a new online period must be a new session")
	}
	// Heartbeat timeout ends the session with its own reason.
	if _, err := e.admin.Exec(e.ctx, `update hosting.hosts set last_heartbeat_at = now() - interval '10 minutes' where user_id = $1`, id); err != nil {
		t.Fatal(err)
	}
	if _, err := e.repo.MarkOffline(e.ctx, time.Now().Add(-90*time.Second)); err != nil {
		t.Fatal(err)
	}
	if err := e.admin.QueryRow(e.ctx, `select end_reason from hosting.online_sessions where id = $1`, st.OnlineSession.Id).Scan(&reason); err != nil || reason != "heartbeat_timeout" {
		t.Fatalf("heartbeat end reason %q %v", reason, err)
	}
	var open int
	_ = e.admin.QueryRow(e.ctx, `select count(*) from hosting.online_sessions where host_id = $1 and ended_at is null`, id).Scan(&open)
	if open != 0 {
		t.Fatal("offline host still has an open session")
	}
}

func TestArrivalPhotoNeedsOnlineSession(t *testing.T) {
	e := newAEnv(t, nil)
	_, p := e.offlineHost(t)
	if _, err := e.svc.CreateArrivalUpload(e.ctx, p, hosts.ArrivalUploadRequest{ContentType: "image/jpeg"}); code(err) != "not_online" {
		t.Fatalf("offline upload: %v", err)
	}
	e.online(t, p, true)
	if _, err := e.svc.CreateArrivalUpload(e.ctx, p, hosts.ArrivalUploadRequest{ContentType: "image/png"}); code(err) != "content_type:must_be_image_jpeg" {
		t.Fatalf("png ticket: %v", err)
	}
	// A customer (not an approved host) cannot upload.
	if _, err := e.svc.CreateArrivalUpload(e.ctx, e.viewer, hosts.ArrivalUploadRequest{ContentType: "image/jpeg"}); code(err) != "host_not_approved" {
		t.Fatalf("customer upload: %v", err)
	}
}

func TestArrivalCaptureModerationAndDiscovery(t *testing.T) {
	e := newAEnv(t, nil) // no scanner, no auto-approve → staff review
	id, p := e.offlineHost(t)
	e.online(t, p, true)
	v, err := e.capture(t, p, jpegBytes(t, 480, 640))
	if err != nil || v.Status != hosts.ArrivalPendingReview || v.CapturedAt == nil || v.PhotoUrl == nil {
		t.Fatalf("confirm %+v %v", v, err)
	}
	// The stored object was re-encoded by the server (metadata dropped).
	if card := e.card(t, id); card.ArrivalPhoto != nil {
		t.Fatal("an unreviewed photo must not be shown to customers")
	}
	q, err := e.svc.ArrivalReviewQueue(e.ctx, e.staff, 50)
	if err != nil || len(q) == 0 {
		t.Fatalf("queue %v %v", q, err)
	}
	if _, err := e.svc.DecideArrivalPhotoStaff(e.ctx, e.staff, v.PhotoId, hosts.ArrivalDecisionRequest{Decision: "approve"}); err != nil {
		t.Fatal(err)
	}
	card := e.card(t, id)
	if card.ArrivalPhoto == nil || card.ArrivalPhoto.Url == "" || card.ArrivalPhoto.PhotoId != v.PhotoId || card.ArrivalPhoto.CapturedAt.IsZero() ||
		time.Since(card.ArrivalPhoto.CapturedAt) > time.Minute {
		t.Fatalf("discovery arrival photo %+v", card.ArrivalPhoto)
	}
	list, err := e.disc.ListAvailableHosts(e.ctx, e.viewer, discovery.ListRequest{Limit: 100})
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, c := range list.Items {
		if c.UserId == id {
			found = c.ArrivalPhoto != nil
		}
	}
	if !found {
		t.Fatal("arrival photo missing from the listing")
	}
	var audited int
	_ = e.admin.QueryRow(e.ctx, `select count(*) from audit.events where action = 'arrival_photo.approved' and target = $1`, v.PhotoId).Scan(&audited)
	if audited != 1 {
		t.Fatal("staff decision not audited")
	}

	// Going offline: the photo expires at once and is never shown again.
	e.online(t, p, false)
	var status string
	_ = e.admin.QueryRow(e.ctx, `select status from hosting.arrival_photos where id = $1`, v.PhotoId).Scan(&status)
	if status != hosts.ArrivalExpired {
		t.Fatalf("status after offline %s", status)
	}
	if card := e.card(t, id); card.ArrivalPhoto != nil {
		t.Fatal("expired photo still in discovery")
	}
	// The next session starts without a photo (no reuse).
	e.online(t, p, true)
	if cur, err := e.svc.GetArrivalPhoto(e.ctx, p); err != nil || cur != nil {
		t.Fatalf("previous session's photo reused: %+v %v", cur, err)
	}
	if card := e.card(t, id); card.ArrivalPhoto != nil {
		t.Fatal("previous session's photo shown")
	}
}

func TestArrivalClassifierAndAutoApprove(t *testing.T) {
	clean := newAEnv(t, func(c *hosts.ArrivalConfig) { c.Scanner = scanner{0.05} })
	_, p := clean.offlineHost(t)
	clean.online(t, p, true)
	if v, err := clean.capture(t, p, jpegBytes(t, 400, 400)); err != nil || v.Status != hosts.ArrivalApproved {
		t.Fatalf("clean scan %+v %v", v, err)
	}
	flagged := newAEnv(t, func(c *hosts.ArrivalConfig) { c.Scanner = scanner{0.95}; c.FlagThreshold = 0.6 })
	fid, fp := flagged.offlineHost(t)
	flagged.online(t, fp, true)
	v, err := flagged.capture(t, fp, jpegBytes(t, 400, 400))
	if err != nil || v.Status != hosts.ArrivalRejected || v.Reason == nil {
		t.Fatalf("flagged scan %+v %v", v, err)
	}
	if card := flagged.card(t, fid); card.ArrivalPhoto != nil {
		t.Fatal("rejected photo shown")
	}
	auto := newAEnv(t, func(c *hosts.ArrivalConfig) { c.AutoApproveUnscanned = true })
	_, ap := auto.offlineHost(t)
	auto.online(t, ap, true)
	if v, err := auto.capture(t, ap, jpegBytes(t, 400, 400)); err != nil || v.Status != hosts.ArrivalApproved {
		t.Fatalf("auto approve %+v %v", v, err)
	}
}

func TestArrivalInvalidUploads(t *testing.T) {
	e := newAEnv(t, nil)
	_, p := e.offlineHost(t)
	e.online(t, p, true)
	var pngBuf bytes.Buffer
	_ = png.Encode(&pngBuf, image.NewRGBA(image.Rect(0, 0, 400, 400)))
	for name, data := range map[string][]byte{
		"png bytes":   pngBuf.Bytes(),
		"garbage":     []byte("not an image at all"),
		"tiny":        jpegBytes(t, 100, 100),
		"truncated":   jpegBytes(t, 400, 400)[:600],
		"oversized":   bytes.Repeat([]byte{0xFF}, hosts.ArrivalMaxBytes+1),
		"fake header": append([]byte{0xFF, 0xD8, 0xFF}, bytes.Repeat([]byte{1}, 500)...),
	} {
		t.Run(name, func(t *testing.T) {
			_, err := e.capture(t, p, data)
			if c := code(err); c != "photo:invalid_image" && c != "photo:too_large" {
				t.Fatalf("want rejection, got %v", err)
			}
		})
	}
	// Missing upload: retryable, then succeeds once uploaded.
	tk, err := e.svc.CreateArrivalUpload(e.ctx, p, hosts.ArrivalUploadRequest{ContentType: "image/jpeg"})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := e.svc.ConfirmArrivalPhoto(e.ctx, p, tk.PhotoId); code(err) != "upload_missing" {
		t.Fatalf("missing upload: %v", err)
	}
	e.store.failGet = errors.New("network down")
	e.store.upload(p.UserID+"/"+tk.PhotoId+".jpg", jpegBytes(t, 400, 400))
	if _, err := e.svc.ConfirmArrivalPhoto(e.ctx, p, tk.PhotoId); code(err) != "storage_error" {
		t.Fatalf("storage failure: %v", err)
	}
	e.store.failGet = nil
	v, err := e.svc.ConfirmArrivalPhoto(e.ctx, p, tk.PhotoId)
	if err != nil || v.Status != hosts.ArrivalPendingReview {
		t.Fatalf("retry %+v %v", v, err)
	}
	// Confirming again is idempotent.
	if again, err := e.svc.ConfirmArrivalPhoto(e.ctx, p, tk.PhotoId); err != nil || again.Status != v.Status {
		t.Fatalf("repeat confirm %+v %v", again, err)
	}
}

func TestArrivalAccessControlAndWindow(t *testing.T) {
	e := newAEnv(t, nil)
	_, p := e.offlineHost(t)
	_, other := e.offlineHost(t)
	e.online(t, p, true)
	e.online(t, other, true)
	tk, err := e.svc.CreateArrivalUpload(e.ctx, p, hosts.ArrivalUploadRequest{ContentType: "image/jpeg"})
	if err != nil {
		t.Fatal(err)
	}
	e.store.upload(p.UserID+"/"+tk.PhotoId+".jpg", jpegBytes(t, 400, 400))
	if _, err := e.svc.ConfirmArrivalPhoto(e.ctx, other, tk.PhotoId); code(err) != "not_found" {
		t.Fatalf("another host confirmed my photo: %v", err)
	}
	// Past the upload window an old picture cannot be "captured" now.
	if _, err := e.admin.Exec(e.ctx, `update hosting.arrival_photos set upload_expires_at = now() - interval '1 second' where id = $1`, tk.PhotoId); err != nil {
		t.Fatal(err)
	}
	if _, err := e.svc.ConfirmArrivalPhoto(e.ctx, p, tk.PhotoId); code(err) != "arrival_photo_expired" {
		t.Fatalf("expired window: %v", err)
	}
	// Offline between ticket and confirm: refused.
	tk2, _ := e.svc.CreateArrivalUpload(e.ctx, other, hosts.ArrivalUploadRequest{ContentType: "image/jpeg"})
	e.store.upload(other.UserID+"/"+tk2.PhotoId+".jpg", jpegBytes(t, 400, 400))
	e.online(t, other, false)
	if _, err := e.svc.ConfirmArrivalPhoto(e.ctx, other, tk2.PhotoId); code(err) != "arrival_photo_expired" {
		t.Fatalf("confirm after offline: %v", err)
	}
}

func TestArrivalRetakeRemoveReportAndPurge(t *testing.T) {
	e := newAEnv(t, func(c *hosts.ArrivalConfig) { c.AutoApproveUnscanned = true })
	id, p := e.offlineHost(t)
	e.online(t, p, true)
	first, err := e.capture(t, p, jpegBytes(t, 400, 400))
	if err != nil {
		t.Fatal(err)
	}
	second, err := e.capture(t, p, jpegBytes(t, 500, 500)) // retake replaces it
	if err != nil || second.PhotoId == first.PhotoId {
		t.Fatal(err)
	}
	var status string
	_ = e.admin.QueryRow(e.ctx, `select status from hosting.arrival_photos where id = $1`, first.PhotoId).Scan(&status)
	if status != hosts.ArrivalRemoved {
		t.Fatalf("replaced photo status %s", status)
	}
	// A customer reports the current photo; it is linked to the report.
	sf := safety.NewService(safety.Deps{Repo: postgres.SafetyRepo{Pool: e.api}})
	ph := second.PhotoId
	if _, err := sf.ReportUser(e.ctx, e.viewer, safety.ReportRequest{TargetUserId: id, Category: "fake_profile", ArrivalPhotoId: &ph}); err != nil {
		t.Fatal(err)
	}
	var linked int
	_ = e.admin.QueryRow(e.ctx, `select count(*) from safety.reports where arrival_photo_id = $1`, ph).Scan(&linked)
	if linked != 1 {
		t.Fatal("report not linked to the photo")
	}
	// Staff removal takes it out of discovery at once.
	if _, err := e.svc.DecideArrivalPhotoStaff(e.ctx, e.staff, ph, hosts.ArrivalDecisionRequest{Decision: "remove", Reason: "reported"}); err != nil {
		t.Fatal(err)
	}
	if e.card(t, id).ArrivalPhoto != nil {
		t.Fatal("removed photo shown")
	}
	// Host removal of nothing current is a no-op.
	if err := e.svc.DeleteArrivalPhoto(e.ctx, p); err != nil {
		t.Fatal(err)
	}
	// Purge: after retention, the replaced photo's object is deleted; the
	// reported one is kept while its report is open.
	later := time.Now().Add(48 * time.Hour)
	if _, _, err := e.svc.PurgeArrivalPhotos(e.ctx, later); err != nil {
		t.Fatal(err)
	}
	firstPath := p.UserID + "/" + first.PhotoId + ".jpg"
	secondPath := p.UserID + "/" + ph + ".jpg"
	if _, ok := e.store.objects[firstPath]; ok {
		t.Fatal("replaced photo not purged")
	}
	if _, ok := e.store.objects[secondPath]; !ok {
		t.Fatal("reported photo purged while its report is open")
	}
	if _, err := e.admin.Exec(e.ctx, `update safety.reports set status = 'decided' where arrival_photo_id = $1`, ph); err != nil {
		t.Fatal(err)
	}
	if _, _, err := e.svc.PurgeArrivalPhotos(e.ctx, later); err != nil {
		t.Fatal(err)
	}
	if _, ok := e.store.objects[secondPath]; ok {
		t.Fatal("photo kept after its report closed")
	}
	// Abandoned tickets expire.
	tk, _ := e.svc.CreateArrivalUpload(e.ctx, p, hosts.ArrivalUploadRequest{ContentType: "image/jpeg"})
	if n, _, err := e.svc.PurgeArrivalPhotos(e.ctx, time.Now().Add(time.Hour)); err != nil || n < 1 {
		t.Fatalf("abandoned tickets expired %d %v", n, err)
	}
	_ = e.admin.QueryRow(e.ctx, `select status from hosting.arrival_photos where id = $1`, tk.PhotoId).Scan(&status)
	if status != hosts.ArrivalExpired {
		t.Fatalf("abandoned ticket %s", status)
	}
}

func TestArrivalDisabledFlag(t *testing.T) {
	e := newAEnv(t, func(c *hosts.ArrivalConfig) { c.Enabled = false })
	_, p := e.offlineHost(t)
	e.online(t, p, true)
	if _, err := e.svc.CreateArrivalUpload(e.ctx, p, hosts.ArrivalUploadRequest{ContentType: "image/jpeg"}); code(err) != "arrival_photos_disabled" {
		t.Fatalf("flag off: %v", err)
	}
}
